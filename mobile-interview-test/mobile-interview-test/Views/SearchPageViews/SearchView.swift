//
//  ContentView.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import SwiftUI

struct SearchView: View {

    @State private var viewModel: SearchViewModel
    private let hotelsSearchService: HotelsSearchService

    init(
        viewModel: SearchViewModel,
        hotelsSearchService: HotelsSearchService = URLSessionHotelsSearchService()
    ) {
        _viewModel = State(wrappedValue: viewModel)
        self.hotelsSearchService = hotelsSearchService
    }

    var body: some View {
//        @Bindable var viewModel = viewModel
        NavigationView {
            VStack(spacing: 10) {
                TextField("Search for a location", text: $viewModel.searchText)
                    .disableAutocorrection(true)
                    .padding(10)
                    .border(.secondary)
                    .onAppear {
                        UITextField.appearance().clearButtonMode = .whileEditing
                    }
                content
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .onChange(of: viewModel.searchText) { _, newValue in
                viewModel.searchTextDidChange(newValue)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingView
        case .notStarted:
            placeholderView
        case .empty:
            emptyView
        case .success(let results):
            locationResultsView(results)
        case .error:
            errorView
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        Spacer()
        ProgressView()
            .frame(alignment: .center)
    }

    @ViewBuilder
    private var placeholderView: some View {
        Spacer()
        Text("Begin typing to search for a location")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .font(.headline)
    }

    @ViewBuilder
    private var emptyView: some View {
        Spacer()
        Text("No locations matched your search")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .font(.headline)
    }

    @ViewBuilder
    private var errorView: some View {
        Spacer()
        Text("There was an error with your search. Please try again")
            .multilineTextAlignment(.center)
        Button("", systemImage: "arrow.trianglehead.clockwise") {
            viewModel.retry()
        }
    }

    @ViewBuilder
    private func locationResultsView(_ results: [LocationData]) -> some View {
        VStack(alignment: .leading) {
            ForEach(results, id: \.self) { searchResult in
                NavigationLink {
                    SearchResultsView(
                        viewModel: HotelsSearchViewModel(
                            latitude: searchResult.latitude,
                            longitude: searchResult.longitude,
                            service: hotelsSearchService
                        )
                    )
                } label: {
                    LocationNameView(locationData: searchResult, boldTextLength: viewModel.searchText.count)
                        .padding(.horizontal, 5)
                }
                .foregroundStyle(.black)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
/// In-memory fake used to drive previews without hitting the network.
private struct PreviewPlacesSearchService: PlacesSearchService {
    enum Mode { case success([LocationData]), empty, error, hang }
    let mode: Mode

    func searchPlaces(terms: String) async throws -> [LocationData] {
        switch mode {
        case .success(let results): return results
        case .empty: return []
        case .error: throw PlacesSearchServiceError.transportFailed
        case .hang:
            try await Task.sleep(for: .seconds(60))
            return []
        }
    }
}

#Preview("Search Results - Success") {
    let results = [
        LocationData(id: 0, name: "New York, New York", type: .city, latitude: 0.0, longitude: 0.0),
        LocationData(id: 1, name: "New Haven, Connecticut", type: .city, latitude: 0.0, longitude: 0.0),
        LocationData(id: 2, name: "The Four Seasons", type: .hotel, latitude: 0.0, longitude: 0.0)
    ]
    SearchView(viewModel: SearchViewModel(service: PreviewPlacesSearchService(mode: .success(results))))
}

#Preview("Placeholder Text - Not Started") {
    SearchView(viewModel: SearchViewModel(service: PreviewPlacesSearchService(mode: .empty)))
}

#Preview("Loading") {
    SearchView(viewModel: SearchViewModel(service: PreviewPlacesSearchService(mode: .hang)))
}

#Preview("Error") {
    SearchView(viewModel: SearchViewModel(service: PreviewPlacesSearchService(mode: .error)))
}
#endif
