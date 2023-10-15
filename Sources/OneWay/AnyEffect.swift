//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

public struct AnyEffect<Element>: Effect where Element: Sendable {
    public var completion: (() -> Void)? {
        get {
            base.completion
        }
        set {
            base.completion = newValue
        }
    }
    private var base: any Effect<Element>

    public init<Base>(_ base: Base)
    where Base: Effect, Base.Element == Element {
        self.base = base
    }

    public var values: AsyncStream<Element> {
        base.values
    }
}

extension AnyEffect {
    @inlinable
    public static var none: AnyEffect<Element> {
        Effects.Empty().any
    }

    @inlinable
    public static func just(
        _ element: Element
    ) -> AnyEffect<Element> {
        Effects.Just(element).any
    }

    @inlinable
    public static func async(
        priority: TaskPriority? = nil,
        operation: @escaping () async -> Element
    ) -> AnyEffect<Element> {
        Effects.Async(
            priority: priority,
            operation: operation
        ).any
    }

    @inlinable
    public static func concat(
        priority: TaskPriority? = nil,
        _ effects: AnyEffect<Element>...
    ) -> AnyEffect<Element> {
        Effects.Concat(
            priority: priority,
            effects
        ).any
    }

    @inlinable
    public static func merge(
        priority: TaskPriority? = nil,
        _ effects: AnyEffect<Element>...
    ) -> AnyEffect<Element> {
        Effects.Merge(
            priority: priority,
            effects
        ).any
    }
}
