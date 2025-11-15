//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Testing
import OneWay

#if !os(Linux)
@MainActor
struct ViewStoreTests {
    private var sut: ViewStore<TestReducer, ContinuousClock>!

    init() {
        sut = ViewStore(
            reducer: TestReducer(),
            state: TestReducer.State(count: 0)
        )
    }

    @Test
    func initialState() async {
        #expect(self.sut.initialState == TestReducer.State(count: 0))
        #expect(self.sut.state.count == 0)

        for await state in sut.states {
            #expect(state.count == 0)
            break
        }
    }

    @Test
    func sendSeveralActions() async {
        sut.send(.increment)
        sut.send(.increment)
        sut.send(.twice)

        var result: [Int] = []
        for await state in sut.states {
            result.append(state.count)
            if result.count > 4 {
                break
            }
        }

        #expect(result == [0, 1, 2, 3, 4])
    }

    @Test
    func triggeredState() async {
        actor TestResult {
            var counts: [Int] = []
            var triggeredCounts: [Int] = []
            func appendCount(_ count: Int) {
                counts.append(count)
            }
            func appendTriggeredCount(_ count: Int) {
                triggeredCounts.append(count)
            }
        }
        let result = TestResult()

        Task { @MainActor in
            for await state in sut.states {
                await result.appendCount(state.count)
            }
        }
        Task { @MainActor in
            for await triggeredCount in sut.states.triggeredCount {
                await result.appendTriggeredCount(triggeredCount)
            }
        }

        sut.send(.setTriggeredCount(10))
        sut.send(.setTriggeredCount(10))
        sut.send(.setTriggeredCount(10))

        await expect(
            result,
            expectedCounts: [0, 0, 0, 0],
            expectedTriggeredCounts: [0, 10, 10, 10]
        )

        func expect(
            _ result: TestResult,
            expectedCounts: [Int],
            expectedTriggeredCounts: [Int],
            timeout: Duration = .seconds(1)
        ) async {
            let clock = ContinuousClock()
            let deadline = clock.now + timeout
            while clock.now < deadline {
                let counts = await result.counts
                let triggeredCounts = await result.triggeredCounts
                if counts == expectedCounts && triggeredCounts == expectedTriggeredCounts {
                    #expect(true)
                    return
                } else {
                    await Task.yield()
                }
            }
            Issue.record("Exceeded timeout of \(timeout.components.seconds) seconds")
        }
    }

    @Test
    func ignoredState() async {
        actor TestResult {
            var counts: [Int] = []
            var ignoredCounts: [Int] = []
            func appendCount(_ count: Int) {
                counts.append(count)
            }
            func appendIgnoredCount(_ count: Int) {
                ignoredCounts.append(count)
            }
        }
        let result = TestResult()

        Task { @MainActor in
            for await state in sut.states {
                await result.appendCount(state.count)
            }
        }
        Task { @MainActor in
            for await ignoredCount in sut.states.ignoredCount {
                await result.appendIgnoredCount(ignoredCount)
            }
        }

        sut.send(.setIgnoredCount(10))
        sut.send(.setIgnoredCount(20))
        sut.send(.setIgnoredCount(30))

        // only initial value
        await expect(
            result,
            expectedCounts: [0],
            expectedIgnoredCounts: [0]
        )

        func expect(
            _ result: TestResult,
            expectedCounts: [Int],
            expectedIgnoredCounts: [Int],
            timeout: Duration = .seconds(1)
        ) async {
            let clock = ContinuousClock()
            let deadline = clock.now + timeout
            while clock.now < deadline {
                let counts = await result.counts
                let ignoredCounts = await result.ignoredCounts
                if counts == expectedCounts && ignoredCounts == expectedIgnoredCounts {
                    #expect(true)
                    return
                } else {
                    await Task.yield()
                }
            }
            Issue.record("Exceeded timeout of \(timeout.components.seconds) seconds")
        }
    }

    @Test
    func asyncViewStateSequence() async {
        sut.send(.concat)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        #expect(result == [0, 1, 2, 3, 4])
    }

    @Test
    func asyncViewStateSequenceForMultipleConsumers() async {
        let sut = sut!
        let result = TestResult(expectedCount: 15)
        Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await state in await sut.states {
                        await result.insert(state.count)
                    }
                }
                group.addTask {
                    for await count in await sut.states.count {
                        await result.insert(count)
                    }
                }
                group.addTask {
                    for await count in await sut.states.count {
                        await result.insert(count)
                    }
                }
            }
        }

        try! await Task.sleep(for: .milliseconds(10))
        sut.send(.concat)

        await result.waitForCompletion(timeout: 1)

        let values = await result.values
        let expectation = [
            0, 0, 0,
            1, 1, 1,
            2, 2, 2,
            3, 3, 3,
            4, 4, 4,
        ]
        #expect(values.sorted() == expectation)
    }

    @Test
    func logging_options() {
        let _ = ViewStore(
            reducer: TestReducer(),
            state: TestReducer.State(count: 0)
        )
        .debug(.all)
        .debug(.none)
        .debug(.action)
        .debug(.state)
    }
}

private struct TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case twice
        case concat
        case setCount(Int)
        case setTriggeredCount(Int)
        case setIgnoredCount(Int)
    }

    struct State: Equatable {
        var count: Int
        @Triggered var triggeredCount: Int = 0
        @Ignored var ignoredCount: Int = 0
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .twice:
            return .merge(
                .just(.increment),
                .just(.increment)
            )

        case .concat:
            return .concat(
                .just(.increment),
                .just(.increment),
                .just(.increment),
                .just(.increment)
            )

        case .setCount(let count):
            state.count = count
            return .none

        case .setTriggeredCount(let count):
            state.triggeredCount = count
            return .none

        case .setIgnoredCount(let count):
            state.ignoredCount = count
            return .none
        }
    }
}

private actor TestResult {
    private var continuation: CheckedContinuation<Void, Never>?
    let expectedCount: Int
    var values: [Int] = [] {
        didSet {
            if values.count >= expectedCount {
                continuation?.resume()
                continuation = nil
            }
        }
    }
    var count: Int { values.count }

    init(expectedCount: Int) {
        self.expectedCount = expectedCount
    }

    func insert(_ value: Int) {
        values.append(value)
    }

    func waitForCompletion(timeout: Double) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            Task {
                try await Task.sleep(for: .seconds(timeout))
                self.continuation?.resume()
                self.continuation = nil
            }
        }
    }
}
#endif
