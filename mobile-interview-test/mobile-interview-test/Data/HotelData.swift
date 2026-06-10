//
//  HotelData.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation

struct HotelData: Codable, Hashable {
    var id: Int
    var rating: Double
    var reviews: Int
    var city: String
    var state: String
    var name: String
    var desktop_img: String
    var products: [ProductData]

    // The API returns the full state name under the key "state"; everything
    // else matches the property names directly.
    private enum CodingKeys: String, CodingKey {
        case id, rating, reviews, name, desktop_img, products
        case city = "city_name"
        case state = "state_code"
    }
}

