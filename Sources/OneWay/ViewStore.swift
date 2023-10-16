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
    public var states: DynamicStream<State> { DynamicStream(stream) }

    private let store: Store<R>
    private let stream: AsyncStream<State>
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
        (stream, continuation) = AsyncStream<State>.makeStream()
        self.task = Task { await observe() }
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

@dynamicMemberLookup
public struct DynamicStream<State>: AsyncSequence {
    public typealias Element = State

    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = State

        private var iterator: AsyncStream<State>.Iterator

        init(_ iterator: AsyncStream<State>.Iterator) {
            self.iterator = iterator
        }

        public mutating func next() async -> Element? {
            await iterator.next()
        }
    }

    private let stream: AsyncStream<State>

    public init(_ stream: AsyncStream<State>) {
        self.stream = stream
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(stream.makeAsyncIterator())
    }

    public subscript<Property>(
        dynamicMember keyPath: KeyPath<State, Property>
    ) -> AsyncMapSequence<AsyncStream<State>, Property> {
        stream.map { $0[keyPath: keyPath] }
    }
}
