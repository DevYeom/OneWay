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
    /// state changes
    public var states: AsyncStream<State>

    private let reducer: any Reducer<Action, State>
    private let continuation: AsyncStream<State>.Continuation
    private var isProcessing: Bool = false
    private var isIdle: Bool { !isProcessing && tasks.isEmpty }
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
        let count = actionQueue.count
        for index in Int.zero ..< count {
            let action = actionQueue[index]
            let taskID = TaskID()
            let effect = reducer.reduce(state: &state, action: action)
            let task = Task { [weak self, taskID] in
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
                if cancelInFlight {
                    let taskIDs = cancellables[EffectIDWrapper(id), default: []]
                    taskIDs.forEach { removeTask($0) }
                }
                cancellables[EffectIDWrapper(id), default: []].insert(taskID)
            case let .cancel(id):
                let taskIDs = cancellables[EffectIDWrapper(id), default: []]
                taskIDs.forEach { removeTask($0) }
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

#if canImport(Testing) && canImport(CoreFoundation)
import CoreFoundation
import Testing

extension Store {
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
    public func expect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: TimeInterval = 2,
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) async {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        if isTimeout && result != input {
            Issue.record("Exceeded timeout of \(timeout) seconds", sourceLocation: sourceLocation)
        } else {
            #expect(result == input, sourceLocation: sourceLocation)
        }
    }
}
#endif

#if canImport(XCTest) && canImport(CoreFoundation)
import CoreFoundation
import XCTest

extension Store {
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
    public func xctExpect<Property: Equatable>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        if isTimeout && result != input {
            XCTFail("Exceeded timeout of \(timeout) seconds", file: file, line: line)
        } else {
            XCTAssertEqual(result, input, file: file, line: line)
        }
    }
}
#endif
