# Passport Index Toolbox - System Design Review

## 1. Scope and Goals
- Build a client-side passport comparison tool (Flutter Web first, multi-platform capable).
- Support comparison for 1-5 passports with year selection and detailed destination access matrix.
- Survive API instability by falling back to local bundled dataset (`lib/data.json`).
- Keep deployment simple on static hosting (GitHub Pages), without a custom backend.

## 2. Architecture Overview
### High-level components
- `lib/main.dart`: UI composition + app-level state orchestration.
- `lib/services/api_service.dart`: network access, fallback logic, and data caching.
- `lib/models/country.dart`: domain model for country summary + yearly data.
- `lib/widgets/*`: presentation components (`PassportInputRow`, `ComparisonTable`, indicators).
- `SharedPreferences`: lightweight persistence for favorites and cached country payload.
- `lib/data.json`: offline fallback source for countries and visa detail extraction.

### Runtime data flow
1. User clicks `Start` -> `ApiService.fetchCountries()`.
2. Service tries `GET /countries` with timeout.
3. If API fails/invalid:
- try `cached_countries` from `SharedPreferences`;
- if still unusable, load `lib/data.json`.
4. User clicks `Details` -> lazy fetch `GET /visa-single/{code}` per selected passport.
5. If visa detail API fails, extract equivalent detail codes from local `data.json`.
6. UI renders matrix using `visaFreeMap`, supports search and "Diff Only" filter.

## 3. Architecture Tradeoffs
### Chosen
- Single-screen orchestration in one `StatefulWidget` (`_PassportComparePageState`).
- Service-level fallback + caching logic concentrated in `ApiService`.
- Local persistence with `SharedPreferences` (JSON string payloads).

### Benefits
- Fast implementation velocity and low operational overhead.
- No backend dependency for persistence.
- Clear fallback chain improves reliability in weak network conditions.

### Costs
- `main.dart` is large; UI/state concerns are tightly coupled.
- Dynamic JSON maps reduce compile-time safety.
- `SharedPreferences` JSON blobs can be brittle for schema evolution.

## 4. Data Structures: Why This Design
### 4.1 `List<String?> selectedCountryCodes` (fixed length 5)
- Why chosen:
- Direct mapping from UI slot index -> selected country.
- Simple enable/disable logic for compare button.
- Efficient for small fixed max (`<=5`).
- Alternatives:
- `Map<int, String>`: more explicit indexing but more null/absence checks.
- `List<PassportSelection>` object: cleaner domain model, more code overhead.

### 4.2 `List<String> selectedYears` (parallel to selectedCountryCodes)
- Why chosen:
- O(1) lookup by same index as selected country.
- Keeps render logic straightforward in summary cards.
- Alternatives:
- Merge into one typed list (`List<PassportSelection{code, year}>`) to remove parallel-array coupling.

### 4.3 `Map<String, Set<String>> visaFreeMap`
- Why chosen:
- Key = source passport code, Value = reachable destination codes.
- `Set<String>` gives O(1) membership for matrix checks and diff filtering.
- Avoids duplicate destination entries by definition.
- Alternatives:
- `Map<String, List<String>>`: slower membership checks (O(n)).
- Bitset/compressed index structure: better memory/perf at scale, but unnecessary complexity for current size.

### 4.4 `List<Map<String, dynamic>> _favorites`
- Why chosen:
- Easy JSON encode/decode into `SharedPreferences`.
- Minimal model overhead for quick feature delivery.
- Alternatives:
- `List<FavoriteSnapshot>` typed model + serializers: safer refactoring and schema evolution.
- SQLite/Isar/Hive: stronger query/versioning, higher complexity/dependency cost.

### 4.5 `Country.yearlyData` as `Map<String, dynamic>?`
- Why chosen:
- API year fields are dynamic keys (`"2024"`, `"2023"`...), map shape aligns naturally.
- Flexible with partial/missing year data.
- Alternatives:
- `Map<int, YearStat>` typed map for stronger compile-time guarantees.
- Custom normalized table structure for analytics-heavy use cases.

## 5. Reliability Strategy
- Timeout guard on external API calls (`12s`).
- Three-tier fallback for `/countries`: API -> local cache -> bundled dataset.
- Fallback for `/visa-single/{code}` from bundled dataset when frontend API call fails.
- In-memory memoization of visa details (`_cache`) to reduce duplicate calls.

## 6. Interview Deep-Dive Prep (Likely Questions)
1. Why no backend service?
- Static deployment and low ops cost were prioritized; data is read-mostly and API-backed.

2. Why not state management framework (Riverpod/BLoC)?
- Scope is currently single-screen with bounded state; local state kept delivery speed high.
- If screens/features grow, move to feature-level state isolation.

3. Why use `Set` for visa details?
- Matrix rendering and "Diff Only" rely on frequent membership tests; `Set` is the right default.

4. What is the biggest architectural risk now?
- Growth risk in `main.dart` (coupled UI/business logic) and untyped favorites payloads.

5. What would be first refactor?
- Extract `ComparisonController` (or equivalent) and typed `FavoriteSnapshot` model.
- Keep `ApiService` fallback contract unchanged to preserve behavior.

6. How would you scale to large datasets?
- Pre-normalize data, use typed models, offload heavy transforms to isolate/background compute, and paginate/filter server-side when possible.

## 7. Recommended Next Iteration
- Split app state into feature controllers (`selection`, `comparison`, `favorites`).
- Replace dynamic favorite maps with typed DTO + version field.
- Add explicit contract tests for fallback precedence and malformed local dataset behavior.
