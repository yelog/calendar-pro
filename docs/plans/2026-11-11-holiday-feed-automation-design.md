# Holiday Feed Automation Design

**Goal:** Make statutory-holiday data arrive without an app release, refresh reliably while CalendarPro stays running, and expose missing or failed data honestly.

**Architecture:** Keep the existing bundled JSON + remote manifest + application-support cache architecture. Generate the same payload schema from the official holiday-cn mirror in CI, propose incremental feed updates through a pull request, and let the client validate and commit payloads before replacing cached data.

**Tech Stack:** Swift 6, URLSession, XCTest, Python 3 standard library, GitHub Actions.

---

## Task 1: Add the 2027 statutory holiday payload

**Files:**
- Create: `feed/holidays/mainland-cn-2027.json`
- Create: `CalendarPro/Resources/Holidays/mainland-cn/mainland-cn-2027.json`
- Modify: `feed/holidays/manifest.json`

Map `isOffDay=true` to `statutoryHoliday` / `statutory-holidays`; map `isOffDay=false` to `workingAdjustmentDay` / `adjustment-workdays` and append `调休上班` to the name. Verify 29 off days and 5 adjustment workdays against the State Council notice.

## Task 2: Add a repeatable feed synchronizer

**Files:**
- Create: `tools/sync_holidays.py`
- Create: `tools/tests/test_sync_holidays.py`
- Create: `.github/workflows/sync-holidays.yml`

The synchronizer fetches `NateScarlet/holiday-cn`, validates dates and source papers, converts records into CalendarPro's schema, updates only changed files atomically, mirrors mainland payloads into app resources, and rebuilds the manifest from feed files. It also:

- version every content change with a monotonic `YYYY.MM.DD.HHMMSS` China-time value so same-day revisions are distinguishable;
- split cross-year notices by actual calendar date, while omitting source-year metadata for records that belong to the schedule year;
- refuse to create a target-year payload from an adjacent year's records alone, and fail closed on conflicting records from two schedule years;
- remain a no-op when a second run produces identical payload content.

The workflow runs daily, creates or updates a dedicated pull request, and opens no pull request when nothing changed. Repository settings must allow GitHub Actions to create pull requests.

## Task 3: Make feed refresh transactional and incremental

**Files:**
- Modify: `CalendarPro/Infrastructure/Data/HolidayFeedClient.swift`
- Modify: `CalendarProTests/Data/HolidayFeedClientTests.swift`

Download and decode every payload before saving any of them. Commit a complete snapshot through a staging directory and atomically switch the active pointer. If the complete manifest and payload list match the cache, only record the successful check time. Preserve the last known good cache on any network or decoding failure and carry the failure reason in the result.

## Task 4: Refresh while the app remains running

**Files:**
- Modify: `CalendarPro/Infrastructure/Data/HolidayFeedClient.swift`
- Modify: `CalendarPro/App/AppDelegate.swift`

Add a main-actor scheduler with one in-flight refresh, startup/activation/wake checks, and a one-shot timer aligned to the cached manifest's expiry. A failed attempt, or a stale cache timestamp that could not be updated, reschedules after the full interval to avoid retry loops. Publish the latest success or failure so the settings page reflects background refreshes even when they did not change any payload.

## Task 5: Expose data availability

**Files:**
- Modify: `CalendarPro/Features/Holidays/HolidayProvider.swift`
- Modify: `CalendarPro/Features/Holidays/MainlandCNProvider.swift`
- Modify: `CalendarPro/Features/Holidays/HongKongProvider.swift`
- Modify: `CalendarPro/Features/Holidays/UnitedStatesProvider.swift`
- Modify: `CalendarPro/Features/Holidays/UnitedKingdomProvider.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Modify: `CalendarPro/Views/Popover/VacationGuideWindowView.swift`

Distinguish cache, bundled, missing, and invalid datasets. Missing future-year mainland data must show a neutral “not synced” note instead of claiming the government has not published it. Cache read failures fall back to bundled data. Mainland records must also use the holiday-set ID that matches their kind. Malformed JSON must not destroy the whole calendar render.

## Task 6: Verify and document

**Files:**
- Modify: `CalendarProTests/Holidays/MainlandCNProviderTests.swift`
- Modify: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`
- Modify: `CalendarProTests/VacationPlanning/VacationPlanningServiceTests.swift`
- Modify: `README.md`
- Modify: `docs/release-checklist.md`
- Create: `docs/plans/2026-11-11-holiday-feed-automation-implementation.md`

Run Python unit tests, focused XCTest suites, then the full macOS test suite if the focused suites pass.
