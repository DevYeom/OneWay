//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2026 Seungyeop Yeom ( https://github.com/DevYeom ).
//

import Testing
#if canImport(Combine)
import Combine
#endif
import Clocks
import OneWay
#if canImport(CoreFoundation)
import CoreFoundation
#endif

#if !os(Linux)
@MainActor
struct ViewStoreTests {
    private var sut: ViewStore<TestReducer, TestClock<Duration>>!
    private var clock: TestClock<Duration>!

    init() {
        let clock = TestClock()
        self.clock = clock
        sut = ViewStore(
            reducer: TestReducer(clock: clock),
            state: TestReducer.State(count: 0, text: ""),
            clock: clock
        )
    }

    @Test
    func initialState() async {
        #expect(self.sut.initialState == TestReducer.State(count: 0, text: ""))
        #expect(self.sut.state.count == 0)
        #expect(self.sut.state.text == "")

        for await state in sut.states {
            #expect(state.count == 0)
            #expect(state.text == "")
            break
        }
    }

    @Test
    func sendSeveralActions() async {
        sut.send(.increment)
        sut.send(.increment)
        sut.send(.twice)

        var result: [Int] = []
        for await state in sut.states {
            result.append(state.count)
            if result.count > 4 {
                break
            }
        }

        #expect(result == [0, 1, 2, 3, 4])
    }

    @Test
    func triggeredState() async {
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

        await Task.yield() // Allow observer tasks to start

        sut.send(.setTriggeredCount(10))
        sut.send(.setTriggeredCount(10))
        sut.send(.setTriggeredCount(10))

        await expect(
            result,
            expectedCounts: [0, 0, 0, 0],
            expectedTriggeredCounts: [0, 10, 10, 10]
        )

        func expect(
            _ result: TestResult,
            expectedCounts: [Int],
            expectedTriggeredCounts: [Int],
            timeout: Duration = .seconds(1)
        ) async {
            let deadline = clock.now.advanced(by: timeout)
            while clock.now < deadline {
                let counts = await result.counts
                let triggeredCounts = await result.triggeredCounts
                if counts == expectedCounts && triggeredCounts == expectedTriggeredCounts {
                    #expect(true)
                    return
                } else {
                    await Task.yield()
                }
            }
            Issue.record("Exceeded timeout of \(timeout.components.seconds) seconds")
        }
    }

    @Test
    func ignoredState() async {
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
        
        await Task.yield()

        sut.send(.setIgnoredCount(10))
        sut.send(.setIgnoredCount(20))
        sut.send(.setIgnoredCount(30))

        // only initial value
        await expect(
            result,
            expectedCounts: [0],
            expectedIgnoredCounts: [0]
        )

        func expect(
            _ result: TestResult,
            expectedCounts: [Int],
            expectedIgnoredCounts: [Int],
            timeout: Duration = .seconds(1)
        ) async {
            let deadline = clock.now.advanced(by: timeout)
            while clock.now < deadline {
                let counts = await result.counts
                let ignoredCounts = await result.ignoredCounts
                if counts == expectedCounts && ignoredCounts == expectedIgnoredCounts {
                    #expect(true)
                    return
                } else {
                    await Task.yield()
                }
            }
            Issue.record("Exceeded timeout of \(timeout.components.seconds) seconds")
        }
    }

    @Test
    func asyncViewStateSequence() async {
        sut.send(.concat)

        var result: [Int] = []
        for await count in sut.states.count {
            result.append(count)
            if result.count > 4 { break }
        }

        #expect(result == [0, 1, 2, 3, 4])
    }

    @Test
    func asyncViewStateSequenceForMultipleConsumers() async {
        let sut = sut!
        let result = TestResult(expectedCount: 15)
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

        try! await Task.sleep(for: .milliseconds(100))
        sut.send(.concat)

        await result.waitForCompletion(timeout: 1)

        let values = await result.values
        let expectation = [
            0, 0, 0,
            1, 1, 1,
            2, 2, 2,
            3, 3, 3,
            4, 4, 4,
        ]
        #expect(values.sorted() == expectation)
    }

    @Test
    func logging_options() {
        let _ = ViewStore(
            reducer: TestReducer(clock: TestClock()),
            state: TestReducer.State(count: 0)
        )
        .debug(.all)
        .debug(.none)
        .debug(.action)
        .debug(.state)
    }

    @Test
    func lotsOfActions() async {
        let iterations: Int = 100_000
        sut.send(.incrementMany)
        await sut.expect(\.count, iterations, timeout: 10)
    }

    @Test
    func threadSafeSendingActions() async {
        let iterations: Int = 100_000
        let sut = sut!
        for _ in 0 ..< iterations {
            Task.detached {
                await sut.send(.increment)
            }
        }

        await sut.expect(\.count, iterations)
    }

    @Test
    func asyncAction() async {
        sut.send(.request)
        await sut.expect(\.text, "Success")
    }

