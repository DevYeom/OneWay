//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// An asynchronous sequence that treats consecutive repeated values as unique values.
public struct AsyncRemoveDuplicatesSequence<Base>: AsyncSequence
where Base: AsyncSequence, Base.Element: Equatable {
    public typealias Element = Base.Element

    /// The iterator for an `AsyncRemoveDuplicatesSequence` instance.
    public struct Iterator: AsyncIteratorProtocol {
        @usableFromInline
        var iterator: Base.AsyncIterator

        @usableFromInline
        var last: Element?

        @usableFromInline
        init(_ iterator: Base.AsyncIterator) {
            self.iterator = iterator
        }

        @inlinable
        public mutating func next() async rethrows -> Element? {
            guard let last else {
                self.last = try await iterator.next()
                return self.last
            }
            while let element = try await iterator.next() {
                guard last != element else { continue }
                self.last = element
                return element
            }
            return nil
        }
    }

    @usableFromInline
    let base: Base

    init(_ base: Base) {
        self.base = base
    }

    @inlinable
    public func makeAsyncIterator() -> Iterator {
        Iterator(base.makeAsyncIterator())
    }
}

extension AsyncRemoveDuplicatesSequence: Sendable where Base: Sendable, Base.Element: Sendable { }
