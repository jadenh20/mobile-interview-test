# ResortPass iOS Interview — Implementation Notes

Two-screen native SwiftUI app: an autocomplete search of places, and a list of hotels for the selected place.

## Running it

Open `mobile-interview-test/mobile-interview-test.xcodeproj` in Xcode 16+ and run on any iOS 16+ simulator. No SPM resolution or setup steps required.

## Architecture

Layered, with a one-way data flow from services → view models → views:

```
Data/         Codable models (LocationData, HotelData, SearchResultsData)
Networking/   HTTPSession seam + two service protocols + their URLSession impls
ViewModels/   @Observable view models (SearchViewModel, HotelsSearchViewModel)
Views/        SwiftUI views, organized by screen
```

Each view model exposes a single `State` enum (`.loading / .empty / .success(...) / .error`) that the view exhaustively switches over. Mutations are unidirectional: views call methods on the view model; the view model mutates state; SwiftUI re-renders. Views own zero domain state — the only `@State` on each screen is the view model itself.

## Key choices & rationale

**MVVM with `@Observable` (iOS 17+)** — picked over ObservableObject/`@Published` because the new Observation framework gives finer-grained re-renders and removes the Combine dependency for plain state. Picked over TCA because the app is two screens; the ceremony isn't worth it at this size, but the layering here would map cleanly onto reducers/stores later.

**Swift Concurrency end-to-end, no Combine** — the brief explicitly favors `async/await`. The text-input debounce is implemented with `Task.sleep(for: .milliseconds(500))` inside a cancellable `Task`, not `Combine.debounce`. Each keystroke cancels the prior task (`currentSearchTask?.cancel()`) before spawning a new one, so `Task.checkCancellation()` / `URLError.cancelled` propagation handles both the debounce window *and* the in-flight network request uniformly.

**Networking — `URLSession` + a tiny `HTTPSession` protocol** — no third-party HTTP library; `URLSession` is more than enough for two endpoints. The `HTTPSession` protocol is a one-method seam over `data(for:)` so tests inject a closure-driven fake without needing `URLProtocol` global state (which races under Swift Testing's parallel execution). `URLSession` conforms via extension; the live composition is unchanged.

**Dependency injection — manual constructor injection of protocols** — services are protocols (`PlacesSearchService`, `HotelsSearchService`); view models take them via `init`. The app entry point (`mobile_interview_testApp`) is the single composition root. No DI container — the graph is small enough that a container would obscure more than it clarifies. The `hotelsSearchService` is threaded one level through `SearchView` so the `NavigationLink` can construct the next view model; if the graph grew I'd promote that to an environment value.

**Pagination on Screen 2** — `HotelsSearchViewModel` keeps two flags alongside `state`: `isLoadingNextPage` and `hasMore`. The next page appends into the existing `.loaded(...)` array rather than replacing it, so rows don't flicker. A page failure sets `hasMore = false` instead of clobbering existing results — UX prefers "we couldn't load more" over "we lost what you were reading."

**Forward-tolerant decoding** — the autocomplete API returns `type` values beyond the documented `city`/`hotel` (e.g. `alias`). `LocationType` has an explicit `.unknown` case and a custom `init(from:)` that maps any unrecognized raw value to `.unknown`, so a new API enum value can't take the search down.

**Navigation — `NavigationView` + `NavigationLink`** — works for two screens. For a real app I'd use `NavigationStack` with a typed path enum so destinations are data, not views, and deep linking is trivial.

## Testing

Swift Testing (`import Testing`, `@Test`, `#expect`) per the project's CLAUDE.md. The networking layer has unit coverage in `mobile-interview-testTests/`:

- `PlacesSearchServiceTests` — happy path decode, empty array, query-param construction, GET-without-body, HTTP error → `invalidResponse`, malformed JSON → `decodingFailed`, transport error → `transportFailed`, cancellation propagation.
- `HotelsSearchServiceTests` — happy path decode, POST method + content type, JSON body shape (location/limit/offset round-tripped), error paths, cancellation propagation.

Mocks live in `MockHTTPSession.swift` — a closure-driven `HTTPSession` plus a small `CaptureBox` helper for grabbing the outbound request out of the handler.

## Known limitations & what I'd do differently with more time

- **Image caching** — the brief calls this out as a bonus. Currently relies on `URLSession`'s default `URLCache`, which is small and shared. I'd add Nuke (or `Kingfisher`) for explicit memory + disk caching with proper eviction, or build a thin `ImageLoader` over `URLCache` with a larger budget.
- **Design system** — typography, spacing, and corner radii are inlined. I'd extract a `DesignTokens` namespace (or a dedicated module) with semantic colors that respect light/dark mode and Dynamic Type.
- **Accessibility** — basic SwiftUI defaults only. Would add explicit `accessibilityLabel` / `accessibilityHint` on each row, group ratings into a single readable label, and verify Dynamic Type behavior end-to-end.
- **Error surfacing** — both services collapse decode/transport failures to a single error state in the view model. For a production app I'd preserve the underlying `Error` (or a domain-specific enum) and let the view distinguish retryable vs. non-retryable failures
- **Generic HTTP client** — at this scale, two service implementations with copy-paste error mapping is fine. At three or more endpoints I'd extract a generic `HTTPClient` with typed `Endpoint` values and have each service describe its endpoint declaratively.
