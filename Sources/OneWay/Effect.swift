//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

public protocol Effect<Element> {
    associatedtype Element: Sendable

    var completion: (() -> Void)? { get set }
    var values: AsyncStream<Element> { get }
}

extension Effect {
    public var any: AnyEffect<Element> {
        AnyEffect(self)
    }
}

/// A namespace for types that serve as effects.
public enum Effects {
    public struct Empty<Element: Sendable>: Effect {
        public var completion: (() -> Void)?

        public init() { }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in
                    completion?()
                }
                continuation.finish()
            }
        }
    }

    public struct Just<Element: Sendable>: Effect {
        public var completion: (() -> Void)?

        private let element: Element

        public init(_ element: Element) {
            self.element = element
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in
                    completion?()
                }

                continuation.yield(element)
                continuation.finish()
            }
        }
    }

    public struct Async<Element: Sendable>: Effect {
        public var completion: (() -> Void)?

        private let priority: TaskPriority?
        private let operation: () async -> Element

        public init(
            priority: TaskPriority? = nil,
            operation: @escaping () async -> Element
        ) {
            self.priority = priority
            self.operation = operation
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in
                    completion?()
                }

                Task(priority: priority) {
                    let result = await operation()
                    continuation.yield(result)
                    continuation.finish()
                }
            }
        }
    }

    public struct Concat<Element>: Effect where Element: Sendable {
        public var completion: (() -> Void)?

        private let priority: TaskPriority?
        private let effects: [AnyEffect<Element>]

        public init(
            priority: TaskPriority? = nil,
            _ effects: [AnyEffect<Element>]
        ) {
            self.priority = priority
            self.effects = effects
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in
                    completion?()
                }

                Task(priority: priority) {
                    for effect in effects {
                        for await value in effect.values {
                            continuation.yield(value)
                        }
                    }
                    continuation.finish()
                }
            }
        }
    }

    public struct Merge<Element>: Effect where Element: Sendable {
        public var completion: (() -> Void)?

        private let priority: TaskPriority?
        private let effects: [AnyEffect<Element>]

        public init(
            priority: TaskPriority? = nil,
            _ effects: [AnyEffect<Element>]
        ) {
            self.priority = priority
            self.effects = effects
        }

        public var values: AsyncStream<Element> {
            AsyncStream { continuation in
                continuation.onTermination = { _ in
                    completion?()
                }

                Task(priority: priority) {
                    if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
                        await withDiscardingTaskGroup { group in
                            for effect in effects {
                                group.addTask {
                                    for await value in effect.values {
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
                                        continuation.yield(value)
                                    }
                                }
                            }
                        }
                        continuation.finish()
                    }
                }
            }
        }
    }
}
