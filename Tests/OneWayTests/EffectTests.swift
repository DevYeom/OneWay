//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Clocks
import OneWay
import XCTest

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
final class EffectTests: XCTestCase {
    enum Action: Sendable {
        case first
        case second
        case third
        case fourth
        case fifth
    }

    func test_just() async {
        let values = Effects.Just(Action.first).values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        XCTAssertEqual(result, [.first])
    }

    func test_cancel() async {
        let cancel = AnyEffect<Action>.cancel("100")
        let method = cancel.method

        if case .cancel(let id) = method {
            XCTAssertEqual(id as! String, "100")
        } else {
            XCTFail()
        }
    }

    func test_cancellable() async {
        let effect = Effects.Just("").eraseToAnyEffect().cancellable("100")
        let method = effect.method

        if case let .register(id, _) = method {
            XCTAssertEqual(id as! String, "100")
        } else {
            XCTFail()
        }
    }

    func test_single() async {
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

        XCTAssertEqual(result, [.first])
    }

    func test_sequence() async {
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
                    XCTFail()
                }
                send(action)
            }
        }.values

        var result: [Action] = []
        for await value in values {
            result.append(value)
        }

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_concat() async {
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


        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_concatIncludingMerge() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_merge() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_mergeIncludingConcat() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_createSynchronously() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_createAsynchronously() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )
    }

    func test_createAsynchronouslyWithCompletionHandler() async {
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

        XCTAssertEqual(
            result,
            [
                .first,
                .second,
                .third,
                .fourth,
                .fifth,
            ]
        )

        func perform(completionHandler: @Sendable @escaping (Action) -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                completionHandler(.first)
                completionHandler(.second)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completionHandler(.third)
                completionHandler(.fourth)
                completionHandler(.fifth)
            }
        }
    }
}
