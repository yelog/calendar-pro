# Holiday Feed Automation Implementation

**Status:** Implemented; feed publication and UI regression pending

**Design:** [2026-11-11-holiday-feed-automation-design.md](./2026-11-11-holiday-feed-automation-design.md)

## Outcome

- Added the State Council's 2027 mainland schedule: 29 statutory days and 5 adjustment workdays.
- Added `tools/sync_holidays.py` plus Python unit tests. The synchronizer validates the `gov.cn` source paper, dates, duplicates, day/off-day semantics, and cross-year records before writing.
- Manifest versions now use a monotonic `YYYY.MM.DD.HHMMSS` China-time value, so two revisions on the same day remain distinguishable. Same-year records no longer carry redundant `sourceScheduleYear` metadata.
- Cross-year records are split by actual date. A target year is only created when its own schedule is published; adjacent-year records can extend an already complete payload. Conflicting records from two schedule years fail the sync before any file is written.
- Added `.github/workflows/sync-holidays.yml`, scheduled daily in China time and supporting manual dispatch. It creates or updates a dedicated data pull request instead of pushing directly to `main`.
- Added `HolidayFeedRefreshScheduler`, which refreshes on launch, app activation, wake, and the cache's 12-hour expiry while deduplicating concurrent checks.
- The scheduler publishes its latest result or failure. The settings page now reflects background success, cached-only checks, and failures even when no payload was replaced.
- Changed remote refresh to download and decode every payload before committing a cache snapshot. The snapshot is staged first and activated by pointer switch, so a partial write preserves the previous complete cache.
- Missing or invalid cached payloads are repaired even when the manifest is unchanged. A failed check-time update no longer causes a one-second retry loop.
- Added `HolidayDatasetAvailability` with cache, bundled, missing, and invalid states.
- Cache read failures fall back to bundled data. Mainland records are additionally validated against the holiday-set ID that matches their kind.
- Added a month-calendar notice and accurate vacation-guide empty states for missing or unreadable years.
- Malformed bundle data no longer prevents the entire month grid from rendering.

## Verification

- `python3 -m unittest discover -s tools/tests -p 'test_*.py'` — 20 tests passed.
- `python3 tools/sync_holidays.py --years 2026 2027 --dry-run` — validated 39 records for 2026 and 34 for 2027.
- A real synchronization produced 39 records for 2026 and 34 for 2027; a second run reported that the feed was already up to date.
- `feed/holidays/manifest.json` now points to `mainland-cn-2027.json` and uses version `2026.11.11.164149`.
- Focused XCTest suites passed: 29 tests across holiday feed, scheduler, region settings, and mainland provider.
- A new-resource registration test in an isolated repository copy added `mainland-cn-2099.json` on the first run and made no project-file change on the second run.
- Full unit suite passed: 554 tests.
- `xcodebuild build -project CalendarPro.xcodeproj -scheme CalendarPro -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` succeeded.
- UI execution for the 2027 calendar case is still pending; see Remaining Risks.

## Remaining Risks

- The current feed is not published. The working-tree feed changes must be committed, pushed, and merged before an installed app can download 2027 data from the default manifest URL.
- The GitHub workflow has not executed remotely because no commit or push was performed. Its first scheduled or manual run must be observed, and the repository must allow GitHub Actions to create pull requests.
- The new background refresh, cache fallback, and settings-status behavior requires a new application release; feed-only updates cannot deliver client code changes.
- The 2027 UI test at `CalendarProUITests/CalendarPopoverUITests.swift` has not passed in this environment. The test runner launched, but the injected UI-test environment did not reach the app process reliably. Before release, manually verify February 2027 shows Spring Festival on February 6 and the adjustment workday on February 14.
- The synchronizer automates mainland China only. Hong Kong, US, and UK data remain manually maintained.
