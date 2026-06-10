//
//  SearchResult.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

struct LocationData: Codable, Hashable {
    let id: Int
    let name: String
    let type: LocationType
    let latitude: Double
    let longitude: Double
}

enum LocationType: String, Codable {
    case city
    case hotel
    case alias
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = LocationType(rawValue: raw) ?? .unknown
    }
}
