//
//  SearchResultsData.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

struct SearchResultsData: Codable, Hashable {
    // The hotels endpoint does not return a top-level `id`; keeping the
    // property optional so it doesn't break decoding.
    var id: Int?
    var total: Int
    var pages: Int
    var page: Int
    var hotels: [HotelData]
}
