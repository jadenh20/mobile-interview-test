//
//  HotelListingView.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

struct HotelListingView: View {
    
    var hotel: HotelData
    
    public var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(string: hotel.desktop_img)) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.15)
                    .frame(height: 227)
            }
            Text(hotel.name)
                .font(.headline)
                .padding(.top, 10)
            HStack(spacing: 5) {
                ratingsView
                Divider()
                    .frame(height: 16)
                Text("\(hotel.city), \(hotel.state)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(20)
    }
    
    @ViewBuilder
    private var ratingsView: some View {
        ForEach(1..<6, id: \.self) { number in
            image(for: Double(number))
        }
        Text(String(format: "%.1f", hotel.rating))
        Text("(\(hotel.reviews))")
    }
    
    private func image(for number: Double) -> Image {
        if number <= hotel.rating {
            return Image(systemName: "star.fill")
        } else {
            return number - hotel.rating >= 1 ? Image(systemName: "star") : Image(systemName: "star.leadinghalf.filled")
        }
    }
}

#Preview {
    HotelListingView(hotel: HotelData(
        id: 0,
        rating: 4.6,
        reviews: 200,
        city: "New York",
        state: "NY",
        name: "TWA Hotel",
        desktop_img: "<https://assets-staging.resortpass.dev/uploads/image/picture/35445/TWA_pool7.jpg>"
    ))
}
