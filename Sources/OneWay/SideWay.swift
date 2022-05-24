import Foundation
import Combine

public struct SideWay<Output, Failure: Error>: Publisher {
    public let upstream: AnyPublisher<Output, Failure>

    public init<P: Publisher>(_ publisher: P)
    where P.Output == Output, P.Failure == Failure {
        self.upstream = publisher.eraseToAnyPublisher()
    }

    public init(error: Failure) {
        self.init(
            Deferred {
                Future { $0(.failure(error)) }
            }
        )
    }

    public func receive<S>(subscriber: S)
    where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
        self.upstream.subscribe(subscriber)
    }

    public func map<T>(_ transform: @escaping (Output) -> T) -> SideWay<T, Failure> {
        .init(self.map(transform) as Publishers.Map<Self, T>)
    }

    public static func just(_ value: Output) -> SideWay {
        self.init(Just(value).setFailureType(to: Failure.self))
    }

    public static var none: SideWay {
        Empty(completeImmediately: true).eraseToSideWay()
    }

    public static func concat(_ sideWays: SideWay...) -> SideWay {
        .concat(sideWays)
    }

    public static func concat<C: Collection>(_ sideWays: C) -> SideWay where C.Element == SideWay {
        guard let first = sideWays.first else { return .none }
        return sideWays
            .dropFirst()
            .reduce(into: first) { sideWays, sideWay in
                sideWays = sideWays.append(sideWay).eraseToSideWay()
            }
    }

    public static func merge(_ sideWays: SideWay...) -> SideWay {
        .merge(sideWays)
    }

    public static func merge<S: Sequence>(_ sideWays: S) -> SideWay where S.Element == SideWay {
        Publishers.MergeMany(sideWays).eraseToSideWay()
    }

    public static func future(_ result: @escaping (@escaping (Result<Output, Failure>) -> Void) -> Void) -> SideWay {
      Deferred { Future(result) }.eraseToSideWay()
    }
}

extension Publisher {
    public func eraseToSideWay() -> SideWay<Output, Failure> {
        SideWay(self)
    }

    public func eraseToSideWay<T>(_ transform: @escaping (Output) -> T) -> SideWay<T, Failure> {
        self.map(transform)
            .eraseToSideWay()
    }

    public func catchToSideWay() -> SideWay<Result<Output, Failure>, Never> {
        self.map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToSideWay()
    }

    public func catchToSideWay<T>(_ transform: @escaping (Result<Output, Failure>) -> T) -> SideWay<T, Never> {
        self.map { transform(.success($0)) }
            .catch { Just(transform(.failure($0))) }
            .eraseToSideWay()
    }

    public func catchToNever() -> SideWay<Output, Never> {
        self.catch { _ in Empty(completeImmediately: true) }
            .eraseToSideWay()
    }

    public func catchToReturn(_ value: Output) -> SideWay<Output, Never> {
        self.catch { _ in Just(value) }
            .eraseToSideWay()
    }
}
