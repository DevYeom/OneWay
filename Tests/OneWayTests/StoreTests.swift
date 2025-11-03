//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Clocks
#if canImport(Combine)
import Combine
#endif
import OneWay
import OneWayTesting
import XCTest

final class StoreTests: XCTestCase {
    private var sut: Store<TestReducer, TestClock<Duration>>!
    private var clock: TestClock<Duration>!

    override func setUp() {
        super.setUp()
        let clock = TestClock()
        self.clock = clock
        sut = Store(
            reducer: TestReducer(clock: clock),
            state: TestReducer.State(count: 0, text: ""),
            clock: clock
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

        await sut.expect(\.count, 4)
        await sut.expect(\.text, "")
    }

    func test_lotsOfActions() async {
        let iterations: Int = 100_000
        await sut.send(.incrementMany)
        await sut.expect(\.count, iterations, timeout: 10)
    }

    func test_threadSafeSendingActions() async {
        let iterations: Int = 100_000
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

        await sut.expect(\.count, iterations)
    }

    func test_asyncAction() async {
        await sut.send(.request)
        await sut.expect(\.text, "Success")
    }

    #if canImport(Combine)
    func test_bind() async {
        var result: Set<String> = []

        // https://forums.swift.org/t/how-to-use-combine-publisher-with-swift-concurrency-publisher-values-could-miss-events/67193
        Task {
            try! await Task.sleep(nanoseconds: NSEC_PER_MSEC)
            testPublisher.text.send("first")
            testPublisher.number.send(1)
            testPublisher.text.send("second")
            testPublisher.number.send(2)
        }

        let states = await sut.states
        for await state in states {
            result.insert(state.text)
            if result.count > 4 { break }
        }

        XCTAssertEqual(result, ["", "first", "1", "second", "2"])
    }
    #endif

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
        do {
            let before = await sut.state.text
            XCTAssertEqual(before, "")

            await sut.send(.longTimeTask)
            await clock.advance(by: .seconds(200 + 1))

            let after = await sut.state.text
            XCTAssertEqual(after, "Success")
        }

        await sut.send(.response(""))

        do {
            await sut.send(.longTimeTask)
            await clock.advance(by: .seconds(100))

            await sut.send(.cancelLongTimeTask)
            await clock.advance(by: .seconds(100))

            let text = await sut.state.text
            XCTAssertEqual(text, "")
        }
    }

    func test_debounce() async {
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(100))
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(100))

        await sut.expect(\.count, 2)

        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(10)) // 10s < 100s

        await sut.expect(\.count, 2)
    }

    func test_deboouncedSequence() async {
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(100))
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(100))

        await sut.expect(\.count, 10)

        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            await sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(10)) // 10s < 100s

        await sut.expect(\.count, 10)
    }

    func test_throttle() async {
        await sut.send(.throttledIncrement)
        await sut.send(.throttledIncrement)
        await clock.advance(by: .seconds(10))
        await sut.send(.throttledIncrement)
        await sut.expect(\.count, 1)

        await clock.advance(by: .seconds(100))
        await sut.expect(\.count, 1)

        await sut.send(.throttledIncrement)
        await sut.expect(\.count, 2)
    }

    func test_throttle_latest() async {
        await sut.send(.throttledIncrementLatest)
        await sut.expect(\.count, 1)

        await sut.send(.throttledIncrementLatest)
        await sut.expect(\.count, 1)

        await clock.advance(by: .seconds(100))
        await sut.expect(\.count, 2)

        await sut.send(.throttledIncrementLatest)
        await clock.advance(by: .seconds(10))
        await sut.send(.throttledIncrementLatest)
        await sut.expect(\.count, 3)

        await clock.advance(by: .seconds(100))
        await sut.expect(\.count, 4)
    }
}

#if canImport(Combine)
/// Just for testing
private struct TestPublisher: @unchecked Sendable {
    let text = PassthroughSubject<String, Never>()
    let number = PassthroughSubject<Int, Never>()
}
private let testPublisher = TestPublisher()
#endif

private struct TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case incrementMany
        case twice
        case request
        case response(String)
        case longTimeTask
        case cancelLongTimeTask
        case debouncedIncrement
        case debouncedSequence
        case throttledIncrement
        case throttledIncrementLatest
    }

    struct State: Equatable {
        var count: Int
        var text: String
    }

    private enum EffectID: Hashable {
        case longTimeTask
    }

    private let clock: TestClock<Duration>

    init(clock: TestClock<Duration>) {
        self.clock = clock
    }

    enum Debounce {
        case increment
        case incrementSequence
    }

    enum Throttle {
        case increment
        case incrementLatest
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
                try? await clock.sleep(for: .seconds(200))
                return Action.response("Success")
            }
            .cancellable(EffectID.longTimeTask)

        case .cancelLongTimeTask:
            return .cancel(EffectID.longTimeTask)

        case .debouncedIncrement:
            return .just(.increment)
                .debounce(id: Debounce.increment, for: .seconds(100), clock: clock)

        case .debouncedSequence:
            return .sequence { send in
                send(.increment)
                send(.increment)
                send(.increment)
                send(.increment)
                send(.increment)
            }
            .debounce(id: Debounce.incrementSequence, for: .seconds(100), clock: clock)

        case .throttledIncrement:
            return .just(.increment)
                .throttle(id: Throttle.increment, for: .seconds(100))

        case .throttledIncrementLatest:
            return .just(.increment)
                .throttle(id: Throttle.incrementLatest, for: .seconds(100), latest: true)
        }
    }

#if canImport(Combine)
    func bind() -> AnyEffect<Action> {
        return .merge(
            .sequence { send in
                for await text in testPublisher.text.stream {
                    send(Action.response(text))
                }
            },
            .sequence { send in
                for await number in testPublisher.number.stream {
                    send(Action.response(String(number)))
                }
            }
        )
    }
#endif
}
