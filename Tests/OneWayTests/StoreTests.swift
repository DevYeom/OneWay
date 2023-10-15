//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

final class StoreTests: XCTestCase {
    private var sut: Store<TestReducer.Action, TestReducer.State>!

    override func setUp() {
        super.setUp()
        sut = Store(
            reducer: TestReducer(),
            state: .init(count: 0, text: "")
        )
    }

    func test_initialState() async {
        let state = await sut.state
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.text, "")
    }

    func test_sendSeveralActions() async {
        await sut.send(.increment)
        await sut.send(.increment)
        await sut.send(.decrement)
        await sut.send(.twice)

        while await sut.state.count < 3 {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, 3)
        XCTAssertEqual(state.text, "")
    }

    func test_lotsOfActions() async {
        let iterations: Int = 100_000
        await sut.send(.incrementMany)

        while await sut.state.count < iterations {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, iterations)
        XCTAssertEqual(state.text, "")
    }

    func test_threadSafeSendingActions() async {
        let iterations: Int = 10_000
        DispatchQueue.concurrentPerform(
            iterations: iterations / 2,
            execute: { _ in
                Task.detached {
                    await self.sut.send(.increment)
                }
            }
        )
        for _ in 0 ..< iterations / 2 {
            Task.detached {
                await self.sut.send(.increment)
            }
        }

        while await sut.state.count < iterations {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, iterations)
        XCTAssertEqual(state.text, "")
    }

    func test_delayedAction() async {
        await sut.send(.request)

        while await sut.state.text.isEmpty {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.text, "Success")
    }
}

fileprivate final class TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case incrementMany
        case decrement
        case twice
        case request
        case response(String)
    }

    struct State: Equatable {
        var count: Int
        var text: String
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .incrementMany:
            state.count += 1
            return state.count >= 100_000 ? .none : .just(.incrementMany)

        case .decrement:
            state.count -= 1
            return .none

        case .twice:
            return .merge(
                .just(.increment),
                .just(.increment)
            )

        case .request:
            return .async {
                return Action.response("Success")
            }

        case .response(let response):
            state.text = response
            return .none
        }
    }
}
