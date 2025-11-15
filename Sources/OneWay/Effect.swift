//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

/// A protocol that encapsulates a unit of work that can be executed in an external environment and
/// can provide data to a ``Store``.
///
/// This is the perfect place to handle side effects, such as network requests, saving or loading
/// from disk, creating timers, and interacting with dependencies. Effects are returned from
/// reducers, allowing the ``Store`` to execute them after the reducer has finished its operation.
public protocol Effect<Element>: Sendable {
    associatedtype Element: Sendable

    /// The elements produced by the effect, delivered as an asynchronous sequence.
    var values: AsyncStream<Element> { get }
}

extension Effect {
    /// Wraps this effect with a type eraser.
    ///
    /// - Returns: An `AnyEffect` wrapping this effect.
    public func eraseToAnyEffect() -> AnyEffect<Element> {
        AnyEffect(self)
    }
}

/// A namespace for types that serve as effects.
public enum Effects {
    /// An effect that does nothing and finishes immediately.
    ///
    /// This is useful for situations where you must return an effect, but you do not need to
    /// perform any operations.
    public struct Empty<Element>: Effect where Element: Sendable {
        /// Initializes an `Empty` effect.
        public init() { }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    /// An effect that immediately emits the value passed in.
    public struct Just<Element>: Effect where Element: Sendable {
        private let element: Element

        /// Initializes a `Just` effect.
        ///
        /// - Parameter element: An element to be emitted immediately.
        public init(_ element: Element) {
            self.element = element
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.yield(element)
                continuation.finish()
            }
        }
    }

    /// An effect that can supply a single value asynchronously in the future.
    public struct Single<Element>: Effect where Element: Sendable {
        private let priority: TaskPriority?
        private let operation: @Sendable () async -> Element

        /// Initializes a `Single` effect.
        ///
        /// - Parameters:
        ///   - priority: The priority of the task.
        ///     Pass `nil` to use the priority from `Task.currentPriority`.
        ///   - operation: The operation to be performed.
        public init(
            priority: TaskPriority? = nil,
            operation: @Sendable @escaping () async -> Element
        ) {
            self.priority = priority
            self.operation = operation
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                let task = Task(priority: priority) {
                    let result = await operation()
                    continuation.yield(result)
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    /// An effect that can supply multiple values asynchronously in the future.
    ///
    /// This can be used for observing an asynchronous sequence.
    public struct Sequence<Element>: Effect where Element: Sendable {
        private let priority: TaskPriority?
        private let operation: @Sendable (@escaping (Element) -> Void) async -> Void

        /// Initializes a `Sequence` effect.
        ///
        /// - Parameters:
        ///   - priority: The priority of the task.
        ///     Pass `nil` to use the priority from `Task.currentPriority`.
        ///   - operation: The operation to be performed.
        public init(
            priority: TaskPriority? = nil,
            operation: @Sendable @escaping (@escaping (Element) -> Void) async -> Void
        ) {
            self.priority = priority
            self.operation = operation
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                let task = Task(priority: priority) {
                    await operation { continuation.yield($0) }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    /// An effect that concatenates a list of effects into a single effect, which runs the
    /// effects one after the other.
    public struct Concat<Element>: Effect where Element: Sendable {
        private let priority: TaskPriority?
        private let effects: [AnyEffect<Element>]

        /// Initializes a `Concat` effect.
        ///
        /// - Parameters:
        ///   - priority: The priority of the task.
        ///     Pass `nil` to use the priority from `Task.currentPriority`.
        ///   - effects: A list of effects.
        public init(
            priority: TaskPriority? = nil,
            _ effects: [AnyEffect<Element>]
        ) {
            self.priority = priority
            self.effects = effects
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                let task = Task(priority: priority) {
                    for effect in effects {
                        for await value in effect.values {
                            guard !Task.isCancelled else { break }
                            continuation.yield(value)
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    /// An effect that merges a list of effects into a single effect, which runs the effects
    /// at the same time.
    public struct Merge<Element>: Effect where Element: Sendable {
        private let priority: TaskPriority?
        private let effects: [AnyEffect<Element>]

        /// Initializes a `Merge` effect.
        ///
        /// - Parameters:
        ///   - priority: The priority of the task.
        ///     Pass `nil` to use the priority from `Task.currentPriority`.
        ///   - effects: A list of effects.
        public init(
            priority: TaskPriority? = nil,
            _ effects: [AnyEffect<Element>]
        ) {
            self.priority = priority
            self.effects = effects
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                let task = Task(priority: priority) {
                    if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
                        await withDiscardingTaskGroup { group in
                            for effect in effects {
                                group.addTask {
                                    for await value in effect.values {
                                        guard !Task.isCancelled else { break }
                                        continuation.yield(value)
                                    }
                                }
                            }
                        }
                        continuation.finish()
                    } else {
                        await withTaskGroup(of: Void.self) { group in
                            for effect in effects {
                                group.addTask {
                                    for await value in effect.values {
                                        guard !Task.isCancelled else { break }
                                        continuation.yield(value)
                                    }
                                }
                            }
                        }
                        continuation.finish()
                    }
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }

    /// An effect that creates an asynchronous stream.
    public struct Create<Element>: Effect where Element: Sendable {
        private let stream: AsyncStream<Element>

        /// Initializes a `Create` effect.
        ///
        /// - Parameters:
        ///   - bufferingPolicy: A `Continuation.BufferingPolicy` value to set the stream's
        ///     buffering behavior. By default, the stream buffers an unlimited number of elements.
        ///     You can also set the policy to buffer a specified number of the oldest or newest
        ///     elements.
        ///   - build: A custom closure that yields values to the `AsyncStream`. This closure
        ///     receives an `AsyncStream.Continuation` instance that it uses to provide elements to
        ///     the stream and to terminate the stream when it is finished.
        public init(
            bufferingPolicy: AsyncStream<Element>.Continuation.BufferingPolicy = .unbounded,
            build: @escaping (AsyncStream<Element>.Continuation) -> Void
        ) {
            self.stream = AsyncStream<Element>(bufferingPolicy: bufferingPolicy, build)
        }

        public var values: AsyncStream<Element> {
            stream
        }
    }
}
