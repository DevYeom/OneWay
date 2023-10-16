//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

final class StoreTests: XCTestCase {
    private var sut: Store<TestReducer>!

    override func setUp() {
        super.setUp()
        sut = Store(
            reducer: TestReducer(),
            state: .init(count: 0, text: "")
        )
    }

    func test_initialState() async {
        let state = await sut.state
        let states = await sut.states
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.text, "")

        for await state in states {
            XCTAssertEqual(state.count, 0)
            XCTAssertEqual(state.text, "")
            break
        }
    }

    func test_sendSeveralActions() async {
        await sut.send(.increment)
        await sut.send(.increment)
        await sut.send(.twice)

        while await sut.state.count < 4 {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, 4)
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

    func test_asyncAction() async {
        await sut.send(.request)

        while await sut.state.text.isEmpty {
            await Task.yield()
        }

        let state = await sut.state
        XCTAssertEqual(state.count, 0)
        XCTAssertEqual(state.text, "Success")
    }

    func test_removeDuplicates() async {
        await sut.send(.response("First"))
        await sut.send(.response("First"))
        await sut.send(.response("First"))
        await sut.send(.response("Second"))
        await sut.send(.response("Second"))
        await sut.send(.response("Third"))

        var result: [String] = []
        let states = await sut.states
        for await state in states {
            result.append(state.text)
            if result.count > 3 {
                break
            }
        }

        XCTAssertEqual(result, ["", "First", "Second", "Third"])
    }
}

fileprivate final class TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case incrementMany
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
