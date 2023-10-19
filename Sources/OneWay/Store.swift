//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

public actor Store<R: Reducer>
where R.Action: Sendable, R.State: Equatable {
    public typealias Action = R.Action
    public typealias State = R.State

    public let initialState: State
    public var state: State {
        didSet {
            if oldValue != state {
                continuation.yield(state)
            }
        }
    }
    public var states: AsyncStream<State>

    private let reducer: any Reducer<Action, State>
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var bindingTask: Task<Void, Never>?
    private var tasks: [UUID: Task<Void, Never>] = [:]

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
