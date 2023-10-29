//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// An asynchronous sequence of the ``ViewStore``'s state.
///
/// This stream supports dynamic member lookup so that you can pluck out a specific field in the
/// state.
@MainActor
@dynamicMemberLookup
public final class AsyncViewStateSequence<State>: AsyncSequence
where State: Sendable & Equatable {
    public typealias Element = State

    /// The iterator for an `AsyncViewStateSequence` instance.
    public struct Iterator: AsyncIteratorProtocol {
        public typealias Element = State

        @usableFromInline
        var iterator: AsyncStream<Element>.Iterator

        @usableFromInline
        init(_ iterator: AsyncStream<Element>.Iterator) {
            self.iterator = iterator
        }

        @inlinable
        public mutating func next() async -> Element? {
            await iterator.next()
        }
    }

    @usableFromInline
    let upstream: AsyncStream<Element>

    private var continuations: [AsyncStream<Element>.Continuation] = []
    private var last: Element?

    public init(_ upstream: AsyncStream<Element>) {
        self.upstream = upstream
    }

    deinit {
        continuations.forEach { $0.finish() }
    }

    @inlinable
    public nonisolated func makeAsyncIterator() -> Iterator {
        Iterator(upstream.makeAsyncIterator())
    }

    func send(_ element: Element) {
        last = element
        for continuation in continuations {
            continuation.yield(element)
        }
    }

    /// Returns the resulting stream with partial state corresponding to the given key path.
    ///
    /// - Parameter dynamicMember: a key path for the original state.
    /// - Returns: A new stream that has a part of the original state.
    public subscript<Property>(
        dynamicMember keyPath: KeyPath<State, Property>
    ) -> AsyncMapSequence<AsyncStream<State>, Property> {
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        continuations.append(continuation)
        if let last {
            continuation.yield(last)
        }
        return stream.map { $0[keyPath: keyPath] }
    }
}

extension AsyncViewStateSequence: Sendable where State: Sendable { }
