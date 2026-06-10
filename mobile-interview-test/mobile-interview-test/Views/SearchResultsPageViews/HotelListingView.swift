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
            productView
                .padding(.vertical, 10)
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
    
    @ViewBuilder
    private var productView: some View {
        VStack(alignment: .leading, spacing: 5.0) {
            ForEach(hotel.products, id: \.self) { product in
                HStack(alignment: .center) {
                    Text(product.typeName)
                        .font(.system(size: 15.0, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    ForEach(product.categories, id: \.self) { category in
                        Text(category)
                            .font(.system(size: 12.0))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    Divider()
                        .frame(height: 16)
                    
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.system(size: 15.0))
                    
                    Divider()
                        .frame(height: 16)
                    
                    switch product.availability {
                    case .available:
                        Text("Available")
                            .font(.system(size: 12.0))
                    case .unavailable, .unknown:
                        Text("Unavailable")
                            .font(.system(size: 12.0))
                    }
                }
            }
        }
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
        desktop_img: "<https://assets-staging.resortpass.dev/uploads/image/picture/35445/TWA_pool7.jpg>",
        products: [ProductData(
            id: 1,
            availability: ProductAvailability.available,
            price: 25.0,
            categories: ["Pool"],
            typeName: "Day Pass"
        ),
       ProductData(
           id: 2,
           availability: ProductAvailability.available,
           price: 75.0,
           categories: ["Spa"],
           typeName: "Spa Pass"
       )]
    ))
}
