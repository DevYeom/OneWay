//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2024 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A property wrapper that allows for an easy way to eliminate the cost of copying large values
/// adopt copy-on-write behavior.
///
/// When applied to a field, the corresponding value will always be heap-allocated. This happens
/// because this wrapper is a class and classes are always heap-allocated. Use of this wrapper is
/// required on large value types because they can overflow the Swift runtime stack.
///
/// - SeeAlso: [Advice: Use copy-on-write semantics for large values](https://github.com/apple/swift/blob/main/docs/OptimizationTips.rst#advice-use-copy-on-write-semantics-for-large-values)
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
