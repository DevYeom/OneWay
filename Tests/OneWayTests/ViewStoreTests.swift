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

    func test_dynamicStream() async {
        sut.send(.concat)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, [0, 1, 2, 3, 4])
    }

    func test_dynamicStreamForMultipleConsumers() async {
        let expectation = expectation(description: #function)

        actor Result {
            let expectation: XCTestExpectation
            var values: [Int] = [] {
                didSet {
                    if values.reduce(0, +) == 30 {
                        expectation.fulfill()
                    }
                }
            }
            var count: Int { values.count }

            init(_ expectation: XCTestExpectation) {
                self.expectation = expectation
            }

            func insert(_ value: Int) {
                values.append(value)
            }
        }

        let result = Result(expectation)
        Task {
            for await state in sut.states {
                await result.insert(state.count)
            }
        }
        Task {
            for await count in sut.states.count {
                await result.insert(count)
            }
        }
        Task {
            for await count in sut.states.count {
                await result.insert(count)
            }
        }

        try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
        sut.send(.concat)

        await fulfillment(of: [expectation], timeout: 1)

        var values = await result.values
        // Depending on the time of observation, the initial value may not be received, so the
        // initial value is excluded.
        values.removeAll(where: { $0 == 0 })
        XCTAssertEqual(
            values.sorted(),
            [
                1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4,
            ]
        )
    }
}

fileprivate final class TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case twice
        case concat
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
        }
    }
}
