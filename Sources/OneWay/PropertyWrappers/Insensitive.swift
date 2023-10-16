//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

@propertyWrapper
public struct Insensitive<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
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
