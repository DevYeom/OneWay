//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

/// A property wrapper that allows for an easy way to implement storing data in heap memory.
///
/// When applied to a field, the corresponding value will always be heap-allocated. This happens
/// because this wrapper is a class and classes are always heap-allocated. Use of this wrapper is
/// required on large value types because they can overflow the Swift runtime stack.
///
/// - SeeAlso: [`CopyOnWrite.swift` located in `square/wire` repository](https://github.com/square/wire/blob/master/wire-runtime-swift/src/main/swift/propertyWrappers/CopyOnWrite.swift)
@propertyWrapper
public struct Heap<Value> {
    fileprivate final class Storage {
        var value: Value

        init(_ value: Value) {
            self.value = value
        }
    }

    public var wrappedValue: Value {
        get {
            storage.value
        }

        set {
            if isKnownUniquelyReferenced(&storage) {
                storage.value = newValue
            } else {
                storage = Storage(newValue)
            }
        }
    }

    private var storage: Storage

    public init(wrappedValue: Value) {
        storage = Storage(wrappedValue)
    }
}

extension Heap: CustomStringConvertible {
    public var description: String {
        String(describing: storage.value)
    }
}

extension Heap: Sendable where Value: Sendable { }
extension Heap: Equatable where Value: Equatable {
    public static func == (lhs: Heap, rhs: Heap) -> Bool {
        lhs.wrappedValue == rhs.wrappedValue
    }
}
extension Heap: Hashable where Value : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedValue)
    }
}

extension Heap.Storage: @unchecked Sendable where Value: Sendable { }
