//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import Foundation

extension AsyncSequence {
    public func gather(_ take: Int? = nil) async throws -> [Element] {
        var results: [Element] = []
        for try await element in self {
            results.append(element)
            
            if let take = take, results.count >= take {
               break
            }
        }
        return results
    }
}
