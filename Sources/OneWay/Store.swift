//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Foundation)
import Foundation
#endif

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

    private let reducer: any Reducer<Action, State>
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var bindingTask: Task<Void, Never>?
    private var tasks: [TaskID: Task<Void, Never>] = [:]
    private var cancellables: [EffectIDWrapper: Set<TaskID>] = [:]

    /// Initializes a store from a reducer and an initial state.
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
        self.reducer = reducer()
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
            let taskID = TaskID()
            let effect = reducer.reduce(state: &state, action: action)
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
            case .none:
                break
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
