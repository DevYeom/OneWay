//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if !os(Linux)
#if canImport(Combine)
import Combine
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

    /// The initial state of the store.
    public let initialState: State

    /// The current state of the store.
    public private(set) var state: State {
        didSet {
            continuation.yield(state)
            states.send(state)
#if canImport(Combine)
            objectWillChange.send()
#endif
        }
    }

    /// The asynchronous stream that emits state changes.
    ///
    /// Use this stream to observe state changes.
    public let states: AsyncViewStateSequence<State>

    private let store: Store<R, C>
    private let continuation: AsyncStream<State>.Continuation
    private var task: Task<Void, Never>?

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
        self.store = Store(
            reducer: reducer(),
            state: state,
            clock: clock
        )
        let (stream, continuation) = AsyncStream<State>.makeStream()
        self.states = AsyncViewStateSequence(stream)
        self.continuation = continuation
        self.task = Task { @MainActor [weak self] in
            guard let states = await self?.store.states else { return }
            for await state in states {
                guard let self else { break }
                guard !Task.isCancelled else { break }
                self.state = state
            }
        }
    }

    deinit {
        task?.cancel()
        continuation.finish()
    }

    /// Sends an action to the view store.
    ///
    /// - Parameter action: An action defined in the reducer.
    public func send(_ action: Action) {
        Task { @MainActor in
            await store.send(action)
        }
    }

    /// Resets the store by removing all queued actions and effects and re-binding global states.
    ///
    /// - Note: This is useful when you need to call `bind()` again, as you cannot call `bind()`
    ///   directly.
    public func reset() {
        Task { @MainActor in
            await store.reset()
        }
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
        Task { @MainActor in
            await store.debug(loggingOptions)
        }
        return self
    }
}

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
