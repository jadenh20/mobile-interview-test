//
//  HotelsSearchService.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation

/// Abstraction over the hotel listings endpoint used by Screen 2. Defined as a
/// protocol so the view model can be unit-tested against a fake without
/// hitting the network.
protocol HotelsSearchService: Sendable {
    func searchHotels(
        latitude: Double,
        longitude: Double,
        limit: Int,
        offset: Int
    ) async throws -> SearchResultsData
}

enum HotelsSearchServiceError: Error, Equatable {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case encodingFailed
    case decodingFailed
    case transportFailed
}

struct URLSessionHotelsSearchService: HotelsSearchService {

    private let baseURL: URL
    private let session: any HTTPSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://staging-app.resortpass.com")!,
        session: any HTTPSession = URLSession.shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    func searchHotels(
        latitude: Double,
        longitude: Double,
        limit: Int,
        offset: Int
    ) async throws -> SearchResultsData {
        let url = baseURL.appendingPathComponent("api/search/algolia_hotels_v7")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RequestBody(
            location: .init(latitude: latitude, longitude: longitude),
            limit: limit,
            offset: offset
        )
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw HotelsSearchServiceError.encodingFailed
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw CancellationError()
        } catch {
            throw HotelsSearchServiceError.transportFailed
        }

        guard let http = response as? HTTPURLResponse else {
            throw HotelsSearchServiceError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HotelsSearchServiceError.invalidResponse(statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(SearchResultsData.self, from: data)
        } catch {
            throw HotelsSearchServiceError.decodingFailed
        }
    }

    private struct RequestBody: Encodable {
        let location: Location
        let limit: Int
        let offset: Int

        struct Location: Encodable {
            let latitude: Double
            let longitude: Double
        }
    }
}
