//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

extension AsyncStream {
    public func eraseToAnyEffect() -> AnyEffect<Element> {
        return Effects.Stream(self).eraseToAnyEffect()
    }
}
