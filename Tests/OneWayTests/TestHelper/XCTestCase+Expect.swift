//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2023 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import XCTest

extension XCTestCase {
    func expect(
        compare: () async -> Bool,
        timeout seconds: UInt64 = 1,
        description: String = #function
    ) async {
        let limit = NSEC_PER_SEC * seconds
        let start = DispatchTime.now().uptimeNanoseconds
        while true {
            guard start.distance(to: DispatchTime.now().uptimeNanoseconds) < limit else {
                XCTFail("Exceeded timeout of \(seconds) seconds")
                break
            }
            if await compare() {
                XCTAssert(true)
                break
            } else {
                await Task.yield()
            }
        }
    }
}
