//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

final class EffectsBuilderTests: XCTestCase {
    func test_array() async {
        do {
            let effect = AnyEffect<Int>.concat {
                let effects = [
                    AnyEffect.just(1),
                    AnyEffect.just(2),
                    AnyEffect.just(3),
                ]
                for effect in effects {
                    effect
                }
            }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [1, 2, 3])
        }

        do {
            let effect = AnyEffect<Int>.merge {
                let effects = [
                    AnyEffect.just(1),
                    AnyEffect.just(2),
                    AnyEffect.just(3),
                ]
                for effect in effects {
                    effect
                }
            }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [1, 2, 3])
        }
    }

    func test_emptyBlock() async {
        do {
            let effect = AnyEffect<Int>.concat { }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [])
        }

        do {
            let effect = AnyEffect<Int>.merge { }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [])
        }
    }

    func test_block() async {
        do {
            let effect = AnyEffect<Int>.concat {
                AnyEffect.just(1)
                AnyEffect.just(2)
                AnyEffect.just(3)
            }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [1, 2, 3])
        }

        do {
            let effect = AnyEffect<Int>.merge {
                AnyEffect.just(1)
                AnyEffect.just(2)
                AnyEffect.just(3)
            }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [1, 2, 3])
        }
    }

    func test_conditionalBlock() async {
        enum Order {
            case first
            case second
        }
        let trueCondition = true
        let falseCondition = false
        let order = Order.second

        do {
            let effect = AnyEffect<Int>.concat {
                AnyEffect.just(1)

                if trueCondition {
                    AnyEffect.just(2)
                }
                if falseCondition {
                    AnyEffect.just(3)
                } else {
                    AnyEffect.just(4)
                }

                switch order {
                case .first:
                    AnyEffect.just(5)
                case .second:
                    AnyEffect.just(6)
                }
            }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [1, 2, 4, 6])
        }

        do {
            let effect = AnyEffect<Int>.merge {
                AnyEffect.just(1)

                if trueCondition {
                    AnyEffect.just(2)
                }
                if falseCondition {
                    AnyEffect.just(3)
                } else {
                    AnyEffect.just(4)
                }

                switch order {
                case .first:
                    AnyEffect.just(5)
                case .second:
                    AnyEffect.just(6)
                }
            }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [1, 2, 4, 6])
        }
    }

    func test_optionalBlock() async {
        let someValue: AnyEffect<Int>? = .just(1)
        let someValue2: AnyEffect<Int>? = .just(2)
        let noneValue: AnyEffect<Int>? = nil

        do {
            let effect = AnyEffect<Int>.concat {
                if let someValue {
                    someValue
                }
                if case let .some(value) = someValue2 {
                    value
                }
                if let noneValue {
                    noneValue
                }
            }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [1, 2])
        }

        do {
            let effect = AnyEffect<Int>.merge {
                if let someValue {
                    someValue
                }
                if case let .some(value) = someValue2 {
                    value
                }
                if let noneValue {
                    noneValue
                }
            }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [1, 2])
        }
    }

    func test_limitedAvailabilityBlock() async {
        do {
            let effect = AnyEffect<Int>.concat {
                AnyEffect.just(1)
                if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
                    AnyEffect.just(2)
                } else {
                    AnyEffect.just(3)
                }
            }

            var result: [Int] = []
            for await value in effect.values {
                result.append(value)
            }

            XCTAssertEqual(result, [1, 2])
        }

        do {
            let effect = AnyEffect<Int>.merge {
                AnyEffect.just(1)
                if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
                    AnyEffect.just(2)
                } else {
                    AnyEffect.just(3)
                }
            }

            var result: Set<Int> = []
            for await value in effect.values {
                result.insert(value)
            }

            XCTAssertEqual(result, [1, 2])
        }
    }
}
