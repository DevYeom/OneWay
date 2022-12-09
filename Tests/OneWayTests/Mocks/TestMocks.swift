import Foundation
import Combine

struct WayError: Error { }
let globalTextSubject = PassthroughSubject<String, Never>()
let globalNumberSubject = PassthroughSubject<Int, Never>()
