//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2026 Seungyeop Yeom ( https://github.com/DevYeom ).
//

#if !os(Linux)
#if canImport(Combine)
import Combine
#endif
#if canImport(Foundation)
import Foundation
#endif
#if canImport(OSLog)
import OSLog
#endif

/// `ViewStore` is an object that manages state values within the context of the `MainActor`.
///
/// It can be used to observe state changes and send actions. It is primarily intended for use in
/// SwiftUI's `View`, `UIView`, or `UIViewController`, all of which operate on the main thread.
@MainActor
public final class ViewStore<R: Reducer, C: Clock<Duration>>
where R.Action: Sendable, R.State: Sendable & Equatable {
    /// A convenience type alias for referring to a given reducer's action.
    public typealias Action = R.Action

    /// A convenience type alias for referring to a given reducer's state.
    public typealias State = R.State

    private typealias TaskID = UUID

    /// The initial state of the store.
    public let initialState: State

    /// The current state of the store.
    public private(set) var state: State {
        didSet {
            if oldValue != state {
                continuation.yield(state)
                states.send(state)
#if canImport(Combine)
                objectWillChange.send()
#endif
#if canImport(OSLog) && DEBUG
                if loggingOptions.contains(.state) {
                    let timestamp = Date.now.formatted(iso8601FormatStyle)
                    logger.debug("""
                    [\(timestamp)] State changed:
                    - \(String(describing: oldValue))
                    + \(String(describing: self.state))
                    """)
                }
#endif
            }
        }
    }

    /// The asynchronous stream that emits state changes.
    ///
    /// Use this stream to observe state changes.
    public let states: AsyncViewStateSequence<State>
    
    /// A boolean value indicating whether the store is currently idle.
    ///
    /// A store is considered idle when it is not processing any actions and there are no pending
    /// tasks for side effects.
    public var isIdle: Bool {
        !isProcessing && tasks.isEmpty
    }

    private let reducer: R
    private let clock: C
#if canImport(OSLog) && DEBUG
    private let logger = Logger(subsystem: "com.devyeom.oneway", category: "ViewStore")
#endif
    private var loggingOptions = LoggingOptions.none
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var bindingTask: Task<Void, Never>?
    private var tasks: [TaskID: Task<Void, Never>] = [:]
    private var cancellables: [EffectIDWrapper: Set<TaskID>] = [:]
    private var throttleTimestamps: [EffectIDWrapper: C.Instant] = [:]
    private var trailingThrottledEffects: [EffectIDWrapper: AnyEffect<Action>] = [:]

    /// Initializes a new view store with a reducer, an initial state, and a clock.
    ///
    /// - Parameters:
    ///   - reducer: The reducer that is responsible for transitioning the current state to the
    ///     next state in response to actions.
    ///   - state: The initial state to be used for the store.
    ///   - clock: The clock that determines how time-based effects, such as debounce or
    ///     throttle, are scheduled. The default is `ContinuousClock`.
    public init(
        reducer: @Sendable @autoclosure () -> R,
        state: State,
        clock: C = ContinuousClock()
    ) {
        self.initialState = state
        self.state = state
        self.reducer = reducer()
        self.clock = clock
        let (stream, continuation) = AsyncStream<State>.makeStream()
        self.states = AsyncViewStateSequence(stream)
        self.continuation = continuation
        Task { @MainActor [weak self] in
            self?.bindExternalEffect()
        }
        defer {
            continuation.yield(state)
            states.send(state)
        }
    }

    deinit {
        continuation.finish()
        tasks.forEach { $0.value.cancel() }
        bindingTask?.cancel()
    }

    /// Sends an action to the view store.
    ///
    /// - Parameter action: An action defined in the reducer.
    public func send(_ action: Action) {
        actionQueue.append(action)
        guard !isProcessing else { return }
        isProcessing = true
        while !actionQueue.isEmpty {
            let actions = actionQueue
            actionQueue.removeAll()
            for action in actions {
#if canImport(OSLog) && DEBUG
                if loggingOptions.contains(.action) {
                    let timestamp = Date.now.formatted(iso8601FormatStyle)
                    logger.debug("[\(timestamp)] Action: \(String(describing: action))")
                }
#endif
                let effect = reducer.reduce(state: &state, action: action)
                let isThrottled = throttleIfNeeded(for: effect)
                if !isThrottled {
                    execute(effect: effect)
                }
            }
        }
        isProcessing = false
    }

    /// Resets the store by removing all queued actions and effects and re-binding global states.
    ///
    /// - Note: This is useful when you need to call `bind()` again, as you cannot call `bind()`
    ///   directly.
    public func reset() {
        bindExternalEffect()
        tasks.forEach { $0.value.cancel() }
        tasks.removeAll()
        actionQueue.removeAll()
        cancellables.removeAll()
        trailingThrottledEffects.removeAll()
        throttleTimestamps.removeAll()
    }

    /// Sets the logging options for the store to control what information is logged.
    ///
    /// You can use this method to dynamically change the logging behavior of the store after it
    /// has been initialized. For example, you might want to enable logging only for certain
    /// user interactions or when debugging a specific issue.
    ///
    /// ```swift
    /// // Enables logging for both actions and state changes.
    /// @StateObject private var store = ViewStore(
    ///     reducer: HomeReducer(),
    ///     state: HomeReducer.State()
    /// )
    /// .debug(.all)
    ///
    /// // Disables all logging.
    /// store.debug(.none)
    /// ```
    ///
    /// - Parameter loggingOptions: A set of `LoggingOptions` that determines what information
    ///   is logged.
    public func debug(_ loggingOptions: LoggingOptions) -> Self {
        self.loggingOptions = loggingOptions
        return self
    }

    private func throttleIfNeeded(for effect: AnyEffect<Action>) -> Bool {
        guard case let .throttle(id, interval, latest) = effect.method else {
            return false
        }
        let effectID = EffectIDWrapper(id)
        let now = clock.now
        if let last = throttleTimestamps[effectID],
           last.duration(to: now) < interval {
            if latest {
                trailingThrottledEffects[effectID] = effect
            }
            return true
        } else {
            throttleTimestamps[effectID] = now
            if latest {
                Task { @MainActor [weak self] in
                    do {
                        try await self?.clock.sleep(for: interval)
                        self?.executeTrailingThrottledEffects(effectID)
                    }
                    catch {
                        self?.removeTrailingThrottledEffects(effectID)
                    }
                }
            }
            return false
        }
    }

    private func execute(effect: AnyEffect<Action>) {
        let taskID = TaskID()
        let task = Task { @MainActor [weak self, taskID] in
            guard !Task.isCancelled else { return }
            for await value in effect.values {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                self.send(value)
            }
            self?.removeTask(taskID)
        }
        tasks[taskID] = task

        switch effect.method {
        case let .register(id, cancelInFlight):
            let effectID = EffectIDWrapper(id)
            if cancelInFlight {
                let taskIDs = cancellables[effectID, default: []]
                taskIDs.forEach { removeTask($0) }
                cancellables.removeValue(forKey: effectID)
            }
            cancellables[effectID, default: []].insert(taskID)
        case let .cancel(id):
            let effectID = EffectIDWrapper(id)
            let taskIDs = cancellables[effectID, default: []]
            taskIDs.forEach { removeTask($0) }
            cancellables.removeValue(forKey: effectID)
        case .throttle,
             .none:
            break
        }
    }

    private func executeTrailingThrottledEffects(_ effectID: EffectIDWrapper) {
        if let effect = trailingThrottledEffects.removeValue(forKey: effectID) {
            execute(effect: effect)
        }
    }

    private func removeTrailingThrottledEffects(_ effectID: EffectIDWrapper) {
        trailingThrottledEffects.removeValue(forKey: effectID)
    }

    private func bindExternalEffect() {
        let values = reducer.bind().values
        bindingTask?.cancel()
        bindingTask = Task { @MainActor [weak self] in
            for await value in values {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                self.send(value)
            }
        }
    }

    private func removeTask(_ key: UUID) {
        if let task = tasks.removeValue(forKey: key) {
            task.cancel()
        }
    }
}

