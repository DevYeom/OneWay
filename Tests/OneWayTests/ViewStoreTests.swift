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
        sut.send(.decrement)
        sut.send(.twice)

        while sut.state.count < 3 {
            await Task.yield()
        }

        XCTAssertEqual(sut.state.count, 3)
    }

    func test_dynamicMemberStream() async {
        sut.send(.increment)
        sut.send(.increment)
        sut.send(.decrement)
        sut.send(.decrement)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, [0, 1, 2, 1, 0])
    }
}

fileprivate final class TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case decrement
        case twice
    }

    struct State: Equatable {
        var count: Int
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none

        case .decrement:
            state.count -= 1
            return .none

        case .twice:
            return .merge(
                .just(.increment),
                .just(.increment)
            )
        }
    }
}
