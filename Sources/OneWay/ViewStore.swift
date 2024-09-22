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

#if canImport(Testing)
import Testing

extension ViewStore {
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value. The
    /// function works asynchronously, yielding control to allow other tasks to execute, especially
    /// when the store is processing or updating its state.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - sourceLocation: The source location for tracking the test location.
    #if swift(>=6)
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: TimeInterval = 2,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(keyPath, input, timeout: timeout, sourceLocation: sourceLocation)
    }
    #else
    public func expect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: TimeInterval = 2,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.expect(keyPath, input, timeout: timeout, sourceLocation: sourceLocation)
    }
    #endif
}
#endif

#if canImport(XCTest)
import XCTest

extension ViewStore {
    /// An `XCTest`-specific helper that asynchronously waits for the store to finish processing
    /// before comparing a specific property in the state to an expected value. It uses
    /// `XCTAssertEqual` to validate that the retrieved value matches the input.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - file: The file path from which the function is called (default is the current file).
    ///   - line: The line number from which the function is called (default is the current line).
    #if swift(>=6)
    public func xctExpect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.xctExpect(keyPath, input, timeout: timeout, file: file, line: line)
    }
    #else
    public func xctExpect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        await Task { @MainActor in
            await Task.yield()
        }.value
        await store.xctExpect(keyPath, input, timeout: timeout, file: file, line: line)
    }
    #endif
}
#endif
#endif
