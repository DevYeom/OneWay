//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Combine)
import Combine
#endif
import Foundation

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
    public var state: State {
        didSet {
            continuation.yield(state)
            for continuation in states.continuations {
                continuation.yield(state)
            }
#if canImport(Combine)
            objectWillChange.send()
#endif
        }
    }

    /// The state stream that emits state when the state changes. Use this stream to observe the
    /// state changes
    public lazy var states = DynamicStream(stream)

    private let store: Store<R>
    private let stream: AsyncStream<State>
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
        (stream, continuation) = AsyncStream<State>.makeStream()
        self.task = Task { await observe() }
    }

    deinit {
        continuation.finish()
        task?.cancel()
        task = nil
    }

    /// Sends an action to the view store.
    ///
    /// - Parameter action: An action defined in the reducer.
    public func send(_ action: Action) {
        Task { await store.send(action) }
    }

    /// Removes all actions and effects in the queue and re-binds for global states.
    ///
    /// - Note: This is useful when you need to call `bind()` again. Because you can't call `bind()`
    ///   directly
    public func reset() {
        Task { await store.reset() }
    }

    private func observe() async {
        let states = await store.states
        for await state in states {
            self.state = state
        }
    }
}

#if canImport(Combine)
extension ViewStore: ObservableObject { }
#endif

/// A dynamic stream of the ``ViewStore``'s state.
///
/// This stream supports dynamic member lookup so that you can pluck out a specific field in the
/// state.
@dynamicMemberLookup
public final class DynamicStream<State>: AsyncSequence {
    public typealias Element = State

    fileprivate var continuations: [AsyncStream<Element>.Continuation] = []

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

    private let upstream: AsyncStream<State>

    public init(_ upstream: AsyncStream<State>) {
        self.upstream = upstream
    }

    deinit {
        continuations.forEach { $0.finish() }
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(upstream.makeAsyncIterator())
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
        return stream.map { $0[keyPath: keyPath] }
    }
}
