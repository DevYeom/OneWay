//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Testing) && canImport(Darwin)
import Darwin
import Testing
import OneWay

@testable import OneWayTesting

struct TestingTests {
    @Test
    func testingFramework() {
        #expect(TestingFramework.current == TestingFramework.testing)
    }

    @Test
    func storeExpect() async {
        let store = Store(
            reducer: TestReducer(),
            state: TestReducer.State(count: 0)
        )
        await store.expect(\.count, 0)

        await store.send(.increment)
        await store.expect(\.count, 1)

        await store.send(.increment)
        await store.expect(\.count, 2)

        await store.send(.setName("hello"))
        await store.expect(\.nested.name, "hello")

        await store.send(.setValue(1.23))
        await store.expect(\.nested.doubleNested.value, 1.23)
    }

    @Test
    func storeExpectWithManyActions() async {
        let store = Store(
            reducer: TestReducer(),
            state: TestReducer.State(count: 0)
        )
        await store.expect(\.count, 0)

        for _ in 0..<10_000 {
            await store.send(.increment)
        }
        await store.expect(\.count, 10_000)

        await store.send(.delayedIncrement)
        await store.expect(\.count, 10_001)
    }
}

private struct TestReducer: Reducer {
    enum Action: Sendable {
        case increment
        case delayedIncrement
        case setName(String)
        case setValue(Double)
    }

    struct State: Sendable, Equatable {
        var count: Int
        var nested = Nested()
        struct Nested: Sendable, Equatable {
            var name: String = ""
            var doubleNested = DoubleNested(value: 0)
            struct DoubleNested: Sendable, Equatable {
                var value: Double
            }
        }
    }

    func reduce(state: inout State, action: Action) -> AnyEffect<Action> {
        switch action {
        case .increment:
            state.count += 1
            return .none
        case .delayedIncrement:
            return .single {
                try! await Task.sleep(nanoseconds: NSEC_PER_MSEC * 100)
                return .increment
            }
        case let .setName(name):
            state.nested.name = name
            return .none
        case let .setValue(value):
            state.nested.doubleNested.value = value
            return .none
        }
    }
}
#endif
