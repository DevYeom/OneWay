//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

@MainActor
final class ViewStoreTests: XCTestCase {
    private var sut: ViewStore<TestReducer>!

    override func setUp() {
        super.setUp()
        sut = ViewStore(
            reducer: TestReducer(),
            state: .init(count: 0)
        )
    }

    override func tearDown() {
        super.tearDown()
        sut = nil
    }

    func test_initialState() async {
        XCTAssertEqual(sut.initialState, TestReducer.State(count: 0))
        XCTAssertEqual(sut.state.count, 0)

        for await state in sut.states {
            XCTAssertEqual(state.count, 0)
            XCTAssertEqual(Thread.isMainThread, true)
            break
        }
    }

    func test_sendSeveralActions() async {
        sut.send(.increment)
        sut.send(.increment)
        sut.send(.twice)

        await sendableExpect { await sut.state.count == 4 }
    }

    func test_sensitiveState() async {
        actor Result {
            var counts: [Int] = []
            var sensitiveCounts: [Int] = []
            func appendCount(_ count: Int) {
                counts.append(count)
            }
            func appendSensitiveCount(_ count: Int) {
                sensitiveCounts.append(count)
            }
        }
        let result = Result()

        Task { @MainActor in
            for await state in sut.states {
                await result.appendCount(state.count)
            }
        }
        Task { @MainActor in
            for await sensitiveCount in sut.states.sensitiveCount {
                await result.appendSensitiveCount(sensitiveCount)
            }
        }

        sut.send(.setSensitiveCount(10))
        sut.send(.setSensitiveCount(10))
        sut.send(.setSensitiveCount(10))

        await sendableExpect { await result.counts == [0, 0, 0, 0] }
        await sendableExpect { await result.sensitiveCounts == [0, 10, 10, 10] }
    }

    func test_insensitiveState() async {
        actor Result {
            var counts: [Int] = []
            var insensitiveCounts: [Int] = []
            func appendCount(_ count: Int) {
                counts.append(count)
            }
            func appendInsensitiveCount(_ count: Int) {
                insensitiveCounts.append(count)
            }
        }
        let result = Result()

        Task { @MainActor in
            for await state in sut.states {
                await result.appendCount(state.count)
            }
        }
        Task { @MainActor in
            for await insensitiveCount in sut.states.insensitiveCount {
                await result.appendInsensitiveCount(insensitiveCount)
            }
        }

        sut.send(.setInsensitiveCount(10))
        sut.send(.setInsensitiveCount(20))
        sut.send(.setInsensitiveCount(30))

        // only initial value
        await sendableExpect { await result.counts == [0] }
        await sendableExpect { await result.insensitiveCounts == [0] }
    }

    func test_asyncViewStateSequence() async {
        sut.send(.concat)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, [0, 1, 2, 3, 4])
    }

    func test_asyncViewStateSequenceForMultipleConsumers() async {
        let expectation = expectation(description: #function)

        let result = Result(expectation, expectedCount: 15)
        Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.consumeAsyncViewStateSequence1(result) }
                group.addTask { await self.consumeAsyncViewStateSequence2(result) }
                group.addTask { await self.consumeAsyncViewStateSequence3(result) }
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

extension ViewStoreTests {
    private func consumeAsyncViewStateSequence1(_ result: Result) async {
        for await state in sut.states {
            await result.insert(state.count)
        }
    }

    private func consumeAsyncViewStateSequence2(_ result: Result) async {
        for await count in sut.states.count {
            await result.insert(count)
        }
    }

    private func consumeAsyncViewStateSequence3(_ result: Result) async {
        for await count in sut.states.count {
            await result.insert(count)
        }
    }
}

private struct TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case twice
        case concat
        case setCount(Int)
        case setSensitiveCount(Int)
        case setInsensitiveCount(Int)
    }

    struct State: Equatable {
        var count: Int
        @Sensitive var sensitiveCount: Int = 0
        @Insensitive var insensitiveCount: Int = 0
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

        case .setSensitiveCount(let count):
            state.sensitiveCount = count
            return .none

        case .setInsensitiveCount(let count):
            state.insensitiveCount = count
            return .none
        }
    }
}

private actor Result {
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
