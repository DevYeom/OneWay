//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

@resultBuilder
public enum EffectsBuilder<T: Sendable> {
    public static func buildArray(_ components: [[AnyEffect<T>]]) -> [AnyEffect<T>] {
        components.flatMap { $0 }
    }

    public static func buildBlock() -> [AnyEffect<T>] {
        []
    }

    public static func buildBlock(_ effects: AnyEffect<T>...) -> [AnyEffect<T>] {
        effects
    }

    public static func buildBlock(_ components: [AnyEffect<T>]...) -> [AnyEffect<T>] {
        components.flatMap { $0 }
    }

    public static func buildEither(first component: [AnyEffect<T>]) -> [AnyEffect<T>] {
        component
    }

    public static func buildEither(second component: [AnyEffect<T>]) -> [AnyEffect<T>] {
        component
    }

    public static func buildExpression(_ expression: AnyEffect<T>) -> [AnyEffect<T>] {
        [expression]
    }

    public static func buildFinalResult(_ component: [AnyEffect<T>]) -> [AnyEffect<T>] {
        component
    }

    public static func buildLimitedAvailability(_ component: [AnyEffect<T>]) -> [AnyEffect<T>] {
        component
    }

    public static func buildOptional(_ component: [AnyEffect<T>]?) -> [AnyEffect<T>] {
        guard let component = component else { return [] }
        return component
    }
}
