//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Clocks
import Combine
import OneWay
import XCTest

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class StoreTests: XCTestCase {
    private var sut: Store<TestReducer>!

    override func setUp() {
        super.setUp()
        sut = Store(
            reducer: TestReducer(),
            state: .init(count: 0, text: "")
        )
    }

    override func tearDown() {
        super.tearDown()
        sut = nil
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

        await expect { await sut.state.count == 4 }
        await expect { await sut.state.text == "" }
    }

    func test_lotsOfActions() async {
        let iterations: Int = 100_000
        await sut.send(.incrementMany)

        await expect(
            compare: { await sut.state.count == iterations },
            timeout: 10
        )
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

        await expect(
            compare: { await sut.state.count == iterations },
            timeout: 10
        )
    }

    func test_asyncAction() async {
        await sut.send(.request)

        await expect { await sut.state.text == "Success" }
    }

    func test_bind() async {
        var result: Set<String> = []

        // https://forums.swift.org/t/how-to-use-combine-publisher-with-swift-concurrency-publisher-values-could-miss-events/67193
        Task {
            try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            textPublisher.send("first")
            numberPublisher.send(1)
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

    func test_cancel() async {
        _clock = TestClock()

        do {
            await sut.send(.longTimeTask)
            await _clock.advance(by: .seconds(200))

            let text = await sut.state.text
            XCTAssertEqual(text, "Success")
        }

        await sut.send(.response(""))

        do {
            await sut.send(.longTimeTask)
            await _clock.advance(by: .seconds(100))

            await sut.send(.cancelLongTimeTask)
            await _clock.advance(by: .seconds(100))

            let text = await sut.state.text
            XCTAssertEqual(text, "")
        }
    }
}

private let textPublisher = PassthroughSubject<String, Never>()
private let numberPublisher = PassthroughSubject<Int, Never>()

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
private var _clock = TestClock()

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
private struct TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case incrementMany
        case twice
        case request
        case response(String)
        case longTimeTask
        case cancelLongTimeTask
    }

    struct State: Equatable {
        var count: Int
        var text: String
    }

    private enum EffectID: Hashable {
        case longTimeTask
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
            return .single {
                return Action.response("Success")
            }

        case .response(let response):
            state.text = response
            return .none

        case .longTimeTask:
            return .single {
                try! await _clock.sleep(for: .seconds(200))
                return Action.response("Success")
            }
            .cancellable(EffectID.longTimeTask)

        case .cancelLongTimeTask:
            return .cancel(EffectID.longTimeTask)
        }
    }

    func bind() -> AnyEffect<Action> {
        return .merge(
            .sequence { send in
                for await text in textPublisher.stream {
                    send(Action.response(text))
                }
            },
            .sequence { send in
                for await number in numberPublisher.stream {
                    send(Action.response(String(number)))
                }
            }
        )
    }
}
