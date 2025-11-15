//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Testing
import OneWay

struct PropertyWrappersTests {
    @Test
    func copyOnWrite() {
        struct Storage {
            @CopyOnWrite var value: Int
            @CopyOnWrite var optionalValue: Int?
        }

        do {
            var storage = Storage(value: 10, optionalValue: 10)
            #expect(storage.value == 10)
            #expect(storage.optionalValue == 10)

            storage.value = 20
            storage.optionalValue = nil
            #expect(storage.value == 20)
            #expect(storage.optionalValue == nil)

            storage.value = 30
            storage.optionalValue = 20
            #expect(storage.value == 30)
            #expect(storage.optionalValue == 20)
        }

        do {
            var storage = Storage(value: 10, optionalValue: nil)
            #expect(storage.value == 10)
            #expect(storage.optionalValue == nil)

            storage.value = 20
            storage.optionalValue = 10
            #expect(storage.value == 20)
            #expect(storage.optionalValue == 10)

            storage.value = 30
            storage.optionalValue = nil
            #expect(storage.value == 30)
            #expect(storage.optionalValue == nil)
        }
    }

    @Test
    func triggered() {
        struct Storage: Equatable {
            @Triggered var value: Int
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 20

            #expect(old != new)
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 10

            #expect(old != new)
        }

        do {
            var old = Storage(value: 10)
            var new = old
            old.value = 20
            new.value = 20

            #expect(old == new)
        }
    }

    @Test
    func ignored() {
        struct Storage: Equatable {
            @Ignored var value: Int
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 20

            #expect(old == new)
        }

        do {
            let old = Storage(value: 10)
            var new = old
            new.value = 10

            #expect(old == new)
        }

        do {
            var old = Storage(value: 10)
            var new = old
            old.value = 20
            new.value = 20

            #expect(old == new)
        }
    }
}
