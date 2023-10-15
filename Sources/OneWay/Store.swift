//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

public actor Store<Action, State> where Action: Sendable, State: Equatable {
    public var state: State { didSet { continuation.yield(state) } }
    public var states: AsyncStream<State>

    private let reducer: any Reducer<Action, State>
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var actionQueue: [Action] = []
    private var tasks: [UUID: Task<Void, Never>] = [:]

    public init<R: Reducer>(
        reducer: @autoclosure () -> R,
        state: State
    ) where R.Action == Action, R.State == State {
        self.state = state
        self.reducer = reducer()
        (states, continuation) = AsyncStream<State>.makeStream()
    }

    public func send(_ action: Action) async {
        actionQueue.append(action)
        guard !isProcessing else { return }

        isProcessing = true
        while !actionQueue.isEmpty {
            let action = actionQueue.removeFirst()
            let uuid = UUID()
            var effect = reducer.reduce(state: &state, action: action)
            effect.completion = {
                Task { [weak self, uuid] in
                    await self?.removeTask(uuid)
                }
            }

            let task = Task { [weak self, uuid, effect] in
                for await value in effect.values {
                    await self?.send(value)
                }
                await self?.removeTask(uuid)
            }
            tasks[uuid] = task
        }
        isProcessing = false
    }

    private func removeTask(_ key: UUID) {
        tasks.removeValue(forKey: key)
    }
}
