//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that facilitates the use of copy-on-write semantics to eliminate the cost of
/// copying large values.
///
/// When applied to a field, the corresponding value will always be heap-allocated because this
/// wrapper uses a class, and classes in Swift are always allocated on the heap. This is especially
/// useful for large value types, as it prevents stack overflow by ensuring the value is managed on
/// the heap instead of the stack. Additionally, the copy-on-write behavior helps avoid unnecessary
/// copying when the value is not modified, improving performance.
///
/// - SeeAlso: [Advice: Use copy-on-write semantics for large values](https://github.com/swiftlang/swift/blob/swift-6.0-RELEASE/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values)
@propertyWrapper
public struct CopyOnWrite<Value> {
    fileprivate final class Reference {
        var value: Value

        init(_ value: Value) {
            self.value = value
        }
    }

    public var wrappedValue: Value {
        get {
            reference.value
        }
        set {
            if isKnownUniquelyReferenced(&reference) {
                reference.value = newValue
            } else {
                reference = Reference(newValue)
            }
        }
    }

    private var reference: Reference

    public init(wrappedValue: Value) {
        reference = Reference(wrappedValue)
    }
}

extension CopyOnWrite: CustomStringConvertible {
    public var description: String {
        String(describing: reference.value)
    }
}

extension CopyOnWrite: Sendable where Value: Sendable { }
extension CopyOnWrite: Equatable where Value: Equatable {
    public static func == (lhs: CopyOnWrite, rhs: CopyOnWrite) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}
extension CopyOnWrite: Hashable where Value : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension CopyOnWrite.Reference: @unchecked Sendable where Value: Sendable { }
