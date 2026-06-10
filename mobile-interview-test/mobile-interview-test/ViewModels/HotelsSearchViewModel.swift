//
//  HotelsSearchViewModel.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation
import Observation

/// Drives Screen 2 (hotel listings). Owns the page-by-page fetch lifecycle:
/// the initial load is exposed as a single `state` enum the view switches
/// over, while subsequent pages append to `.loaded` and surface a small
/// `isLoadingNextPage` flag so the list can show a trailing spinner without
/// hiding the existing results.
@MainActor
@Observable
final class HotelsSearchViewModel {

    enum State: Equatable {
        case loading
        case empty
        case loaded([HotelData])
        case error
    }

    private(set) var state: State = .loading
    private(set) var isLoadingNextPage: Bool = false
    private(set) var hasMore: Bool = false

    private let latitude: Double
    private let longitude: Double
    private let service: HotelsSearchService
    private let pageSize: Int
    private let nextPageThreshold: Int

    private var currentLoadTask: Task<Void, Never>?
    private var nextPageTask: Task<Void, Never>?

    init(
        latitude: Double,
        longitude: Double,
        service: HotelsSearchService,
        pageSize: Int = 30,
        nextPageThreshold: Int = 5
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.service = service
        self.pageSize = pageSize
        self.nextPageThreshold = nextPageThreshold
    }

    /// Fetches the first page. Safe to call repeatedly — any in-flight work
    /// from a previous invocation is cancelled first.
    func loadInitial() {
        currentLoadTask?.cancel()
        nextPageTask?.cancel()
        state = .loading
        isLoadingNextPage = false
        hasMore = false

        currentLoadTask = Task { [service, latitude, longitude, pageSize] in
            do {
                let response = try await service.searchHotels(
                    latitude: latitude,
                    longitude: longitude,
                    limit: pageSize,
                    offset: 0
                )
                if Task.isCancelled { return }
                if response.hotels.isEmpty {
                    state = .empty
                } else {
                    state = .loaded(response.hotels)
                    hasMore = response.hotels.count < response.total
                }
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                state = .error
            }
        }
    }

    /// Called by the list as each row appears. Triggers a next-page fetch
    /// when the user gets within `nextPageThreshold` rows of the end and we
    /// know more results are available.
    func loadMoreIfNeeded(currentHotelID: Int) {
        guard case .loaded(let hotels) = state else { return }
        guard hasMore, !isLoadingNextPage else { return }
        guard let index = hotels.firstIndex(where: { $0.id == currentHotelID }) else { return }
        guard index >= hotels.count - nextPageThreshold else { return }
        loadNextPage()
    }

    func retry() {
        loadInitial()
    }

    private func loadNextPage() {
        guard case .loaded(let existing) = state, hasMore, !isLoadingNextPage else { return }
        isLoadingNextPage = true
        let offset = existing.count

        nextPageTask = Task { [service, latitude, longitude, pageSize] in
            defer { isLoadingNextPage = false }
            do {
                let response = try await service.searchHotels(
                    latitude: latitude,
                    longitude: longitude,
                    limit: pageSize,
                    offset: offset
                )
                if Task.isCancelled { return }
                // Re-check state in case a retry replaced it while we were in flight.
                guard case .loaded(let current) = state else { return }
                let combined = current + response.hotels
                state = .loaded(combined)
                hasMore = combined.count < response.total
            } catch is CancellationError {
                return
            } catch {
                // Pagination failure shouldn't blow away the results the user
                // is already looking at — stop trying to fetch more.
                hasMore = false
            }
        }
    }
}