    #if canImport(Combine)
    @Test
    func bind() async {
        let sut = ViewStore(
            reducer: BindTestReducer(),
            state: BindTestReducer.State(text: "")
        )
        var result: Set<String> = []

        Task {
            try! await Task.sleep(for: .milliseconds(1))
            testPublisher.text.send("first")
            testPublisher.number.send(1)
            testPublisher.text.send("second")
            testPublisher.number.send(2)
        }

        let states = sut.states
        for await state in states {
            result.insert(state.text)
            if result.count > 4 { break }
        }

        #expect(result == ["", "first", "1", "second", "2"])
    }
    #endif

    @Test
    func removeDuplicates() async {
        sut.send(.response("First"))
        sut.send(.response("First"))
        sut.send(.response("First"))
        sut.send(.response("Second"))
        sut.send(.response("Second"))
        sut.send(.response("Third"))

        var result: [String] = []
        let states = sut.states
        for await state in states {
            result.append(state.text)
            if result.count > 3 {
                break
            }
        }

        #expect(result == ["", "First", "Second", "Third"])
    }

    @Test
    func cancel() async {
        do {
            let before = sut.state.text
            #expect(before == "")

            sut.send(.longTimeTask)
            await Task.yield()
            await clock.advance(by: .seconds(200 + 1))

            await sut.expect(\.text, "Success")
        }

        sut.send(.response(""))
        await sut.expect(\.text, "")

        do {
            sut.send(.longTimeTask)
            await Task.yield()
            await clock.advance(by: .seconds(100))
            await Task.yield()

            sut.send(.cancelLongTimeTask)
            await Task.yield()
            await clock.advance(by: .seconds(100))
            await Task.yield()

            let text = sut.state.text
            #expect(text == "")
        }
    }

    @Test
    func debounce() async {
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(100))
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(100))

        await sut.expect(\.count, 2)

        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedIncrement)
        }
        await clock.advance(by: .seconds(10)) // 10s < 100s

        await sut.expect(\.count, 2)
    }

    @Test
    func deboouncedSequence() async {
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(100))
        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(100))

        await sut.expect(\.count, 10)

        for _ in 0..<5 {
            await clock.advance(by: .seconds(10))
            sut.send(.debouncedSequence)
        }
        await clock.advance(by: .seconds(10)) // 10s < 100s

        await sut.expect(\.count, 10)
    }

    @Test
    func throttle() async {
        sut.send(.throttledIncrement)
        sut.send(.throttledIncrement)
        await clock.advance(by: .seconds(10))
        sut.send(.throttledIncrement)
        await sut.expect(\.count, 1)

        await clock.advance(by: .seconds(100))
        await sut.expect(\.count, 1)

        sut.send(.throttledIncrement)
        await sut.expect(\.count, 2)
    }

    @Test
    func throttle_latest() async {
        sut.send(.throttledIncrementLatest)
        await sut.expect(\.count, 1)

        sut.send(.throttledIncrementLatest)
        await sut.expect(\.count, 1)

        await clock.advance(by: .seconds(100))
        await sut.expect(\.count, 2)

        sut.send(.throttledIncrementLatest)
        await clock.advance(by: .seconds(10))
        sut.send(.throttledIncrementLatest)
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

private struct BindTestReducer: Reducer {
    enum Action: Sendable {
        case response(String)
    }

    struct State: Equatable {
        var text: String
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .response(let response):
            state.text = response
            return .none
        }
    }

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
}
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
        case concat
        case setCount(Int)
        case setTriggeredCount(Int)
        case setIgnoredCount(Int)
    }

    struct State: Equatable {
        var count: Int
        var text: String = ""
        @Triggered var triggeredCount: Int = 0
        @Ignored var ignoredCount: Int = 0
    }

    private enum EffectID: Hashable {
        case longTimeTask
    }

    private let clock: TestClock<Duration>?

    init(clock: TestClock<Duration>? = nil) {
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
                try? await clock?.sleep(for: .seconds(200))
                return Action.response("Success")
            }
            .cancellable(EffectID.longTimeTask)

        case .cancelLongTimeTask:
            return .cancel(EffectID.longTimeTask)

        case .debouncedIncrement:
            guard let clock = clock else { return .none }
            return .just(.increment)
                .debounce(id: Debounce.increment, for: .seconds(100), clock: clock)

        case .debouncedSequence:
            guard let clock = clock else { return .none }
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
    private var continuation: CheckedContinuation<Void, Never>?
    let expectedCount: Int
    var values: [Int] = [] {
        didSet {
            if values.count >= expectedCount {
                continuation?.resume()
                continuation = nil
            }
        }
    }
    var count: Int { values.count }

    init(expectedCount: Int) {
        self.expectedCount = expectedCount
    }

    func insert(_ value: Int) {
        values.append(value)
    }

    func waitForCompletion(timeout: Double) async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            Task {
                try await Task.sleep(for: .seconds(timeout))
                self.continuation?.resume()
                self.continuation = nil
            }
        }
    }
}
#endif
