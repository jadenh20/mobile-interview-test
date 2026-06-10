//
//  HotelsSearchServiceTests.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation
import Testing
@testable import mobile_interview_test

@Suite("URLSessionHotelsSearchService")
struct HotelsSearchServiceTests {

    private let baseURL = URL(string: "https://example.com")!

    // MARK: - Happy path

    @Test
    func decodesSuccessfulResponseIntoSearchResultsData() async throws {
        let json = Data("""
        {
            "total": 164,
            "pages": 6,
            "page": 0,
            "hotels": [
                {
                    "id": 1990,
                    "rating": 4.1,
                    "reviews": 164,
                    "city_name": "New York",
                    "state_code": "NY",
                    "name": "TWA Hotel",
                    "desktop_img": "https://example.com/twa.jpg"
                }
            ]
        }
        """.utf8)

        let session = MockHTTPSession { request in
            (json, httpResponse(for: request))
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        let results = try await service.searchHotels(
            latitude: 40.757,
            longitude: -73.736,
            limit: 30,
            offset: 0
        )

        #expect(results.total == 164)
        #expect(results.pages == 6)
        #expect(results.page == 0)
        #expect(results.hotels.count == 1)

        let hotel = try #require(results.hotels.first)
        #expect(hotel.id == 1990)
        #expect(hotel.name == "TWA Hotel")
        #expect(hotel.city == "New York")
        #expect(hotel.state == "NY")
    }

    // MARK: - Request construction

    @Test
    func requestUsesPOSTToHotelsEndpoint() async throws {
        let captured = CaptureBox<URLRequest>()
        let session = MockHTTPSession { request in
            captured.set(request)
            return (Data(#"{"total":0,"pages":0,"page":0,"hotels":[]}"#.utf8), httpResponse(for: request))
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        _ = try await service.searchHotels(latitude: 0, longitude: 0, limit: 30, offset: 0)

        let request = try #require(captured.value)
        let url = try #require(request.url)
        #expect(url.path == "/api/search/algolia_hotels_v7")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test
    func requestBodyHasLocationLimitAndOffset() async throws {
        let captured = CaptureBox<URLRequest>()
        let session = MockHTTPSession { request in
            captured.set(request)
            return (Data(#"{"total":0,"pages":0,"page":0,"hotels":[]}"#.utf8), httpResponse(for: request))
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        _ = try await service.searchHotels(
            latitude: 40.757,
            longitude: -73.736,
            limit: 30,
            offset: 60
        )

        let request = try #require(captured.value)
        let body = try #require(request.httpBody)

        // Decode the body back into a structural representation we can assert
        // against — keeps the test resilient to key ordering.
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: body, options: []) as? [String: Any]
        )
        #expect(parsed["limit"] as? Int == 30)
        #expect(parsed["offset"] as? Int == 60)

        let location = try #require(parsed["location"] as? [String: Any])
        #expect((location["latitude"] as? Double) == 40.757)
        #expect((location["longitude"] as? Double) == -73.736)
    }

    // MARK: - Error paths

    @Test
    func nonSuccessStatusCodeThrowsInvalidResponse() async throws {
        let session = MockHTTPSession { request in
            (Data(), httpResponse(for: request, statusCode: 503))
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        await #expect(throws: HotelsSearchServiceError.invalidResponse(statusCode: 503)) {
            _ = try await service.searchHotels(latitude: 0, longitude: 0, limit: 30, offset: 0)
        }
    }

    @Test
    func malformedJSONThrowsDecodingFailed() async throws {
        let session = MockHTTPSession { request in
            (Data("not valid json".utf8), httpResponse(for: request))
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        await #expect(throws: HotelsSearchServiceError.decodingFailed) {
            _ = try await service.searchHotels(latitude: 0, longitude: 0, limit: 30, offset: 0)
        }
    }

    @Test
    func transportFailureThrowsTransportFailed() async throws {
        struct FakeTransportError: Error {}
        let session = MockHTTPSession { _ in
            throw FakeTransportError()
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        await #expect(throws: HotelsSearchServiceError.transportFailed) {
            _ = try await service.searchHotels(latitude: 0, longitude: 0, limit: 30, offset: 0)
        }
    }

    @Test
    func urlSessionCancellationIsRethrownAsCancellationError() async throws {
        let session = MockHTTPSession { _ in
            throw URLError(.cancelled)
        }
        let service = URLSessionHotelsSearchService(baseURL: baseURL, session: session)

        await #expect(throws: CancellationError.self) {
            _ = try await service.searchHotels(latitude: 0, longitude: 0, limit: 30, offset: 0)
        }
    }
}
