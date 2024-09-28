//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if !os(Linux)
#if canImport(Combine)
import Combine
#endif

/// `ViewStore` is an object that manages state values within the context of the `MainActor`.
///
/// It can observe state changes and send actions. It can primarily be used in SwiftUI's `View`,
/// `UIView` or `UIViewController` operating on main thread.
@MainActor
public final class ViewStore<R: Reducer>
where R.Action: Sendable, R.State: Sendable & Equatable {
    /// A convenience type alias for referring to a action of a given reducer's action.
    public typealias Action = R.Action

    /// A convenience type alias for referring to a state of a given reducer's state.
    public typealias State = R.State

    /// The initial state of a store.
    public let initialState: State

    /// The current state of a store.
    public private(set) var state: State {
        didSet {
            continuation.yield(state)
            states.send(state)
#if canImport(Combine)
            objectWillChange.send()
#endif
        }
    }

    /// The async stream that emits state when the state changes. Use this stream to observe the
    /// state changes
    public let states: AsyncViewStateSequence<State>

    private let store: Store<R>
    private let continuation: AsyncStream<State>.Continuation
    private var task: Task<Void, Never>?

    /// Initializes a view store from a reducer and an initial state.
    ///
    /// - Parameters:
    ///   - reducer: The reducer is responsible for transitioning the current state to the next
    ///   state.
    ///   - state: The state to initialize a store.
    public init(
        reducer: @Sendable @autoclosure () -> R,
        state: State
    ) {
        self.initialState = state
        self.state = state
        self.store = Store(
            reducer: reducer(),
            state: state
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

    /// Removes all actions and effects in the queue and re-binds for global states.
    ///
    /// - Note: This is useful when you need to call `bind()` again. Because you can't call `bind()`
    ///   directly
    public func reset() {
        Task { @MainActor in
            await store.reset()
        }
    }
}

#if canImport(Combine)
extension ViewStore: ObservableObject { }
#endif

#endif
