//
//  ViewModelTestSupport.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/10/26.
//

import Foundation
@testable import mobile_interview_test

// MARK: - PlacesSearchService recorder

/// Closure-driven `PlacesSearchService` that records every call for assertion.
/// Tests run sequentially per view-model instance, so `@unchecked Sendable`
/// with an `NSLock` is sufficient.
final class RecordingPlacesSearchService: PlacesSearchService, @unchecked Sendable {
    typealias Handler = @Sendable (String) async throws -> [LocationData]

    private let lock = NSLock()
    private var recordedTerms: [String] = []
    private let handler: Handler

    init(_ handler: @escaping Handler = { _ in [] }) {
        self.handler = handler
    }

    var terms: [String] {
        lock.lock(); defer { lock.unlock() }
        return recordedTerms
    }

    var callCount: Int { terms.count }

    func searchPlaces(terms searchTerms: String) async throws -> [LocationData] {
        lock.lock()
        recordedTerms.append(searchTerms)
        lock.unlock()
        return try await handler(searchTerms)
    }
}

// MARK: - HotelsSearchService recorder

/// Closure-driven `HotelsSearchService` that records every call.
final class RecordingHotelsSearchService: HotelsSearchService, @unchecked Sendable {
    struct Call: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        let limit: Int
        let offset: Int
    }

    typealias Handler = @Sendable (Call) async throws -> SearchResultsData

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    private let handler: Handler

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return recordedCalls
    }

    var callCount: Int { calls.count }

    func searchHotels(
        latitude: Double,
        longitude: Double,
        limit: Int,
        offset: Int
    ) async throws -> SearchResultsData {
        let call = Call(latitude: latitude, longitude: longitude, limit: limit, offset: offset)
        lock.lock()
        recordedCalls.append(call)
        lock.unlock()
        return try await handler(call)
    }
}

// MARK: - Polling helper

/// View models kick off async work via `Task { ... }` and don't expose the
/// task handle. To verify the resulting state without exposing test-only
/// API on the view models, poll the condition with a short timeout. Returns
/// `true` if the condition was satisfied before the deadline, `false` if it
/// timed out — callers can `#expect` on that and on the final state for
/// clear failure output.
@discardableResult
func waitFor(
    timeout: Duration = .seconds(2),
    pollEvery interval: Duration = .milliseconds(5),
    _ condition: () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now >= deadline { return false }
        try? await Task.sleep(for: interval)
    }
    return true
}

// MARK: - Fixtures

enum Fixtures {
    static let nycCity = LocationData(
        id: 1,
        name: "New York, New York",
        type: .city,
        latitude: 40.7128,
        longitude: -74.0060
    )

    static let laCity = LocationData(
        id: 2,
        name: "Los Angeles, California",
        type: .city,
        latitude: 34.0522,
        longitude: -118.2437
    )

    static func hotel(id: Int) -> HotelData {
        HotelData(
            id: id,
            rating: 4.0,
            reviews: 100,
            city: "New York",
            state: "NY",
            name: "Hotel #\(id)",
            desktop_img: "https://example.com/\(id).jpg"
        )
    }

    /// Builds a `SearchResultsData` from `hotels` and an explicit `total` so
    /// tests can simulate "page N of M" scenarios without writing JSON.
    static func hotelsPage(_ hotels: [HotelData], total: Int) -> SearchResultsData {
        SearchResultsData(
            id: nil,
            total: total,
            pages: 0,
            page: 0,
            hotels: hotels
        )
    }
}

struct StubError: Error, Equatable {}
