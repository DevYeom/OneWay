//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

@propertyWrapper
public struct Sensitive<Value> where Value: Equatable {
    fileprivate struct Storage: Equatable {
        var value: Value
        var version: UInt8

        init(_ value: Value) {
            self.value = value
            self.version = .min
        }

        mutating func set(_ value: Value) {
            if self.value == value {
                self.version &+= 1
            } else {
                self.value = value
                self.version = .min
            }
        }
    }

    public var wrappedValue: Value {
        get { storage.value }
        set { storage.set(newValue) }
    }

    private var storage: Storage

    public init(wrappedValue: Value) {
        storage = Storage(wrappedValue)
    }
}

extension Sensitive: Sendable where Value: Sendable { }
extension Sensitive: Equatable { }
extension Sensitive: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}

extension Sensitive.Storage: Sendable where Value: Sendable { }
extension Sensitive.Storage: Hashable where Value: Hashable {
    fileprivate func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(version)
    }
}
