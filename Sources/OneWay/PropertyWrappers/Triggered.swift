//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that makes a value behave like a different one just by assigning it, even if
/// the same value is assigned.
///
/// When applied to a field, assigning the same value will lead to different values for comparison.
/// It is useful in cases where the value hasn't actually changed, but the `View` needs to be
/// rendered again.
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
