//
//  ProductData.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/10/26.
//

struct ProductData: Codable, Hashable {
    let id: Int
    let availability: ProductAvailability
    let price: Double
    let categories: [String]
    let typeName: String
    
    private enum CodingKeys: String, CodingKey {
        case id, availability, price
        case categories = "product_categories"
        case typeName = "product_type_name"
    }
}

enum ProductAvailability: String, Codable {
    case available
    case unavailable
    case unknown
    
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProductAvailability(rawValue: raw) ?? .unknown
    }

}

