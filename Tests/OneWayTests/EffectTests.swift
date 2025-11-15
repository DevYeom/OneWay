//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Testing
import Clocks
import OneWay

struct EffectTests {
    enum Action: Sendable, Equatable {
        case first
        case second
        case third
        case fourth
        case fifth
    }

    @Test
    func just() async {
        let values = Effects.Just(Action.first).values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        #expect(result == [.first])
    }

    @Test
    func cancel() async {
        let cancel = AnyEffect<Action>.cancel("100")
        let method = cancel.method

        if case .cancel(let id) = method {
            #expect(id as? String == "100")
        } else {
            Issue.record("method should be .cancel")
        }
    }

    @Test
    func cancellable() async {
        let effect = Effects.Just("").eraseToAnyEffect().cancellable("100")
        let method = effect.method

        if case let .register(id, _) = method {
            #expect(id as? String == "100")
        } else {
            Issue.record("method should be .register")
        }
    }

    @Test
    func single() async {
        let clock = TestClock()

        let values = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(100 + 1)) }
        for await value in values {
            result.append(value)
        }

        #expect(result == [.first])
    }

    @Test
    func sequence() async {
        let stream = AsyncStream { continuation in
            for number in 1 ... 5 {
                continuation.yield(number)
            }
            continuation.finish()
        }

        let values = Effects.Sequence { send in
            for await number in stream {
                let action: Action
                switch number {
                case 1: action = .first
                case 2: action = .second
                case 3: action = .third
                case 4: action = .fourth
                case 5: action = .fifth
                default:
                    action = .first
                    Issue.record("should not be reached")
                }
                send(action)
            }
        }.values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func concat() async {
        let clock = TestClock()

        let first = Effects.Just(Action.first).eraseToAnyEffect()
        let second = Effects.Single {
            try! await clock.sleep(for: .seconds(300))
            return Action.second
        }.eraseToAnyEffect()
        let third = Effects.Single {
            try! await clock.sleep(for: .seconds(200))
            return Action.third
        }.eraseToAnyEffect()
        let fourth = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.fourth
        }.eraseToAnyEffect()
        let fifth = Effects.Just(Action.fifth).eraseToAnyEffect()

        let values = Effects.Concat([
            first,
            second,
            third,
            fourth,
            fifth,
        ]).values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(100 + 200 + 300 + 1)) }
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func concatIncludingMerge() async {
        let clock = TestClock()

        let first = Effects.Single {
            try! await clock.sleep(for: .seconds(500))
            return Action.first
        }.eraseToAnyEffect()
        let second = Effects.Single {
            try! await clock.sleep(for: .seconds(200))
            return Action.second
        }.eraseToAnyEffect()
        let third = Effects.Single {
            try! await clock.sleep(for: .seconds(300))
            return Action.third
        }.eraseToAnyEffect()
        let fourth = Effects.Single {
            try! await clock.sleep(for: .seconds(400))
            return Action.fourth
        }.eraseToAnyEffect()
        let fifth = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.fifth
        }.eraseToAnyEffect()

        let values = Effects.Concat([
            first,
            Effects.Merge([fourth, third, second]).eraseToAnyEffect(),
            fifth,
        ]).values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(500 + 400 + 100 + 1)) }
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func merge() async {
        let clock = TestClock()

        let first = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.eraseToAnyEffect()
        let second = Effects.Single {
            try! await clock.sleep(for: .seconds(200))
            return Action.second
        }.eraseToAnyEffect()
        let third = Effects.Single {
            try! await clock.sleep(for: .seconds(300))
            return Action.third
        }.eraseToAnyEffect()
        let fourth = Effects.Single {
            try! await clock.sleep(for: .seconds(400))
            return Action.fourth
        }.eraseToAnyEffect()
        let fifth = Effects.Single {
            try! await clock.sleep(for: .seconds(500))
            return Action.fifth
        }.eraseToAnyEffect()

        let values = Effects.Merge([
            first,
            second,
            third,
            fourth,
            fifth,
        ]).values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(500 + 1)) }
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func mergeIncludingConcat() async {
        let clock = TestClock()

        let first = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.eraseToAnyEffect()
        let second = Effects.Single {
            try! await clock.sleep(for: .seconds(300))
            return Action.second
        }.eraseToAnyEffect()
        let third = Effects.Single {
            try! await clock.sleep(for: .seconds(200))
            return Action.third
        }.eraseToAnyEffect()
        let fourth = Effects.Single {
            try! await clock.sleep(for: .seconds(100))
            return Action.fourth
        }.eraseToAnyEffect()
        let fifth = Effects.Single {
            try! await clock.sleep(for: .seconds(600 + 100))
            return Action.fifth
        }.eraseToAnyEffect()

        let values = Effects.Merge([
            first,
            Effects.Concat([second, third, fourth]).eraseToAnyEffect(),
            fifth,
        ]).values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(700 + 1)) }
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func createSynchronously() async {
        let values = Effects.Create { continuation in
            continuation.yield(Action.first)
            continuation.yield(Action.second)
            continuation.yield(Action.third)
            continuation.yield(Action.fourth)
            continuation.yield(Action.fifth)
            continuation.finish()
        }.values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func createAsynchronously() async {
        let clock = TestClock()

        let values = Effects.Create { continuation in
            Task {
                try! await clock.sleep(for: .seconds(100))
                continuation.yield(Action.first)
                continuation.yield(Action.second)
            }
            Task {
                try! await clock.sleep(for: .seconds(200))
                continuation.yield(Action.third)
                continuation.yield(Action.fourth)
                continuation.yield(Action.fifth)
            }
            Task {
                try! await clock.sleep(for: .seconds(300))
                continuation.finish()
            }
        }.values

        var result: [Action] = []
        Task { await clock.advance(by: .seconds(300 + 1)) }
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)
    }

    @Test
    func createAsynchronouslyWithCompletionHandler() async {
        let values = Effects.Create { continuation in
            perform { action in
                continuation.yield(action)
                if action == .fifth {
                    continuation.finish()
                }
            }
        }.values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        let expectation: [Action] = [
            .first,
            .second,
            .third,
            .fourth,
            .fifth,
        ]
        #expect(result == expectation)

        func perform(completionHandler: @Sendable @escaping (Action) -> Void) {
            Task {
                completionHandler(.first)
                completionHandler(.second)
            }
            Task {
                try await Task.sleep(for: .milliseconds(100))
                completionHandler(.third)
                completionHandler(.fourth)
                completionHandler(.fifth)
            }
        }
    }
}
