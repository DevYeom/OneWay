//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// An effect that performs type erasure by wrapping another effect.
public struct AnyEffect<Element>: Effect where Element: Sendable {
    public var values: AsyncStream<Element> { base.values }

    private var base: any Effect<Element>

    /// Creates a type-erasing effect to wrap the provided effect.
    ///
    /// - Parameter base: An effect to wrap with a type-eraser.
    public init<Base>(_ base: Base)
    where Base: Effect, Base.Element == Element {
        self.base = base
    }
}

extension AnyEffect {
    /// An effect that does nothing and finishes immediately. It is useful for situations where you
    /// must return a effect, but you don't need to do anything.
    @inlinable
    public static var none: AnyEffect<Element> {
        Effects.Empty().eraseToAnyEffect()
    }

    /// An effect that immediately emits the value passed in.
    ///
    /// - Parameter element: An element to emit immediately.
    /// - Returns: A new effect.
    @inlinable
    public static func just(
        _ element: Element
    ) -> AnyEffect<Element> {
        Effects.Just(element).eraseToAnyEffect()
    }

    /// An effect that can supply a single value asynchronously in the future.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - operation: The operation to perform.
    /// - Returns: A new effect.
    @inlinable
    public static func single(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping () async -> Element
    ) -> AnyEffect<Element> {
        Effects.Single(
            priority: priority,
            operation: operation
        ).eraseToAnyEffect()
    }

    /// An effect that can supply multiple values asynchronously in the future. It can be used for
    /// observing an asynchronous sequence.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - operation: The operation to perform.
    /// - Returns: A new effect.
    @inlinable
    public static func sequence(
        priority: TaskPriority? = nil,
        operation: @Sendable @escaping ((Element) -> Void) async -> Void
    ) -> AnyEffect<Element> {
        Effects.Sequence(
            priority: priority,
            operation: operation
        ).eraseToAnyEffect()
    }

    /// An effect that concatenates a list of effects together into a single effect, which runs the
    /// effects one after the other.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - effects: Variadic effects.
    /// - Returns: A new effect.
    @inlinable
    public static func concat(
        priority: TaskPriority? = nil,
        _ effects: AnyEffect<Element>...
    ) -> AnyEffect<Element> {
        Effects.Concat(
            priority: priority,
            effects
        ).eraseToAnyEffect()
    }

    /// An effect that merges a list of effects together into a single effect, which runs the
    /// effects at the same time.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - effects: Variadic effects.
    /// - Returns: A new effect.
    @inlinable
    public static func merge(
        priority: TaskPriority? = nil,
        _ effects: AnyEffect<Element>...
    ) -> AnyEffect<Element> {
        Effects.Merge(
            priority: priority,
            effects
        ).eraseToAnyEffect()
    }
}
