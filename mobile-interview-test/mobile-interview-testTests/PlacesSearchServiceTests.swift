//
//  PlacesSearchServiceTests.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation
import Testing
@testable import mobile_interview_test

@Suite("URLSessionPlacesSearchService")
struct PlacesSearchServiceTests {

    private let baseURL = URL(string: "https://example.com")!

    // MARK: - Happy path

    @Test
    func decodesSuccessfulResponseIntoLocationData() async throws {
        let json = Data("""
        [
            {
                "id": 236,
                "name": "Newport Beach, California",
                "type": "city",
                "latitude": 33.6189,
                "longitude": -117.9298
            },
            {
                "id": 1990,
                "name": "TWA Hotel",
                "type": "hotel",
                "latitude": 40.6457,
                "longitude": -73.7780
            }
        ]
        """.utf8)

        let session = MockHTTPSession { request in
            (json, httpResponse(for: request))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        let results = try await service.searchPlaces(terms: "anything")

        #expect(results.count == 2)
        #expect(results[0].id == 236)
        #expect(results[0].name == "Newport Beach, California")
        #expect(results[0].type == .city)
        #expect(results[1].type == .hotel)
    }

    @Test
    func emptyArrayResponseReturnsEmptyResults() async throws {
        let session = MockHTTPSession { request in
            (Data("[]".utf8), httpResponse(for: request))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        let results = try await service.searchPlaces(terms: "no matches")
        #expect(results.isEmpty)
    }

    // MARK: - Request construction

    @Test
    func requestUsesAutocompletePathAndQueryParameters() async throws {
        let captured = CaptureBox<URLRequest>()
        let session = MockHTTPSession { request in
            captured.set(request)
            return (Data("[]".utf8), httpResponse(for: request))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        _ = try await service.searchPlaces(terms: "New York")

        let request = try #require(captured.value)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

        #expect(components.path == "/api/search/places/autocomplete")
        let items = components.queryItems ?? []
        #expect(items.contains(URLQueryItem(name: "terms", value: "New York")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "10")))
        #expect(items.contains(URLQueryItem(name: "offset", value: "0")))
    }

    @Test
    func requestDefaultsToGETWithoutBody() async throws {
        let captured = CaptureBox<URLRequest>()
        let session = MockHTTPSession { request in
            captured.set(request)
            return (Data("[]".utf8), httpResponse(for: request))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        _ = try await service.searchPlaces(terms: "anything")

        let request = try #require(captured.value)
        // URLRequest's default method is GET when none is set explicitly.
        #expect(request.httpMethod == nil || request.httpMethod == "GET")
        #expect(request.httpBody == nil)
    }

    // MARK: - Error paths

    @Test
    func nonSuccessStatusCodeThrowsInvalidResponse() async throws {
        let session = MockHTTPSession { request in
            (Data(), httpResponse(for: request, statusCode: 500))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        await #expect(throws: PlacesSearchServiceError.invalidResponse(statusCode: 500)) {
            _ = try await service.searchPlaces(terms: "anything")
        }
    }

    @Test
    func malformedJSONThrowsDecodingFailed() async throws {
        let session = MockHTTPSession { request in
            (Data("not valid json".utf8), httpResponse(for: request))
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        await #expect(throws: PlacesSearchServiceError.decodingFailed) {
            _ = try await service.searchPlaces(terms: "anything")
        }
    }

    @Test
    func transportFailureThrowsTransportFailed() async throws {
        struct FakeTransportError: Error {}
        let session = MockHTTPSession { _ in
            throw FakeTransportError()
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        await #expect(throws: PlacesSearchServiceError.transportFailed) {
            _ = try await service.searchPlaces(terms: "anything")
        }
    }

    @Test
    func urlSessionCancellationIsRethrownAsCancellationError() async throws {
        let session = MockHTTPSession { _ in
            throw URLError(.cancelled)
        }
        let service = URLSessionPlacesSearchService(baseURL: baseURL, session: session)

        await #expect(throws: CancellationError.self) {
            _ = try await service.searchPlaces(terms: "anything")
        }
    }
}
