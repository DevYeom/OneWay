//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Foundation)
import Foundation
#endif

/// `Store` is an actor that holds and manages state values.
///
/// It is fully thread-safe as it is implemented using an actor. It stores the `State` and can
/// change the `State` by receiving `Actions`. You can define `Action` and `State` in ``Reducer``.
/// If you create a data flow through `Store`, you can make it flow in one direction.
public actor Store<R: Reducer, C: Clock<Duration>>
where R.Action: Sendable, R.State: Sendable & Equatable {
    /// A convenience type alias for referring to a action of a given reducer's action.
    public typealias Action = R.Action

    /// A convenience type alias for referring to a state of a given reducer's state.
    public typealias State = R.State

    private typealias TaskID = UUID

    /// The initial state of a store.
    public let initialState: State

    /// The current state of a store.
    public private(set) var state: State {
        didSet {
            if oldValue != state {
                continuation.yield(state)
            }
        }
    }

    /// The state stream that emits state when the state changes. Use this stream to observe the
    /// state changes.
    public var states: AsyncStream<State>

    /// Returns `true` if the store is idle, meaning it's not processing and there are no pending
    /// tasks for side effects.
    public var isIdle: Bool {
        !isProcessing && tasks.isEmpty
    }

    private let reducer: R
    private let clock: C
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var bindingTask: Task<Void, Never>?
    private var tasks: [TaskID: Task<Void, Never>] = [:]
    private var cancellables: [EffectIDWrapper: Set<TaskID>] = [:]
    private var throttleTimestamps: [EffectIDWrapper: C.Instant] = [:]
    private var trailingThrottledEffects: [EffectIDWrapper: AnyEffect<Action>] = [:]

    /// Initializes a store from a reducer, an initial state, and a clock.
    ///
    /// - Parameters:
    ///   - reducer: The reducer responsible for transitioning the current state to the next
    ///     state in response to actions.
    ///   - state: The initial state used to create the store.
    ///   - clock: The clock that determines how time-based effects (such as debounce or throttle)
    ///     are scheduled. Defaults to `ContinuousClock`.
    public init(
        reducer: @Sendable @autoclosure () -> R,
        state: State,
        clock: C = ContinuousClock()
    ) {
        self.initialState = state
        self.state = state
        self.reducer = reducer()
        self.clock = clock
        (states, continuation) = AsyncStream<State>.makeStream()
        Task { await bindExternalEffect() }
        defer { continuation.yield(state) }
    }

    deinit {
        tasks.forEach { $0.value.cancel() }
        bindingTask?.cancel()
    }

    /// Sends an action to the store.
    ///
    /// - Parameter action: An action defined in the reducer.
    public func send(_ action: Action) async {
        actionQueue.append(action)
        guard !isProcessing else { return }
        isProcessing = true
        await Task.yield()
        for action in actionQueue {
            let effect = reducer.reduce(state: &state, action: action)
            let isThrottled = await throttleIfNeeded(for: effect)
            if !isThrottled {
                await execute(effect: effect)
            }
        }
        actionQueue = []
        isProcessing = false
    }

    /// Removes all actions and effects in the queue and re-binds for global states.
    ///
    /// - Note: This is useful when you need to call `bind()` again. Because you can't call `bind()`
    ///   directly
    public func reset() {
        bindExternalEffect()
        tasks.forEach { $0.value.cancel() }
        tasks.removeAll()
        actionQueue.removeAll()
        cancellables.removeAll()
        trailingThrottledEffects.removeAll()
        throttleTimestamps.removeAll()
    }

    private func throttleIfNeeded(for effect: AnyEffect<Action>) async -> Bool {
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
                Task { [weak self] in
                    do {
                        try await self?.clock.sleep(for: interval)
                        await self?.executeTrailingThrottledEffects(effectID)
                    }
                    catch {
                        await self?.removeTrailingThrottledEffects(effectID)
                    }
                }
            }
            return false
        }
    }

    private func execute(effect: AnyEffect<Action>) async {
        let taskID = TaskID()
        let task = Task { [weak self, taskID] in
            guard !Task.isCancelled else { return }
            for await value in effect.values {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                await send(value)
            }
            await self?.removeTask(taskID)
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

    private func executeTrailingThrottledEffects(_ effectID: EffectIDWrapper) async {
        if let effect = trailingThrottledEffects.removeValue(forKey: effectID) {
            await execute(effect: effect)
        }
    }

    private func removeTrailingThrottledEffects(_ effectID: EffectIDWrapper) async {
        trailingThrottledEffects.removeValue(forKey: effectID)
    }

    private func bindExternalEffect() {
        let values = reducer.bind().values
        bindingTask?.cancel()
        bindingTask = Task { [weak self] in
            for await value in values {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                await send(value)
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
