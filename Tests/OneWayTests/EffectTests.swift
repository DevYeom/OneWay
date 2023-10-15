//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Clocks
import OneWay
import XCTest

@available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
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

    func test_async() async {
        let clock = TestClock()

        let values = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.values

        var result: [Action] = []
        await clock.advance(by: .seconds(100))
        for await value in values {
            result.append(value)
        }

        XCTAssertEqual(result, [.first])
    }

    func test_concat() async {
        let clock = TestClock()

        let first = Effects.Just(Action.first).any
        let second = Effects.Async {
            try! await clock.sleep(for: .seconds(300))
            return Action.second
        }.any
        let third = Effects.Async {
            try! await clock.sleep(for: .seconds(200))
            return Action.third
        }.any
        let fourth = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.fourth
        }.any
        let fifth = Effects.Just(Action.fifth).any

        let values = Effects.Concat([
            first,
            second,
            third,
            fourth,
            fifth,
        ]).values

        var result: [Action] = []
        await clock.advance(by: .seconds(100 + 200 + 300))
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

        let first = Effects.Async {
            try! await clock.sleep(for: .seconds(500))
            return Action.first
        }.any
        let second = Effects.Async {
            try! await clock.sleep(for: .seconds(200))
            return Action.second
        }.any
        let third = Effects.Async {
            try! await clock.sleep(for: .seconds(300))
            return Action.third
        }.any
        let fourth = Effects.Async {
            try! await clock.sleep(for: .seconds(400))
            return Action.fourth
        }.any
        let fifth = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.fifth
        }.any

        let values = Effects.Concat([
            first,
            Effects.Merge([fourth, third, second]).any,
            fifth,
        ]).values

        var result: [Action] = []
        await clock.advance(by: .seconds(500 + 400 + 100))
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

        let first = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.any
        let second = Effects.Async {
            try! await clock.sleep(for: .seconds(200))
            return Action.second
        }.any
        let third = Effects.Async {
            try! await clock.sleep(for: .seconds(300))
            return Action.third
        }.any
        let fourth = Effects.Async {
            try! await clock.sleep(for: .seconds(400))
            return Action.fourth
        }.any
        let fifth = Effects.Async {
            try! await clock.sleep(for: .seconds(500))
            return Action.fifth
        }.any

        let values = Effects.Merge([
            first,
            second,
            third,
            fourth,
            fifth,
        ]).values

        var result: [Action] = []
        await clock.advance(by: .seconds(500))
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

        let first = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.first
        }.any
        let second = Effects.Async {
            try! await clock.sleep(for: .seconds(300))
            return Action.second
        }.any
        let third = Effects.Async {
            try! await clock.sleep(for: .seconds(200))
            return Action.third
        }.any
        let fourth = Effects.Async {
            try! await clock.sleep(for: .seconds(100))
            return Action.fourth
        }.any
        let fifth = Effects.Async {
            try! await clock.sleep(for: .seconds(600 + 100))
            return Action.fifth
        }.any

        let values = Effects.Merge([
            first,
            Effects.Concat([second, third, fourth]).any,
            fifth,
        ]).values

        var result: [Action] = []
        await clock.advance(by: .seconds(700))
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
}
