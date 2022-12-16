import Foundation
import Combine

/// The ``SideWay`` type encapsulates a unit of work that can be run in the outside world, and can
/// feed data back to the ``Way``. It is the perfect place to do side effects, such as network
/// requests, saving/loading from disk, creating timers, interacting with dependencies, and more.
///
/// SideWays are returned from reducers so that the ``Way`` can perform the sideWays after the
/// reducer is done running. If the way is initialized with `current` of thread option, It is
/// important to note that ``Way`` is not thread safe, and so all sideWays must receive values on
/// the same thread, and if the way is being used to drive UI then it must receive values on the
/// main thread.
public struct SideWay<Output, Failure: Error>: Publisher {

    public let upstream: AnyPublisher<Output, Failure>

    /// Initializes a sideWay that wraps a publisher. Each emission of the wrapped publisher will be
    /// emitted by the sideWay.
    public init<P: Publisher>(
        _ publisher: P
    ) where P.Output == Output, P.Failure == Failure {
        self.upstream = publisher.eraseToAnyPublisher()
    }

    public func receive<S>(
        subscriber: S
    ) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
        self.upstream.subscribe(subscriber)
    }

    /// Initializes a sideWay that immediately fails with the error passed in.
    ///
    /// - Parameter error: The error that is immediately emitted by the sideWay.
    public init(
        error: Failure
    ) {
        self.init(
            Deferred {
                Future { $0(.failure(error)) }
            }
        )
    }

    /// A sideWay that does nothing and completes immediately. Useful for situations where you must
    /// return a sideWay, but you don't need to do anything.
    public static var none: SideWay {
        Empty(completeImmediately: true)
            .eraseToSideWay()
    }

    /// Transforms all elements from the upstream sideWay with a provided closure.
    ///
    /// - Parameter transform: A closure that transforms the upstream sideWay's output to a new
    ///   output.
    /// - Returns: A publisher that uses the provided closure to map elements from the upstream
    ///   sideWay to new elements that it then publishes.
    public func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> SideWay<T, Failure> {
        .init(self.map(transform) as Publishers.Map<Self, T>)
    }

    /// A sideWay that immediately emits the value passed in.
    public static func just(
        _ value: Output
    ) -> Self {
        self.init(Just(value).setFailureType(to: Failure.self))
    }

    /// Concatenates a variadic list of sideWays together into a single sideWay, which runs the
    /// sideWays one after the other.
    ///
    /// - Parameter sideWays: A variadic list of sideWays.
    /// - Returns: A new sideWay
    public static func concat(
        _ sideWays: SideWay...
    ) -> Self {
        .concat(sideWays)
    }

    /// Concatenates a collection of sideWays together into a single sideWay, which runs the
    /// sideWays one after the other.
    ///
    /// - Parameter sideWays: A collection of sideWays.
    /// - Returns: A new sideWay
    public static func concat<C: Collection>(
        _ sideWays: C
    ) -> Self where C.Element == SideWay {
        guard let first = sideWays.first else { return .none }
        return sideWays
            .dropFirst()
            .reduce(into: first) { sideWays, sideWay in
                sideWays = sideWays
                    .append(sideWay)
                    .eraseToSideWay()
            }
    }

    /// Merges a variadic list of sideWays together into a single sideWay, which runs the sideWays
    /// at the same time.
    ///
    /// - Parameter sideWays: A list of sideWays.
    /// - Returns: A new sideWay
    public static func merge(
        _ sideWays: SideWay...
    ) -> Self {
        .merge(sideWays)
    }

    /// Merges a sequence of sideWays together into a single sideWay, which runs the sideWays at the
    /// same time.
    ///
    /// - Parameter sideWays: A sequence of sideWays.
    /// - Returns: A new sideWay
    public static func merge<S: Sequence>(
        _ sideWays: S
    ) -> Self where S.Element == SideWay {
        Publishers.MergeMany(sideWays)
            .eraseToSideWay()
    }

    /// Creates a sideWay that can supply a single value asynchronously in the future.
    ///
    /// - Parameter result: A closure that takes a `callback` as an argument which can be
    ///   used to feed it `Result<Output, Failure>` values.
    public static func future(
        _ result: @escaping (@escaping (Result<Output, Failure>) -> Void) -> Void
    ) -> Self {
        Deferred { Future(result) }
            .eraseToSideWay()
    }

