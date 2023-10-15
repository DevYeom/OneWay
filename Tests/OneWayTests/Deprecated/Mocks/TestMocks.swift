// The MIT License (MIT)
//
// Copyright (c) 2022 SeungYeop Yeom ( https://github.com/DevYeom ).

import Foundation
import Combine

struct WayError: Error { }
let globalTextSubject = PassthroughSubject<String, Never>()
let globalNumberSubject = PassthroughSubject<Int, Never>()
