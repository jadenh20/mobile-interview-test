//
//  SearchResultview.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

struct LocationNameView: View {
    
    let locationData: LocationData
    let boldText: String
    
    public var body: some View {
        HStack {
            icon
                .foregroundStyle(Color.black)
            Text(formattedLocationName)
        }
        .frame(height: 24)
    }
    
    private var formattedLocationName: AttributedString {
        var attributed = AttributedString(locationData.name)
        
        guard let boldRange = attributed.range(of: boldText) else {
            return attributed
        }
        
        attributed[boldRange].inlinePresentationIntent = .stronglyEmphasized
        return attributed
    }
    
    private var icon: Image {
        switch locationData.type {
        case .city, .alias, .unknown:
            return Image(systemName: "mappin.circle")
        case .hotel:
            return Image(systemName: "building.2")
        }
    }
}

#Preview("City") {
    LocationNameView(locationData: LocationData(id: 0, name: "Newport Beach, California", type: .city, latitude: 0.0, longitude: 0.0), boldText: "New")
}

#Preview("Hotel") {
    LocationNameView(locationData: LocationData(id: 0, name: "The Ritz-Carlton", type: .hotel, latitude: 0.0, longitude: 0.0), boldText: "Ritz")
}