private struct EffectIDWrapper: Hashable, @unchecked Sendable {
    private let id: AnyHashable

    fileprivate init(_ id: some Hashable & Sendable) {
        self.id = id
    }
}

#if canImport(OSLog) && DEBUG
private let iso8601FormatStyle = Date.ISO8601FormatStyle()
    .year()
    .month()
    .day()
    .timeZone(separator: .omitted)
    .time(includingFractionalSeconds: true)
    .timeSeparator(.colon)
#endif

#if canImport(Combine)
extension ViewStore: ObservableObject { }
#endif

#if canImport(SwiftUI)
import SwiftUI

extension ViewStore {
    #if swift(>=6.0)
    /// Creates a `Binding` that allows for two-way data binding between a state value and an
    /// action.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to access a specific value from the current state.
    ///   - send: A closure that takes the updated value and returns an `Action` to be sent.
    ///
    /// - Returns: A `Binding` object that allows for reading from the state using the key path
    ///   and sending an action when the value is changed.
    @inlinable
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value> & Sendable,
        send: @MainActor @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(send($0)) }
        )
    }
    #else
    /// Creates a `Binding` that allows for two-way data binding between a state value and an
    /// action.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to access a specific value from the current state.
    ///   - send: A closure that takes the updated value and returns an `Action` to be sent.
    ///
    /// - Returns: A `Binding` object that allows for reading from the state using the key path
    ///   and sending an action when the value is changed.
    @inlinable
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        send: @MainActor @Sendable @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.send(send($0)) }
        )
    }
    #endif
}
#endif

#endif
