//
//  SearchViewModel.swift
//  mobile-interview-test
//
//  Created by Jaden Hyde on 6/9/26.
//

import Foundation
import Observation

/// Owns the autocomplete search lifecycle for Screen 1.
///
/// The view binds `searchText` directly and notifies the view model of changes
/// via `searchTextDidChange(_:)`. The view model debounces, cancels in-progress
/// work, and exposes a single `state` enum that the view switches over —
/// keeping the data flow unidirectional and the view itself stateless beyond
/// the text field.
@MainActor
@Observable
final class SearchViewModel {

    enum State: Equatable {
        case notStarted
        case loading
        case empty
        case success([LocationData])
        case error
    }

    var searchText: String = ""
    private(set) var state: State = .notStarted

    private let service: PlacesSearchService
    private let debounceInterval: Duration
    private var currentSearchTask: Task<Void, Never>?

    init(
        service: PlacesSearchService,
        debounceInterval: Duration = .milliseconds(500)
    ) {
        self.service = service
        self.debounceInterval = debounceInterval
    }

    /// Called by the view whenever the text field's value changes.
    func searchTextDidChange(_ newValue: String) {
//        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let encodedString = newValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let encodedString, !encodedString.isEmpty else {
            currentSearchTask?.cancel()
            currentSearchTask = nil
            state = .notStarted
            return
        }
        scheduleSearch(for: encodedString, debounced: true)
    }

    /// Re-runs the most recent search without debouncing — used by the error
    /// retry button.
    func retry() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        scheduleSearch(for: trimmed, debounced: false)
    }

    /// Handles running the search with a debounce interval of 500ms
    private func scheduleSearch(for terms: String, debounced: Bool) {
        currentSearchTask?.cancel()
        state = .loading

        currentSearchTask = Task { [service, debounceInterval] in
            if debounced {
                do {
                    try await Task.sleep(for: debounceInterval)
                } catch {
                    return
                }
            }

            if Task.isCancelled { return }

            do {
                let results = try await service.searchPlaces(terms: terms)
                if Task.isCancelled { return }
                state = results.isEmpty ? .empty : .success(results)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                state = .error
            }
        }
    }
}
