# Calendar Pro Design

**Date:** 2026-03-29

**Goal:** Build a native macOS enhanced calendar utility focused on a configurable menu bar clock, a month calendar popover, lunar calendar support, and region-aware holiday overlays.

**Assumptions:**
- Default target is modern macOS (`macOS 14+`).
- The app is a menu bar utility first, not a full calendar client.
- V1 must work offline after installation.

---

## 1. Product Scope

### Core User Value

The app should let users glance at time and date from the menu bar, open a compact month calendar, and understand region-specific holidays without launching a full calendar application.

### In Scope for V1

- Configurable menu bar text showing date, time, weekday, optional lunar text, and optional holiday labels
- Month calendar popover opened from the menu bar
- Mainland China support for lunar dates, traditional festivals, statutory holidays, and make-up workdays
- Hong Kong holiday provider
- Region and holiday visibility settings
- Offline baseline data with optional remote data refresh

### Out of Scope for V1

- Apple Calendar event editing or sync
- Reminder/task management
- Global built-in holiday rules for all countries
- Complex reminder automation

---

## 2. Product Requirements Breakdown

### Menu Bar Display

The menu bar text must be driven by composable display tokens instead of a fixed template.

Supported token categories:

- date
- time
- weekday
- lunar text
- holiday label

Per-token configuration:

- enabled/disabled
- display order
- short or full style
- separator style
- optional seconds for time

This design keeps the formatting engine extensible and avoids hard-coded layout branches.

### Calendar Popover

Each day cell should be able to render three information layers:

- solar day number
- lunar text or traditional festival
- holiday or adjustment badge

The popover needs month navigation, today highlight, and consistent layout across locales.

### Regional Holiday Configuration

Regions should not be hard-coded in the view layer. The UI should expose available data providers and let users enable or disable holiday sets within each provider.

Initial providers:

- Mainland China
- Hong Kong
- Custom imported source

---

## 3. Architecture

### Recommended Runtime Structure

Use a hybrid shell:

- AppKit for menu bar shell and popover lifecycle
- SwiftUI for content views and settings

This balances menu bar interaction control with modern UI implementation speed.

### Module Layout

- `AppShell`
  - app entry
  - app delegate
  - status item and popover control
- `Features/MenuBar`
  - text token rendering
  - refresh scheduling
- `Features/Calendar`
  - month grid generation
  - calendar popover state
- `Features/Lunar`
  - lunar conversion and traditional festivals
- `Features/Holidays`
  - holiday provider protocol
  - region registry
  - holiday resolver
- `Settings`
  - persisted preferences
  - settings UI
- `Infrastructure`
  - local JSON loading
  - remote feed refresh
  - cache management

### Why Not Pure SwiftUI

`MenuBarExtra` is attractive for a fast prototype, but this product centers on menu bar interaction. AppKit provides more predictable control over popover behavior, activation, and future customization. SwiftUI remains a strong fit for the actual views.

---

## 4. Data Model

### User Preferences

`MenuBarPreferences`

- `tokens: [DisplayTokenPreference]`
- `showSeconds: Bool`
- `showLunarInMenuBar: Bool`
- `activeRegionIDs: [String]`
- `enabledHolidayIDs: [String]`
- `weekStart: Weekday`

`DisplayTokenPreference`

- `token: DisplayTokenKind`
- `isEnabled: Bool`
- `order: Int`
- `style: DisplayTokenStyle`

### Calendar Domain

`CalendarDay`

- `date: Date`
- `isInDisplayedMonth: Bool`
- `isToday: Bool`
- `solarText: String`
- `lunarText: String?`
- `badges: [DayBadge]`

`DayBadge`

- `kind: BadgeKind`
- `text: String`
- `priority: Int`

### Holiday Domain

`HolidayOccurrence`

- `id: String`
- `regionID: String`
- `date: Date`
- `name: String`
- `kind: HolidayKind`
- `isObserved: Bool`
- `isAdjustmentWorkday: Bool`
- `source: HolidaySource`

`HolidayKind`

- `festival`
- `publicHoliday`
- `statutoryHoliday`
- `workingAdjustmentDay`

### Provider Metadata

`HolidayProviderDescriptor`

- `id: String`
- `displayName: String`
- `supportsOfflineData: Bool`
- `supportsRemoteRefresh: Bool`
- `availableHolidaySets: [HolidaySet]`

---

## 5. Holiday Data Strategy

### Mainland China

Use bundled yearly JSON files as the offline baseline. Refresh newer yearly files through a remote signed static JSON feed. The official annual notice is the legal source of truth, but the application should not depend on live page parsing.

Data buckets:

- statutory holidays
- adjustment workdays
- traditional festivals

Traditional festivals can be calculated locally and stored as derived display data, while statutory holidays and make-up workdays should be curated from official notices.

### Hong Kong

Use official structured datasets as the primary source. Cache normalized results locally for offline use.

### Overseas Expansion

Do not ship a full global rules engine in V1. Expand through:

- additional official region providers
- user-imported ICS
- custom JSON providers for advanced users

---

## 6. Refresh and Sync Strategy

### Time Refresh

Use a scheduler that aligns updates to the displayed granularity:

- minute-level refresh when seconds are hidden
- second-level refresh only when explicitly enabled

This avoids unnecessary CPU work and reduces menu bar width jitter risk.

### Data Refresh

Refresh holiday feeds on:

- first launch after install
- manual refresh in settings
- occasional background refresh when app is active

Failure handling:

- keep last known good cache
- surface data freshness in settings
- never block core calendar rendering on network failure

---

## 7. UI Structure

### Menu Bar

The menu bar should display a single attributed string or compact text sequence assembled from enabled tokens.

Examples:

- `03/29 Sun 20:13`
- `20:13 Sun`
- `03/29 Sun 初一`

### Popover

Sections inside the popover:

- top bar with current month and navigation
- weekday header row
- month grid
- optional footer with selected date details

### Settings

Suggested tabs:

- General
- Menu Bar
- Calendar
- Regions & Holidays
- Data

---

## 8. Testing Strategy

Priority test areas:

- month grid generation across month boundaries
- lunar conversion including leap months
- holiday overlay merge order
- adjustment workday rendering
- locale and time zone change reactions
- menu bar formatting permutations

Testing layers:

- unit tests for domain services
- UI tests for key settings flows
- snapshot or screenshot regression tests for popover layout if adopted later

---

## 9. Risks and Mitigations

- Lunar leap month logic can introduce subtle date bugs.
  - Mitigation: broad year-range test coverage and fixture validation.
- Menu bar width can jump when text length changes.
  - Mitigation: discourage seconds by default and keep styles compact.
- Mainland holiday data can change yearly and lacks a stable official API.
  - Mitigation: curated yearly JSON plus remote feed updates.
- Region semantics differ.
  - Mitigation: separate `festival`, `holiday`, and `adjustment` concepts in the model.

---

## 10. Delivery Recommendation

Ship V1 as a tightly scoped menu bar utility with strong regional holiday support and a reliable offline experience. Delay calendar event sync until the date, holiday, and region systems are stable.

---

## References

- Apple Developer Documentation: MenuBarExtra
- Apple Developer Documentation: NSStatusBar
- Apple Developer Documentation: Calendar.Identifier.chinese
- Apple Internationalization Guide: Formatting Data Using the Locale Settings
- State Council official 2026 holiday notice
- Hong Kong 1823 public holiday data
