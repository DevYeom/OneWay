//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

#if !os(Linux)
final class ViewStoreTests: XCTestCase {
    @MainActor
    private var sut: ViewStore<TestReducer>!

    @MainActor
    override func setUp() async throws {
        sut = ViewStore(
            reducer: TestReducer(),
            state: TestReducer.State(count: 0)
        )
    }

    @MainActor
    override func tearDown() async throws {
        sut = nil
    }

    @MainActor
    func test_initialState() async {
        XCTAssertEqual(sut.initialState, TestReducer.State(count: 0))
        XCTAssertEqual(sut.state.count, 0)

        for await state in sut.states {
            XCTAssertEqual(state.count, 0)
            XCTAssertEqual(Thread.isMainThread, true)
            break
        }
    }

    @MainActor
    func test_sendSeveralActions() async {
        sut.send(.increment)
        sut.send(.increment)
        sut.send(.twice)

        await sut.xctExpect(\.count, 4)
    }

    @MainActor
    func test_triggeredState() async {
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

        await sendableExpectWithMainActor { await result.counts == [0, 0, 0, 0] }
        await sendableExpectWithMainActor { await result.triggeredCounts == [0, 10, 10, 10] }
    }

    @MainActor
    func test_ignoredState() async {
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
        await sendableExpectWithMainActor { await result.counts == [0] }
        await sendableExpectWithMainActor { await result.ignoredCounts == [0] }
    }

    @MainActor
    func test_asyncViewStateSequence() async {
        sut.send(.concat)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, [0, 1, 2, 3, 4])
    }

    @MainActor
    func test_asyncViewStateSequenceForMultipleConsumers() async {
        let expectation = expectation(description: #function)

        let sut = sut!
        let result = TestResult(expectation, expectedCount: 15)
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

        try! await Task.sleep(nanoseconds: NSEC_PER_MSEC * 10)
        sut.send(.concat)

        await fulfillment(of: [expectation], timeout: 1)

        let values = await result.values
        XCTAssertEqual(
            values.sorted(),
            [
                0, 0, 0,
                1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4,
            ]
        )
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
    let expectation: XCTestExpectation
    let expectedCount: Int
    var values: [Int] = [] {
        didSet {
            if values.count >= expectedCount {
                expectation.fulfill()
            }
        }
    }
    var count: Int { values.count }

    init(_ expectation: XCTestExpectation, expectedCount: Int) {
        self.expectation = expectation
        self.expectedCount = expectedCount
    }

    func insert(_ value: Int) {
        values.append(value)
    }
}
#endif
