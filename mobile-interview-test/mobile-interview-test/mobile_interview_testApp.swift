//
//  mobile_interview_testApp.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

@main
struct mobile_interview_testApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView(
                viewModel: SearchViewModel(
                    service: URLSessionPlacesSearchService()
                )
            )
        }
    }
}
