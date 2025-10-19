//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

#if canImport(Combine)
@preconcurrency import Combine

extension Publisher where Failure == Never, Output: Sendable {
    public var stream: AsyncStream<Output> {
        AsyncStream { continuation in
            let cancellable = self.sink { completion in
                continuation.finish()
            } receiveValue: { value in
                 continuation.yield(value)
            }
            continuation.onTermination = { continuation in
                cancellable.cancel()
            }
        }
    }
}
#endif
