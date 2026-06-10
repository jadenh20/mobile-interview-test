//
//  HotelsSearchViewModelTests.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/10/26.
//

import Foundation
import Testing
@testable import mobile_interview_test

@Suite("HotelsSearchViewModel")
@MainActor
struct HotelsSearchViewModelTests {

    private let latitude = 40.757
    private let longitude = -73.736

    // MARK: - Initial state

    @Test
    func initialStateIsLoading() {
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: RecordingHotelsSearchService { _ in
                Fixtures.hotelsPage([], total: 0)
            }
        )
        #expect(viewModel.state == .loading)
        #expect(viewModel.isLoadingNextPage == false)
        #expect(viewModel.hasMore == false)
    }

    // MARK: - loadInitial

    @Test
    func loadInitialPopulatesLoadedWithFirstPage() async {
        let firstPage = (1...3).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { _ in
            Fixtures.hotelsPage(firstPage, total: firstPage.count)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 30
        )

        viewModel.loadInitial()

        let reached = await waitFor { viewModel.state == .loaded(firstPage) }
        #expect(reached, "Expected .loaded(firstPage); actual: \(viewModel.state)")
        #expect(viewModel.hasMore == false)
        #expect(service.calls == [.init(latitude: latitude, longitude: longitude, limit: 30, offset: 0)])
    }

    @Test
    func loadInitialMarksHasMoreWhenResultsArePartial() async {
        let firstPage = (1...3).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { _ in
            Fixtures.hotelsPage(firstPage, total: 10)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }

        #expect(viewModel.hasMore == true)
    }

    @Test
    func loadInitialReturningEmptyArrayLandsInEmptyState() async {
        let service = RecordingHotelsSearchService { _ in
            Fixtures.hotelsPage([], total: 0)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service
        )

        viewModel.loadInitial()

        let reached = await waitFor { viewModel.state == .empty }
        #expect(reached, "Expected .empty; actual: \(viewModel.state)")
        #expect(viewModel.hasMore == false)
    }

    @Test
    func loadInitialFailureLandsInErrorState() async {
        let service = RecordingHotelsSearchService { _ in throw StubError() }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service
        )

        viewModel.loadInitial()

        let reached = await waitFor { viewModel.state == .error }
        #expect(reached, "Expected .error; actual: \(viewModel.state)")
        #expect(viewModel.hasMore == false)
    }

    // MARK: - Pagination

    @Test
    func loadMoreIfNeededFetchesNextPageWhenNearEnd() async {
        let firstPage = (1...10).map(Fixtures.hotel(id:))
        let secondPage = (11...15).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { call in
            if call.offset == 0 {
                return Fixtures.hotelsPage(firstPage, total: 15)
            }
            return Fixtures.hotelsPage(secondPage, total: 15)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 10,
            nextPageThreshold: 5
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }

        // The last hotel in the first page should trigger pagination.
        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.last!.id)

        let reached = await waitFor { viewModel.state == .loaded(firstPage + secondPage) }
        #expect(reached, "Expected appended page; actual: \(viewModel.state)")
        #expect(viewModel.hasMore == false)
        #expect(viewModel.isLoadingNextPage == false)
        #expect(service.calls.map(\.offset) == [0, 10])
    }

    @Test
    func loadMoreIfNeededIsIgnoredWhenFarFromEnd() async {
        let firstPage = (1...10).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { _ in
            Fixtures.hotelsPage(firstPage, total: 100)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 10,
            nextPageThreshold: 3
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }

        // The first hotel is nowhere near the threshold — no fetch expected.
        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.first!.id)

        try? await Task.sleep(for: .milliseconds(20))
        #expect(service.callCount == 1, "Should not have triggered a second call")
    }

    @Test
    func loadMoreIfNeededIsIgnoredWhenHasMoreIsFalse() async {
        let firstPage = (1...3).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { _ in
            Fixtures.hotelsPage(firstPage, total: firstPage.count)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 10
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }
        #expect(viewModel.hasMore == false)

        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.last!.id)

        try? await Task.sleep(for: .milliseconds(20))
        #expect(service.callCount == 1, "Should not paginate when there's no more")
    }

    @Test
    func loadMoreIfNeededIsIgnoredWhenAlreadyLoadingNextPage() async {
        let firstPage = (1...10).map(Fixtures.hotel(id:))
        let secondPage = (11...20).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { call in
            if call.offset == 0 {
                return Fixtures.hotelsPage(firstPage, total: 50)
            }
            // Hang the second page so we can verify a concurrent trigger is a no-op.
            try await Task.sleep(for: .seconds(60))
            return Fixtures.hotelsPage(secondPage, total: 50)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 10,
            nextPageThreshold: 5
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }

        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.last!.id)
        _ = await waitFor { viewModel.isLoadingNextPage == true }

        // Second trigger while the first is in flight — should be a no-op.
        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.last!.id)

        try? await Task.sleep(for: .milliseconds(20))
        #expect(service.callCount == 2, "Concurrent pagination request must not double-fire")
    }

    @Test
    func nextPageFailurePreservesExistingResultsAndDisablesPagination() async {
        let firstPage = (1...10).map(Fixtures.hotel(id:))
        let service = RecordingHotelsSearchService { call in
            if call.offset == 0 {
                return Fixtures.hotelsPage(firstPage, total: 50)
            }
            throw StubError()
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service,
            pageSize: 10,
            nextPageThreshold: 5
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .loaded(firstPage) }

        viewModel.loadMoreIfNeeded(currentHotelID: firstPage.last!.id)

        let reached = await waitFor {
            viewModel.hasMore == false && viewModel.isLoadingNextPage == false
        }
        #expect(reached)
        // Existing results must NOT have been replaced with .error.
        #expect(viewModel.state == .loaded(firstPage))
    }

    // MARK: - Retry

    @Test
    func retryRestartsFromOffsetZeroAndCancelsPriorLoad() async {
        let firstAttempt = (1...5).map(Fixtures.hotel(id:))
        let attempts = HandlerCallCounter()
        let service = RecordingHotelsSearchService { _ in
            attempts.increment()
            if attempts.value == 1 {
                throw StubError()
            }
            return Fixtures.hotelsPage(firstAttempt, total: firstAttempt.count)
        }
        let viewModel = HotelsSearchViewModel(
            latitude: latitude,
            longitude: longitude,
            service: service
        )

        viewModel.loadInitial()
        _ = await waitFor { viewModel.state == .error }

        viewModel.retry()

        let reached = await waitFor { viewModel.state == .loaded(firstAttempt) }
        #expect(reached, "Expected retry to land in .loaded; actual: \(viewModel.state)")
        #expect(service.calls.map(\.offset) == [0, 0])
    }
}

private final class HandlerCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func increment() {
        lock.lock(); defer { lock.unlock() }
        _value += 1
    }
}
