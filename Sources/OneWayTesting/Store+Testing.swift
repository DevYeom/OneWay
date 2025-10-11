//
//  OneWay
//  The MIT License (MIT)
//
//  Copyright (c) 2022-2025 SeungYeop Yeom ( https://github.com/DevYeom ).
//

import OneWay

#if canImport(CoreFoundation)
import CoreFoundation
#endif

#if canImport(Testing)
import Testing
#endif

#if canImport(XCTest)
import XCTest
#endif

#if canImport(Testing)
extension Store {
    #if swift(>=6.0)
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - fileID: The file ID from which the function is called.
    ///   - filePath: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    ///   - column: The column number from which the function is called.
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: Double = 2,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async where Property: Sendable & Equatable {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        switch TestingFramework.current {
        case .xcTest:
            #if canImport(XCTest)
            if isTimeout && result != input {
                XCTFail(
                    "Timeout exceeded \(timeout) seconds: received \(input), expected \(result)",
                    file: filePath,
                    line: line
                )
            } else {
                XCTAssertEqual(
                    result,
                    input,
                    file: filePath,
                    line: line
                )
            }
            #else
            break
            #endif
        case .testing:
            if isTimeout && result != input {
                Issue.record(
                    "Timeout exceeded \(timeout) seconds: received \(input), expected \(result)",
                    sourceLocation: Testing.SourceLocation(
                        fileID: String(describing: fileID),
                        filePath: String(describing: filePath),
                        line: Int(line),
                        column: Int(column)
                    )
                )
            } else {
                #expect(
                    result == input,
                    sourceLocation: Testing.SourceLocation(
                        fileID: String(describing: fileID),
                        filePath: String(describing: filePath),
                        line: Int(line),
                        column: Int(column)
                    )
                )
            }
        }
    }
    #else
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - fileID: The file ID from which the function is called.
    ///   - filePath: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    ///   - column: The column number from which the function is called.
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: Double = 2,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) async where Property: Sendable & Equatable {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        switch TestingFramework.current {
        case .xcTest:
            #if canImport(XCTest)
            if isTimeout && result != input {
                XCTFail(
                    "Timeout exceeded \(timeout) seconds: received \(input), expected \(result)",
                    file: filePath,
                    line: line
                )
            } else {
                XCTAssertEqual(
                    result,
                    input,
                    file: filePath,
                    line: line
                )
            }
            #else
            break
            #endif
        case .testing:
            if isTimeout && result != input {
                Issue.record(
                    "Timeout exceeded \(timeout) seconds: received \(input), expected \(result)",
                    sourceLocation: Testing.SourceLocation(
                        fileID: String(describing: fileID),
                        filePath: String(describing: filePath),
                        line: Int(line),
                        column: Int(column)
                    )
                )
            } else {
                #expect(
                    result == input,
                    sourceLocation: Testing.SourceLocation(
                        fileID: String(describing: fileID),
                        filePath: String(describing: filePath),
                        line: Int(line),
                        column: Int(column)
                    )
                )
            }
        }
    }
    #endif
}
#endif

#if !canImport(Testing) && canImport(XCTest)
extension Store {
    #if swift(>=6.0)
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - file: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property> & Sendable,
        _ input: Property,
        timeout: Double = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        if isTimeout && result != input {
            XCTFail(
                "Exceeded timeout of \(timeout) seconds",
                file: file,
                line: line
            )
        } else {
            XCTAssertEqual(
                result,
                input,
                file: file,
                line: line
            )
        }
    }
    #else
    /// Allows the expectation of a certain property value in the store's state. It compares the
    /// current value of the given `keyPath` in the state with an expected `input` value
    ///
    /// The function works asynchronously, waiting for the store to become idle, i.e., when the
    /// store is not actively processing or updating its state, before performing the comparison.
    ///
    /// - Parameters:
    ///   - keyPath: A key path that specifies the property in the `State` to be compared.
    ///   - input: The expected value of the property at the given key path.
    ///   - timeout: The maximum amount of time (in seconds) to wait for the store to finish
    ///   processing before timing out. Defaults to 2 seconds.
    ///   - file: The file path from which the function is called.
    ///   - line: The line number from which the function is called.
    public func expect<Property>(
        _ keyPath: KeyPath<State, Property>,
        _ input: Property,
        timeout: Double = 2,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async where Property: Sendable & Equatable {
        var isTimeout = false
        let start = CFAbsoluteTimeGetCurrent()
        await Task.detached(priority: .background) {
            await Task.yield()
        }.value
        await Task.yield()
        while !isIdle {
            await Task.detached(priority: .background) {
                await Task.yield()
            }.value
            await Task.yield()
            let elapsedTime = CFAbsoluteTimeGetCurrent() - start
            if elapsedTime > timeout {
                isTimeout = true
                break
            }
        }
        let result = state[keyPath: keyPath]
        if isTimeout && result != input {
            XCTFail(
                "Exceeded timeout of \(timeout) seconds",
                file: file,
                line: line
            )
        } else {
            XCTAssertEqual(
                result,
                input,
                file: file,
                line: line
            )
        }
    }
    #endif
}
#endif
