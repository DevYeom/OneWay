//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

@resultBuilder
public struct EffectsBuilder {    
    public static func buildBlock<T: Sendable>(_ effects: AnyEffect<T>...) -> [AnyEffect<T>] {
        return effects
    }
}
