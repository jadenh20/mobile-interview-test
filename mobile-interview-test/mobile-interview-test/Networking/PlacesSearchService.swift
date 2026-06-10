//
//  PlacesSearchService.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation

/// Abstraction over the autocomplete endpoint. Defined as a protocol so the
/// view model can be unit-tested with an in-memory fake without hitting the
/// network.
protocol PlacesSearchService: Sendable {
    func searchPlaces(terms: String) async throws -> [LocationData]
}

enum PlacesSearchServiceError: Error, Equatable {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case decodingFailed
    case transportFailed
}

struct URLSessionPlacesSearchService: PlacesSearchService {

    private let baseURL: URL
    private let session: any HTTPSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://staging-app.resortpass.com")!,
        session: any HTTPSession = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    func searchPlaces(terms: String) async throws -> [LocationData] {
        print("SEARCH PLACES: \(terms)")
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/search/places/autocomplete"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "terms", value: terms),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0")
        ]
        guard let url = components?.url else {
            print("ERROR: invalid URL")
            throw PlacesSearchServiceError.invalidURL
        }
        
        print("URL: \(url)")

        let request = URLRequest(url: url)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            print("ERROR: cancellation error")
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            print("ERROR: urlError code cancellation error")
            throw CancellationError()
        } catch {
            print("ERROR: transport failed")
            throw PlacesSearchServiceError.transportFailed
        }

        guard let http = response as? HTTPURLResponse else {
            print("ERROR: Invalid Response")
            throw PlacesSearchServiceError.invalidResponse(statusCode: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            print("ERROR: Invalid Response status code")
            throw PlacesSearchServiceError.invalidResponse(statusCode: http.statusCode)
        }

        do {
            print(String(data: data, encoding: .utf8) ?? "Invalid data format")
            return try decoder.decode([LocationData].self, from: data)
        } catch {
            print("ERROR: decoding failed")
            throw PlacesSearchServiceError.decodingFailed
        }
    }
}