#if canImport(_Concurrency)
    public static func async(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async -> Output
    ) -> Self where Failure == Never {
        var task: Task<Void, Never>?
        return .future { promise in
            task = Task(
                priority: priority,
                operation: { @MainActor in
                    guard !Task.isCancelled else { return }
                    let output = await operation()
                    guard !Task.isCancelled else { return }
                    promise(.success(output))
                }
            )
        }
        .handleEvents(receiveCancel: { task?.cancel() })
        .eraseToSideWay()
    }

    public static func async(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable () async throws -> Output
    ) -> Self where Failure == Error {
        Deferred<Publishers.HandleEvents<PassthroughSubject<Output, Failure>>> {
            let subject = PassthroughSubject<Output, Failure>()
            let task = Task(
                priority: priority,
                operation: { @MainActor in
                    do {
                        try Task.checkCancellation()
                        let output = try await operation()
                        try Task.checkCancellation()
                        subject.send(output)
                        subject.send(completion: .finished)
                    } catch is CancellationError {
                        subject.send(completion: .finished)
                    } catch {
                        subject.send(completion: .failure(error))
                    }
                }
            )
            return subject.handleEvents(receiveCancel: task.cancel)
        }
        .eraseToSideWay()
    }

    public static func asyncVoid(
        priority: TaskPriority? = nil,
        _ operation: @escaping @Sendable () async throws -> Void
    ) -> Self {
        SideWay<Void, Never>.async(
            priority: priority,
            operation: { try? await operation() }
        )
        .empty()
    }
#endif

}

extension Publisher {

    /// Turns any publisher into a ``SideWay``.
    public func eraseToSideWay() -> SideWay<Output, Failure> {
        SideWay(self)
    }

    /// Turns any publisher into a ``SideWay`` with trasfroming.
    public func eraseToSideWay<T>(
        _ transform: @escaping (Output) -> T
    ) -> SideWay<T, Failure> {
        self.map(transform)
            .eraseToSideWay()
    }

    /// Turns any publisher into a ``SideWay`` that cannot fail by wrapping its output and failure
    /// in a result.
    ///
    /// This can be useful when you are working with a failing API but want to deliver its data to
    /// an action that handles both success and failure.
    public func catchToSideWay() -> SideWay<Result<Output, Failure>, Never> {
        self.map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToSideWay()
    }

    /// Turns any publisher into a ``SideWay`` that cannot fail by trasforming its result into a
    /// output.
    public func catchToSideWay<T>(
        _ transform: @escaping (Result<Output, Failure>) -> T
    ) -> SideWay<T, Never> {
        self.map { transform(.success($0)) }
            .catch { Just(transform(.failure($0))) }
            .eraseToSideWay()
    }

    /// Turns any publisher into a ``SideWay`` that ignore its error.
    public func catchToNever() -> SideWay<Output, Never> {
        self.catch { _ in Empty(completeImmediately: true) }
            .eraseToSideWay()
    }

    /// Turns any publisher into a ``SideWay`` that return value instead of an error.
    public func catchToReturn(
        _ value: Output
    ) -> SideWay<Output, Never> {
        self.catch { _ in Just(value) }
            .eraseToSideWay()
    }

    public func empty<EmptyOutput, EmptyFailure>(
        outputType: EmptyOutput.Type = EmptyOutput.self,
        failureType: EmptyFailure.Type = EmptyFailure.self
    ) -> SideWay<EmptyOutput, EmptyFailure> {
        self.flatMap { _ in Empty<EmptyOutput, Failure>() }
            .catch { _ in Empty() }
            .eraseToSideWay()
    }

}
