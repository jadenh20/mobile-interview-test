//
//  SearchViewModelTests.swift
//  mobile-interview-testTests
//
//  Created by Jaden Hyde on 6/10/26.
//

import Foundation
import Testing
@testable import mobile_interview_test

@Suite("SearchViewModel")
@MainActor
struct SearchViewModelTests {

    // MARK: - Initial state

    @Test
    func initialStateIsNotStarted() {
        let viewModel = SearchViewModel(
            service: RecordingPlacesSearchService(),
            debounceInterval: .zero
        )
        #expect(viewModel.state == .notStarted)
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Happy path

    @Test
    func successfulSearchPopulatesSuccessState() async throws {
        let service = RecordingPlacesSearchService { _ in [Fixtures.nycCity] }
        let viewModel = SearchViewModel(service: service, debounceInterval: .zero)

        viewModel.searchText = "NYC"
        viewModel.searchTextDidChange("NYC")

        let reached = await waitFor { viewModel.state == .success([Fixtures.nycCity]) }
        #expect(reached, "Expected state to reach .success; actual: \(viewModel.state)")
        #expect(service.terms == ["NYC"])
    }

    @Test
    func emptyResultsLandInEmptyState() async {
        let service = RecordingPlacesSearchService { _ in [] }
        let viewModel = SearchViewModel(service: service, debounceInterval: .zero)

        viewModel.searchText = "no matches"
        viewModel.searchTextDidChange("no matches")

        let reached = await waitFor { viewModel.state == .empty }
        #expect(reached, "Expected .empty; actual: \(viewModel.state)")
    }

    @Test
    func serviceErrorLandsInErrorState() async {
        let service = RecordingPlacesSearchService { _ in throw StubError() }
        let viewModel = SearchViewModel(service: service, debounceInterval: .zero)

        viewModel.searchText = "broken"
        viewModel.searchTextDidChange("broken")

        let reached = await waitFor { viewModel.state == .error }
        #expect(reached, "Expected .error; actual: \(viewModel.state)")
    }

    // MARK: - Empty / whitespace input

    @Test
    func emptyTextResetsToNotStartedAndSkipsServiceCall() async {
        let service = RecordingPlacesSearchService { _ in [Fixtures.nycCity] }
        let viewModel = SearchViewModel(service: service, debounceInterval: .zero)

        // Put it into a non-default state first.
        viewModel.searchText = "NYC"
        viewModel.searchTextDidChange("NYC")
        _ = await waitFor { viewModel.state == .success([Fixtures.nycCity]) }

        // Now clear it.
        viewModel.searchText = ""
        viewModel.searchTextDidChange("")

        #expect(viewModel.state == .notStarted)
        // Clearing must NOT have triggered a second call.
        try? await Task.sleep(for: .milliseconds(20))
        #expect(service.callCount == 1)
    }

    // MARK: - Debouncing & cancellation

    @Test
    func debounceCollapsesRapidKeystrokesIntoSingleCall() async {
        let service = RecordingPlacesSearchService { _ in [] }
        let viewModel = SearchViewModel(service: service, debounceInterval: .milliseconds(100))

        viewModel.searchText = "N"
        viewModel.searchTextDidChange("N")

        viewModel.searchText = "Ne"
        viewModel.searchTextDidChange("Ne")

        viewModel.searchText = "New"
        viewModel.searchTextDidChange("New")

        // After 200ms (well past the 100ms debounce + service call) only the
        // last keystroke's request should have fired.
        try? await Task.sleep(for: .milliseconds(200))
        #expect(service.callCount == 1)
        #expect(service.terms == ["New"])
    }

    @Test
    func newKeystrokeCancelsInFlightCallAndSchedulesNew() async {
        // First call hangs until cancelled; second returns immediately. If
        // cancellation works, we never see a `.success([])` from the first
        // term, only the second term's result.
        let service = RecordingPlacesSearchService { terms in
            if terms == "first" {
                try await Task.sleep(for: .seconds(60))
                return [Fixtures.nycCity]
            }
            return [Fixtures.laCity]
        }
        let viewModel = SearchViewModel(service: service, debounceInterval: .zero)

        viewModel.searchText = "first"
        viewModel.searchTextDidChange("first")
        _ = await waitFor { service.callCount == 1 }

        viewModel.searchText = "second"
        viewModel.searchTextDidChange("second")

        let reached = await waitFor { viewModel.state == .success([Fixtures.laCity]) }
        #expect(reached, "Expected second call's result; actual: \(viewModel.state)")
        #expect(service.callCount == 2)
    }

    // MARK: - Retry

    @Test
    func retryReissuesSearchWithCurrentTextWithoutDebounce() async {
        let attempts = AtomicCounter()
        let service = RecordingPlacesSearchService { _ in
            attempts.increment()
            if attempts.value == 1 {
                throw StubError()
            }
            return [Fixtures.nycCity]
        }
        // Use a real (non-zero) debounce so we can confirm retry skips it.
        let viewModel = SearchViewModel(service: service, debounceInterval: .milliseconds(500))

        viewModel.searchText = "NYC"
        viewModel.searchTextDidChange("NYC")

        // Wait long enough for the debounce + first (failing) call.
        let reachedError = await waitFor { viewModel.state == .error }
        #expect(reachedError, "Expected .error after first attempt; actual: \(viewModel.state)")

        // Retry — should fire quickly because debounce is bypassed.
        viewModel.retry()
        let start = ContinuousClock().now
        let reachedSuccess = await waitFor { viewModel.state == .success([Fixtures.nycCity]) }
        let elapsed = ContinuousClock().now - start

        #expect(reachedSuccess, "Expected .success after retry; actual: \(viewModel.state)")
        // Generous bound, but well under the 500ms debounce.
        #expect(elapsed < .milliseconds(250), "Retry should bypass debounce; took \(elapsed)")
        #expect(service.callCount == 2)
    }
}

// MARK: - Tiny atomic counter

/// `RecordingPlacesSearchService`'s handler closure is `@Sendable`, which
/// rules out capturing a plain `var`. This counter lets us count attempts
/// from inside the handler safely.
private final class AtomicCounter: @unchecked Sendable {
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
