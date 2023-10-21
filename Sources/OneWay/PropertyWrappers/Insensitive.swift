//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// When applied to a property of `State`, the comparable value will always remain the same, even if
/// the actual value changes.
///
/// It is useful when the actual value of the `State` changes, but rendering of the `View` is not
/// required.
@propertyWrapper
public struct Insensitive<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension Insensitive: CustomStringConvertible {
    public var description: String {
        String(describing: wrappedValue)
    }
}

extension Insensitive: Sendable where Value: Sendable { }
extension Insensitive: Equatable where Value: Equatable {
    public static func == (lhs: Insensitive, rhs: Insensitive) -> Bool {
        true
    }
}
extension Insensitive: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}
