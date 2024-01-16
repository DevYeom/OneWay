//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// An effect that performs type erasure by wrapping another effect.
public struct AnyEffect<Element>: Effect where Element: Sendable {
    /// A convenience type alias for representing a hashable identifier.
    public typealias EffectID = Hashable & Sendable

    /// Enumeration of methods representing additional functionality for AnyEffect.
    public enum Method: Sendable {
        case register(any EffectID, cancelInFlight: Bool)
        case cancel(any EffectID)
        case none
    }

    /// A method of the AnyEffect
    public var method: Method = .none

    public var values: AsyncStream<Element> { base.values }

    private var base: any Effect<Element>

    /// Creates a type-erasing effect to wrap the provided effect.
    ///
    /// - Parameter base: An effect to wrap with a type-eraser.
    public init<Base>(_ base: Base)
    where Base: Effect, Base.Element == Element {
        self.base = base
    }

    /// Assigning an identifier to make it possible to cancel the effect.
    ///
    /// - Parameter id: The effect's identifier.
    /// - Returns: A new effect that can be canceled by an identifier.
    public consuming func cancellable(
        _ id: some EffectID
    ) -> AnyEffect {
        var copy = self
        copy.method = .register(id, cancelInFlight: false)
        return copy
    }

    /// Sends elements only after a specified time interval elapses between events.
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - seconds: The duration for which the effect should wait before sending an element.
    /// - Returns: A new effect that sends elements only after a specified time elapses.
    public consuming func debounce(
        id: some EffectID,
        for seconds: Double
    ) -> Self {
        var copy = self
        copy.method = .register(id, cancelInFlight: true)
        let values = copy.values
        copy.base = Effects.Sequence(
            operation: { send in
                guard !Task.isCancelled else { return }
                let NSEC_PER_SEC: Double = 1_000_000_000
                let dueTime = NSEC_PER_SEC * seconds
                try? await Task.sleep(nanoseconds: UInt64(dueTime))
                for await value in values {
                    guard !Task.isCancelled else { return }
                    send(value)
                }
            }
        )
        return copy
    }

    /// Sends elements only after a specified time interval elapses between events.
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - dueTime: The duration for which the effect should wait before sending an element.
    ///   - clock: The clock used for measuring time intervals.
    /// - Returns: A new effect that sends elements only after a specified time elapses.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public consuming func debounce<C: Clock>(
        id: some EffectID,
        for dueTime: C.Instant.Duration,
        clock: C = ContinuousClock()
    ) -> Self {
        var copy = self
        copy.method = .register(id, cancelInFlight: true)
        let values = copy.values
        copy.base = Effects.Sequence(
            operation: { send in
                guard !Task.isCancelled else { return }
                try? await clock.sleep(for: dueTime)
                for await value in values {
                    guard !Task.isCancelled else { return }
                    send(value)
                }
            }
        )
        return copy
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

    /// An effect that allows canceling by using an identifier.
    ///
    /// - Parameter id: The identifier of the effect to be canceled.
    /// - Returns: A new effect.
    @inlinable
    public static func cancel(
        _ id: some EffectID
    ) -> AnyEffect {
        var copy = AnyEffect.none
        copy.method = .cancel(id)
        return copy
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
        operation: @Sendable @escaping (@escaping (Element) -> Void) async -> Void
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
    
    /// An effect that concatenates a list of effects together into a single effect, which runs the
    /// effects one after the other.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - build: A builder that makes effects.
    /// - Returns: A new effect.
    @inlinable
    public static func concat(
        priority: TaskPriority? = nil,
        @EffectsBuilder<Element> _ build: () -> [AnyEffect<Element>]
    ) -> AnyEffect<Element> {
        Effects.Concat(
            priority: priority,
            build()
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
    
    /// An effect that merges a list of effects together into a single effect, which runs the
    /// effects at the same time.
    ///
    /// - Parameters:
    ///   - priority: The priority of the task.
    ///     Pass `nil` to use the priority from `Task.currentPriority`.
    ///   - build: A builder that makes effects.
    /// - Returns: A new effect.
    @inlinable
    public static func merge(
        priority: TaskPriority? = nil,
        @EffectsBuilder<Element> _ build: () -> [AnyEffect<Element>]
    ) -> AnyEffect<Element> {
        Effects.Merge(
            priority: priority,
            build()
        ).eraseToAnyEffect()
    }

    /// An effect that creates an asynchronous stream.
    ///
    /// - Parameters:
    ///   - bufferingPolicy: A `Continuation.BufferingPolicy` value to set the stream's buffering
    ///   behavior. By default, the stream buffers an unlimited number of elements. You can also set
    ///   the policy to buffer a specified number of oldest or newest elements.
    ///   - build: A custom closure that yields values to the `AsyncStream`. This closure receives
    ///   an `AsyncStream.Continuation` instance that it uses to provide elements to the stream and
    ///   terminate the stream when finished.
    /// - Returns: A new effect.
    @inlinable
    public static func create(
        bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded,
        build: @escaping (AsyncStream<Element>.Continuation) -> Void
    ) -> AnyEffect<Element> {
        Effects.Create(
            bufferingPolicy: bufferingPolicy,
            build: build
        ).eraseToAnyEffect()
    }
}
