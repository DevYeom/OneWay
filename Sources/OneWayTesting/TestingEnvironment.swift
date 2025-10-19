//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Testing)
import Testing
#endif

enum TestingFramework {
    case xcTest
    case testing

    static var current: TestingFramework {
    #if canImport(Testing)
        if Test.current != nil {
            return .testing
        } else {
            return .xcTest
        }
    #else
        return .xcTest
    #endif
    }
}
