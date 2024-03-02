//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay
import XCTest

final class PropertyWrappersTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func test_heap() {
        struct Storage {
            @Heap var value: Int
            @Heap var optionalValue: Int?
        }

        do {
            var storage = Storage(value: 10, optionalValue: 10)
            XCTAssertEqual(storage.value, 10)
            XCTAssertEqual(storage.optionalValue, 10)

            storage.value = 20
            storage.optionalValue = nil
            XCTAssertEqual(storage.value, 20)
            XCTAssertEqual(storage.optionalValue, nil)

            storage.value = 30
            storage.optionalValue = 20
            XCTAssertEqual(storage.value, 30)
            XCTAssertEqual(storage.optionalValue, 20)
        }

        do {
            var storage = Storage(value: 10, optionalValue: nil)
            XCTAssertEqual(storage.value, 10)
            XCTAssertEqual(storage.optionalValue, nil)

            storage.value = 20
            storage.optionalValue = 10
            XCTAssertEqual(storage.value, 20)
            XCTAssertEqual(storage.optionalValue, 10)

            storage.value = 30
            storage.optionalValue = nil
            XCTAssertEqual(storage.value, 30)
            XCTAssertEqual(storage.optionalValue, nil)
        }
    }

    func test_sensitive() {
        struct Storage: Equatable {
            @Sensitive var value: Int
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 20

            XCTAssertNotEqual(old, new)
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 10

            XCTAssertNotEqual(old, new)
        }

        do {
            var old = Storage(value: 10)
            var new = old
            old.value = 20
            new.value = 20

            XCTAssertEqual(old, new)
        }
    }

    func test_insensitive() {
        struct Storage: Equatable {
            @Insensitive var value: Int
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 20

            XCTAssertEqual(old, new)
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 10

            XCTAssertEqual(old, new)
        }

        do {
            var old = Storage(value: 10)
            var new = old
            old.value = 20
            new.value = 20

            XCTAssertEqual(old, new)
        }
    }
}
