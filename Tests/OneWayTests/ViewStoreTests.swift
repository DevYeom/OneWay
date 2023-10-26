//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
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

        while sut.state.count < 4 {
            await Task.yield()
        }

        XCTAssertEqual(sut.state.count, 4)
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

        let result = Result(expectation, target: 30)
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.consumeAsyncViewStateSequence1(result) }
                group.addTask { await self.consumeAsyncViewStateSequence2(result) }
                group.addTask { await self.consumeAsyncViewStateSequence3(result) }
            }
        }

        try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
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

    func test_asyncRemoveDuplicatesSequence() async {
        let expectation = expectation(description: #function)

        let result = Result(expectation, target: 20)
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.consumeAsyncViewStateSequence2(result) }
                group.addTask { await self.consumeAsyncViewStateSequence3(result) }
            }
        }

        try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        sut.send(.setCount(10))
        sut.send(.setCount(10))
        sut.send(.setCount(10))
        sut.send(.setCount(10))
        sut.send(.setCount(10))

        await fulfillment(of: [expectation], timeout: 1)

        let values = await result.values
        XCTAssertEqual(values.sorted(), [0, 0, 10, 10])
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

private final class TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case twice
        case concat
        case setCount(Int)
    }

    struct State: Equatable {
        var count: Int
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
        }
    }
}

private actor Result {
    let expectation: XCTestExpectation
    let target: Int
    var values: [Int] = [] {
        didSet {
            if values.reduce(0, +) == target {
                expectation.fulfill()
            }
        }
    }
    var count: Int { values.count }

    init(_ expectation: XCTestExpectation, target: Int) {
        self.expectation = expectation
        self.target = target
    }

    func insert(_ value: Int) {
        values.append(value)
    }
}
