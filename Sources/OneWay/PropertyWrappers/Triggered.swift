//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that treats a value as unequal, even if the same value is assigned.
///
/// When this property wrapper is applied to a field, assigning the same value will result in a
/// different internal state. This ensures that observers will perceive the state as changed, even
/// if the value itself remains the same. It is particularly useful in SwiftUI, as it can trigger a
/// `View` to re-render when needed, even if the value has not technically changed.
@propertyWrapper
public struct Triggered<Value> where Value: Equatable {
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

extension Triggered: CustomStringConvertible {
    public var description: String {
        String(describing: storage.value)
    }
}

extension Triggered: Sendable where Value: Sendable { }
extension Triggered: Equatable { }
extension Triggered: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(storage)
    }
}

extension Triggered.Storage: Sendable where Value: Sendable { }
extension Triggered.Storage: Hashable where Value: Hashable {
    fileprivate func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(version)
    }
}
