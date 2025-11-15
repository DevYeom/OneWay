//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that always evaluates as equal, regardless of the wrapped value.
///
/// When this property wrapper is applied to a field and compared for equality, it will always
/// return `true`. This prevents observers from detecting a state change, even if the underlying

/// value has been updated. It is particularly useful for avoiding unnecessary UI updates in
/// SwiftUI when a property should not trigger a re-render.
@propertyWrapper
public struct Ignored<Value> {
    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

extension Ignored: CustomStringConvertible {
    public var description: String {
        String(describing: wrappedValue)
    }
}

extension Ignored: Sendable where Value: Sendable { }
extension Ignored: Equatable {
    public static func == (lhs: Ignored, rhs: Ignored) -> Bool {
        true
    }
}
extension Ignored: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}
