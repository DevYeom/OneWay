//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that acts like the same value, regardless of changes in its actual value.
///
/// When applied to a field and compared with an equals sign, it will always yield `true`. This
/// prevents the observers from recognizing the state as changed, even if the actual value has been
/// updated. It is particularly useful when you want to avoid triggering state changes, especially
/// in SwiftUI, where unnecessary re-renders of the `View` can be avoided.
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
