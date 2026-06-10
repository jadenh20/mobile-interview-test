//
//  MockHTTPSession.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation
@testable import mobile_interview_test

/// Closure-driven `HTTPSession` used by the networking-service unit tests.
/// Each test constructs an instance with a handler that returns (or throws)
/// whatever the test needs, so we avoid any shared global state and the
/// tests are safe to run in parallel.
struct MockHTTPSession: HTTPSession {
    typealias Handler = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

/// Sendable single-shot box for capturing values out of a `@Sendable` handler
/// closure. Tests are sequential per-suite so the unchecked Sendable is safe
/// here; the lock is just belt-and-suspenders.
final class CaptureBox<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: Value?

    init() {}

    var value: Value? {
        lock.lock(); defer { lock.unlock() }
        return storedValue
    }

    func set(_ value: Value) {
        lock.lock(); defer { lock.unlock() }
        storedValue = value
    }
}

/// Convenience for building an `HTTPURLResponse` for a request URL.
func httpResponse(for request: URLRequest, statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(
        url: request.url!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: nil
    )!
}
