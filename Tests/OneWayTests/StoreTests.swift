//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Combine
import OneWay
import XCTest

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
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
        let initialState = await sut.initialState
        let state = await sut.state
        let states = await sut.states

        XCTAssertEqual(initialState, TestReducer.State(count: 0, text: ""))
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
        let sut = sut!
        DispatchQueue.concurrentPerform(
            iterations: iterations / 2,
            execute: { _ in
                Task.detached {
                    await sut.send(.increment)
                }
            }
        )
        for _ in 0 ..< iterations / 2 {
            Task.detached {
                await sut.send(.increment)
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

    func test_bind() async {
        var result: Set<String> = []

        // https://forums.swift.org/t/how-to-use-combine-publisher-with-swift-concurrency-publisher-values-could-miss-events/67193
        Task {
            try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            textPublisher.send("first")
            numberPublisher.send(1)
            try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            textPublisher.send("second")
            numberPublisher.send(2)
        }

        let states = await sut.states
        for await state in states {
            result.insert(state.text)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, ["", "first", "1", "second", "2"])
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

private let textPublisher = PassthroughSubject<String, Never>()
private let numberPublisher = PassthroughSubject<Int, Never>()

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
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

    func bind() -> AnyEffect<Action> {
        return .merge(
            .sequence { send in
                for await text in textPublisher.values {
                    send(Action.response(text))
                }
            },
            .sequence { send in
                for await number in numberPublisher.values {
                    send(Action.response(String(number)))
                }
            }
        )
    }
}
