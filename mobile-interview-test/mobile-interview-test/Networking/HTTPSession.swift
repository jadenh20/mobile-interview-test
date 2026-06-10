//
//  HTTPSession.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation

/// Narrow seam over `URLSession.data(for:)` so the networking services can be
/// driven by an in-memory fake in tests without resorting to `URLProtocol`
/// global state (which races under Swift Testing's parallel execution).
protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}
