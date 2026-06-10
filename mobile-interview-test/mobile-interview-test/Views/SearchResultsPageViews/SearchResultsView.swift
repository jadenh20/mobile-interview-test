//
//  SearchResultsView.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

struct SearchResultsView: View {

    @State private var viewModel: HotelsSearchViewModel

    init(viewModel: HotelsSearchViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Search Results")
            .task { viewModel.loadInitial() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
        case .empty:
            emptyView
        case .error:
            errorView
        case .loaded(let hotels):
            hotelList(hotels)
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        Text("No hotels available for this location")
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 12) {
            Text("Something went wrong loading hotels. Please try again.")
                .multilineTextAlignment(.center)
            Button {
                viewModel.retry()
            } label: {
                Label("Retry", systemImage: "arrow.trianglehead.clockwise")
            }
        }
        .padding()
    }

    @ViewBuilder
    private func hotelList(_ hotels: [HotelData]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(hotels, id: \.id) { hotel in
                    HotelListingView(hotel: hotel)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentHotelID: hotel.id)
                        }
                }
                if viewModel.isLoadingNextPage {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
    }
}

#if DEBUG
/// In-memory fake used to drive previews without hitting the network.
private struct PreviewHotelsSearchService: HotelsSearchService {
    enum Mode {
        case success(hotels: [HotelData], total: Int)
        case empty
        case error
        case hang
    }
    let mode: Mode

    func searchHotels(
        latitude: Double,
        longitude: Double,
        limit: Int,
        offset: Int
    ) async throws -> SearchResultsData {
        switch mode {
        case .success(let hotels, let total):
            let slice = Array(hotels.dropFirst(offset).prefix(limit))
            return SearchResultsData(id: nil, total: total, pages: 0, page: 0, hotels: slice)
        case .empty:
            return SearchResultsData(id: nil, total: 0, pages: 0, page: 0, hotels: [])
        case .error:
            throw HotelsSearchServiceError.transportFailed
        case .hang:
            try await Task.sleep(for: .seconds(60))
            return SearchResultsData(id: nil, total: 0, pages: 0, page: 0, hotels: [])
        }
    }
}

private let previewHotels: [HotelData] = (1...6).map { i in
    HotelData(
        id: i,
        rating: 4.1,
        reviews: 164,
        city: "New York",
        state: "NY",
        name: "TWA Hotel #\(i)",
        desktop_img: "https://assets-staging.resortpass.dev/uploads/image/picture/35445/TWA_pool7.jpg"
    )
}

#Preview("Loaded") {
    SearchResultsView(viewModel: HotelsSearchViewModel(
        latitude: 40.757,
        longitude: -73.736,
        service: PreviewHotelsSearchService(mode: .success(hotels: previewHotels, total: previewHotels.count))
    ))
}

#Preview("Empty") {
    SearchResultsView(viewModel: HotelsSearchViewModel(
        latitude: 40.757,
        longitude: -73.736,
        service: PreviewHotelsSearchService(mode: .empty)
    ))
}

#Preview("Loading") {
    SearchResultsView(viewModel: HotelsSearchViewModel(
        latitude: 40.757,
        longitude: -73.736,
        service: PreviewHotelsSearchService(mode: .hang)
    ))
}

#Preview("Error") {
    SearchResultsView(viewModel: HotelsSearchViewModel(
        latitude: 40.757,
        longitude: -73.736,
        service: PreviewHotelsSearchService(mode: .error)
    ))
}
#endif
