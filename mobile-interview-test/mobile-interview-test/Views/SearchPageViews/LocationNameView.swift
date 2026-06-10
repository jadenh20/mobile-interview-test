//
//  SearchResultview.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

struct LocationNameView: View {
    
    let locationData: LocationData
    let boldTextLength: Int
    
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
        
        // This shouldn't ever happen
        guard boldTextLength <= locationData.name.count else {
            return attributed
        }
        
        let start = attributed.characters.index(attributed.startIndex, offsetBy: 0)
        let end = attributed.characters.index(attributed.startIndex, offsetBy: boldTextLength)
        
        attributed[start..<end].inlinePresentationIntent = .stronglyEmphasized
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
    LocationNameView(locationData: LocationData(id: 0, name: "Newport Beach, California", type: .city, latitude: 0.0, longitude: 0.0), boldTextLength: 3)
}

#Preview("Hotel") {
    LocationNameView(locationData: LocationData(id: 0, name: "The Ritz-Carlton", type: .hotel, latitude: 0.0, longitude: 0.0), boldTextLength: 5)
}
