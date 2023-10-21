//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// `Store` is an actor that holds and manages state values.
///
/// It is fully thread-safe as it is implemented using an actor. It stores the `State` and can
/// change the `State` by receiving `Actions`. You can define `Action` and `State` in ``Reducer``.
/// If you create a data flow through `Store`, you can make it flow in one direction.
public actor Store<R: Reducer>
where R.Action: Sendable, R.State: Sendable & Equatable {
    /// A convenience type alias for referring to a action of a given reducer's action.
    public typealias Action = R.Action

    /// A convenience type alias for referring to a state of a given reducer's state.
    public typealias State = R.State

    /// The initial state of a store.
    public let initialState: State

    /// The current state of a store.
    public var state: State {
        didSet {
            if oldValue != state {
                continuation.yield(state)
            }
        }
    }

    /// The state stream that emits state when the state changes. Use this stream to observe the 
    /// state changes
    public var states: AsyncStream<State>

    private let reducer: any Reducer<Action, State>
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var bindingTask: Task<Void, Never>?
    private var tasks: [UUID: Task<Void, Never>] = [:]

    /// Initializes a store from a reducer and an initial state.
    ///
    /// - Parameters:
    ///   - reducer: The reducer is responsible for transitioning the current state to the next 
    ///   state.
    ///   - state: The state to initialize a store.
    public init(
        reducer: @autoclosure () -> R,
        state: State
    ) {
        self.initialState = state
        self.state = state
        self.reducer = reducer()
        (states, continuation) = AsyncStream<State>.makeStream()
        Task { await bindExternalEffect() }
        defer { continuation.yield(state) }
    }

    /// Sends an action to the store.
    ///
    /// - Parameter action: An action defined in the reducer.
    public func send(_ action: Action) async {
        actionQueue.append(action)
        guard !isProcessing else { return }

        isProcessing = true
        while !actionQueue.isEmpty {
            let action = actionQueue.removeFirst()
            let uuid = UUID()
            let effect = reducer.reduce(state: &state, action: action)
            let task = Task { [weak self, uuid] in
                for await value in effect.values {
                    await self?.send(value)
                }
                await self?.removeTask(uuid)
            }
            tasks[uuid] = task
        }
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
    }

    private func bindExternalEffect() {
        bindingTask?.cancel()
        bindingTask = Task { [weak self] in
            guard let values = self?.reducer.bind().values else { return }
            for await value in values {
                await self?.send(value)
            }
        }
    }

    private func removeTask(_ key: UUID) {
        tasks.removeValue(forKey: key)
    }
}
