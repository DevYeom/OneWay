//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

extension AsyncStream {
    public func eraseToAnyEffect() async throws -> AnyEffect<Element> {
        let actions = try await self.gather().map(AnyEffect.just(_:))
        return Effects.Merge(actions).eraseToAnyEffect()
    }
}
