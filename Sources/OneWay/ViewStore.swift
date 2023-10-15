//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

@MainActor
public final class ViewStore<R: Reducer>: ObservableObject
where R.Action: Sendable, R.State: Equatable {
    public typealias Action = R.Action
    public typealias State = R.State

    public var state: State { didSet { continuation.yield(state) } }
    public var states: AsyncStream<State>

    private let store: Store<R>
    private let continuation: AsyncStream<State>.Continuation
    private var task: Task<Void, Never>?

    public init(
        reducer: @autoclosure () -> R,
        state: State
    ) {
        self.state = state
        self.store = Store(
            reducer: reducer(),
            state: state
        )
        (states, continuation) = AsyncStream<State>.makeStream()
        self.task = Task { await observe() }
        defer { continuation.yield(state) }
    }

    deinit {
        continuation.finish()
        task?.cancel()
        task = nil
    }

    public func send(_ action: Action) {
        Task {
            await store.send(action)
        }
    }

    private func observe() async {
        let states = await store.states
        for await state in states {
            self.state = state
        }
    }
}
