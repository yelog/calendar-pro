# Calendar Pro Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first shippable version of Calendar Pro as a native macOS menu bar utility with configurable menu bar display, month popover, lunar support, and regional holiday overlays.

**Architecture:** Use an AppKit menu bar shell (`NSStatusItem` + `NSPopover`) with SwiftUI views for the popover and settings. Keep calendar, lunar, and holiday logic in testable domain services, backed by bundled JSON plus optional remote holiday feed refresh.

**Tech Stack:** Swift, SwiftUI, AppKit, XCTest, Foundation Calendar/Locale APIs, local JSON resources

---

### Task 1: Scaffold the macOS app shell

**Files:**
- Create: `CalendarPro.xcodeproj`
- Create: `CalendarPro/CalendarProApp.swift`
- Create: `CalendarPro/App/AppDelegate.swift`
- Create: `CalendarPro/App/StatusBarController.swift`
- Create: `CalendarPro/App/PopoverController.swift`
- Create: `CalendarPro/Views/RootPopoverView.swift`
- Create: `CalendarProTests/CalendarProTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import CalendarPro

final class CalendarProTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertNotNil(Bundle.main.bundleIdentifier)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS'`
Expected: FAIL because the Xcode project and target do not exist yet.

**Step 3: Write minimal implementation**

Create the Xcode app target, wire a SwiftUI app entry point, and add an app delegate that creates the status item and popover controller.

```swift
@main
struct CalendarProApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings placeholder")
                .frame(width: 480, height: 320)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS'`
Expected: PASS for the smoke test target.

**Step 5: Commit**

```bash
git add CalendarPro.xcodeproj CalendarPro CalendarProTests
git commit -m "chore: scaffold macos menu bar app shell"
```

### Task 2: Add persisted settings models

**Files:**
- Create: `CalendarPro/Settings/MenuBarPreferences.swift`
- Create: `CalendarPro/Settings/SettingsStore.swift`
- Create: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: Write the failing test**

```swift
func testDefaultMenuBarPreferencesEnableDateTimeAndWeekday() {
    let store = SettingsStore(userDefaults: UserDefaults(suiteName: #function)!)
    let preferences = store.menuBarPreferences

    XCTAssertTrue(preferences.tokens.contains { $0.token == .date && $0.isEnabled })
    XCTAssertTrue(preferences.tokens.contains { $0.token == .time && $0.isEnabled })
    XCTAssertTrue(preferences.tokens.contains { $0.token == .weekday && $0.isEnabled })
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests`
Expected: FAIL because `SettingsStore` does not exist.

**Step 3: Write minimal implementation**

Define preference models and load/save them through `UserDefaults`.

```swift
enum DisplayTokenKind: String, Codable {
    case date
    case time
    case weekday
    case lunar
    case holiday
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Settings CalendarProTests/Settings
git commit -m "feat: add persisted menu bar preferences"
```

### Task 3: Implement menu bar text rendering

**Files:**
- Create: `CalendarPro/Features/MenuBar/ClockRenderService.swift`
- Create: `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- Modify: `CalendarPro/App/StatusBarController.swift`
- Create: `CalendarProTests/MenuBar/ClockRenderServiceTests.swift`

**Step 1: Write the failing test**

```swift
func testRendererRespectsTokenOrderAndShortStyles() {
    let renderer = ClockRenderService()
    let text = renderer.render(
        now: Date(timeIntervalSince1970: 0),
        preferences: .previewShort
    )

    XCTAssertEqual(text, "00:00 Thu 01/01")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests`
Expected: FAIL because the renderer is missing.

**Step 3: Write minimal implementation**

Implement a renderer that:

- sorts enabled tokens by order
- formats date/time through locale-aware APIs
- joins segments with the configured separator

```swift
func render(now: Date, preferences: MenuBarPreferences) -> String {
    preferences.tokens
        .filter(\.isEnabled)
        .sorted { $0.order < $1.order }
        .map { renderToken($0, now: now) }
        .joined(separator: preferences.separator)
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/ClockRenderServiceTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/MenuBar CalendarPro/App/StatusBarController.swift CalendarProTests/MenuBar
git commit -m "feat: render configurable menu bar clock text"
```

### Task 4: Implement month grid generation

**Files:**
- Create: `CalendarPro/Features/Calendar/CalendarDay.swift`
- Create: `CalendarPro/Features/Calendar/MonthCalendarService.swift`
- Create: `CalendarProTests/Calendar/MonthCalendarServiceTests.swift`

**Step 1: Write the failing test**

```swift
func testMonthGridReturnsFortyTwoCells() {
    let service = MonthCalendarService(calendar: .gregorianMondayFirst)
    let cells = service.makeMonthGrid(for: DateComponents(calendar: .current, year: 2026, month: 3, day: 1).date!)

    XCTAssertEqual(cells.count, 42)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MonthCalendarServiceTests`
Expected: FAIL because the service is missing.

**Step 3: Write minimal implementation**

Generate a normalized 6x7 grid starting from the configured first weekday.

```swift
func makeMonthGrid(for month: Date) -> [CalendarDay] {
    // Build leading spillover, current month cells, and trailing spillover.
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MonthCalendarServiceTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/Calendar CalendarProTests/Calendar
git commit -m "feat: add month calendar grid generation"
```

### Task 5: Add lunar conversion and festival mapping

**Files:**
- Create: `CalendarPro/Features/Lunar/LunarDateDescriptor.swift`
- Create: `CalendarPro/Features/Lunar/LunarService.swift`
- Create: `CalendarPro/Features/Lunar/TraditionalFestivalResolver.swift`
- Create: `CalendarProTests/Lunar/LunarServiceTests.swift`

**Step 1: Write the failing test**

```swift
func testLunarServiceResolvesMidAutumnFestival() {
    let service = LunarService()
    let result = service.describe(date: DateComponents(calendar: .gregorian, year: 2026, month: 9, day: 25).date!)

    XCTAssertEqual(result.festivalName, "中秋节")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests`
Expected: FAIL because the lunar service is missing.

**Step 3: Write minimal implementation**

Use Foundation's Chinese calendar to derive lunar month/day text, then map well-known traditional festivals through a local resolver.

```swift
let chineseCalendar = Calendar(identifier: .chinese)
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/LunarServiceTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/Lunar CalendarProTests/Lunar
git commit -m "feat: add lunar conversion and festival mapping"
```

### Task 6: Add holiday provider contracts and mainland data

**Files:**
- Create: `CalendarPro/Features/Holidays/HolidayOccurrence.swift`
- Create: `CalendarPro/Features/Holidays/HolidayProvider.swift`
- Create: `CalendarPro/Features/Holidays/MainlandCNProvider.swift`
- Create: `CalendarPro/Resources/Holidays/mainland-cn/2026.json`
- Create: `CalendarProTests/Holidays/MainlandCNProviderTests.swift`

**Step 1: Write the failing test**

```swift
func testMainlandProviderMarksSpringFestivalAsStatutoryHoliday() throws {
    let provider = try MainlandCNProvider.makePreview()
    let holidays = try provider.holidays(forYear: 2026)

    XCTAssertTrue(holidays.contains { $0.name == "春节" && $0.kind == .statutoryHoliday })
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MainlandCNProviderTests`
Expected: FAIL because provider and resource files do not exist.

**Step 3: Write minimal implementation**

Define the provider protocol, normalize bundled JSON into `HolidayOccurrence`, and include statutory holiday plus adjustment workday entries for 2026.

```swift
protocol HolidayProvider {
    var descriptor: HolidayProviderDescriptor { get }
    func holidays(forYear year: Int) throws -> [HolidayOccurrence]
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MainlandCNProviderTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/Holidays CalendarPro/Resources/Holidays/mainland-cn CalendarProTests/Holidays
git commit -m "feat: add mainland holiday provider and bundled data"
```

### Task 7: Add Hong Kong provider and provider registry

**Files:**
- Create: `CalendarPro/Features/Holidays/HongKongProvider.swift`
- Create: `CalendarPro/Features/Holidays/HolidayProviderRegistry.swift`
- Create: `CalendarPro/Resources/Holidays/hong-kong/2026.json`
- Create: `CalendarProTests/Holidays/HolidayProviderRegistryTests.swift`

**Step 1: Write the failing test**

```swift
func testRegistryExposesMainlandAndHongKongProviders() {
    let registry = HolidayProviderRegistry.default
    let ids = registry.providers.map(\.descriptor.id)

    XCTAssertTrue(ids.contains("mainland-cn"))
    XCTAssertTrue(ids.contains("hong-kong"))
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/HolidayProviderRegistryTests`
Expected: FAIL because the registry is missing.

**Step 3: Write minimal implementation**

Create a registry that owns built-in providers and exposes provider metadata to settings.

```swift
struct HolidayProviderRegistry {
    let providers: [any HolidayProvider]
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/HolidayProviderRegistryTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/Holidays CalendarPro/Resources/Holidays/hong-kong CalendarProTests/Holidays
git commit -m "feat: add hong kong holiday provider registry"
```

### Task 8: Merge lunar and holiday overlays into day view models

**Files:**
- Create: `CalendarPro/Features/Holidays/HolidayResolver.swift`
- Create: `CalendarPro/Features/Calendar/CalendarDayFactory.swift`
- Create: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Step 1: Write the failing test**

```swift
func testDayFactoryAddsHolidayBadgeAndLunarText() throws {
    let factory = try CalendarDayFactory.makePreview()
    let day = try factory.makeDay(for: DateComponents(calendar: .gregorian, year: 2026, month: 2, day: 17).date!)

    XCTAssertNotNil(day.lunarText)
    XCTAssertFalse(day.badges.isEmpty)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: FAIL because the factory is missing.

**Step 3: Write minimal implementation**

Combine:

- month grid dates
- lunar descriptions
- resolved holiday and adjustment badges

into a single `CalendarDay` output model.

```swift
func makeDay(for date: Date) throws -> CalendarDay {
    // Merge solar, lunar, and holiday display data.
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarDayFactoryTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Features/Holidays/HolidayResolver.swift CalendarPro/Features/Calendar/CalendarDayFactory.swift CalendarProTests/Calendar
git commit -m "feat: merge lunar and holiday day overlays"
```

### Task 9: Build the popover UI

**Files:**
- Create: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Create: `CalendarPro/Views/Popover/MonthHeaderView.swift`
- Create: `CalendarPro/Views/Popover/CalendarGridView.swift`
- Modify: `CalendarPro/Views/RootPopoverView.swift`
- Create: `CalendarProUITests/CalendarProUITests.swift`

**Step 1: Write the failing test**

```swift
func testPopoverRendersMonthNavigation() {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["Next Month"].exists)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProUITests`
Expected: FAIL because the popover UI and accessibility labels are missing.

**Step 3: Write minimal implementation**

Create the month header, weekday row, and day grid in SwiftUI. Add stable accessibility identifiers for navigation controls.

```swift
Button("Next Month") {
    viewModel.showNextMonth()
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProUITests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Views CalendarProUITests
git commit -m "feat: build calendar popover interface"
```

### Task 10: Build the settings UI

**Files:**
- Create: `CalendarPro/Views/Settings/GeneralSettingsView.swift`
- Create: `CalendarPro/Views/Settings/MenuBarSettingsView.swift`
- Create: `CalendarPro/Views/Settings/RegionSettingsView.swift`
- Modify: `CalendarPro/CalendarProApp.swift`
- Create: `CalendarProTests/Settings/RegionSettingsViewModelTests.swift`

**Step 1: Write the failing test**

```swift
func testRegionSettingsReflectsEnabledProviders() {
    let viewModel = RegionSettingsViewModel.preview
    XCTAssertTrue(viewModel.availableRegions.contains { $0.id == "mainland-cn" })
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/RegionSettingsViewModelTests`
Expected: FAIL because the settings models and views are incomplete.

**Step 3: Write minimal implementation**

Add settings tabs that expose:

- token order and visibility
- short/full styles
- region enablement
- holiday checkbox selection
- manual data refresh

```swift
TabView {
    MenuBarSettingsView(viewModel: menuBarViewModel)
        .tabItem { Text("Menu Bar") }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/RegionSettingsViewModelTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Views/Settings CalendarPro/CalendarProApp.swift CalendarProTests/Settings
git commit -m "feat: add settings for menu bar and regions"
```

### Task 11: Add remote holiday feed refresh

**Files:**
- Create: `CalendarPro/Infrastructure/Data/HolidayFeedClient.swift`
- Create: `CalendarPro/Infrastructure/Data/HolidayCacheStore.swift`
- Create: `CalendarPro/Infrastructure/Data/HolidayFeedManifest.swift`
- Create: `CalendarProTests/Data/HolidayFeedClientTests.swift`

**Step 1: Write the failing test**

```swift
func testFeedClientPrefersCachedDataWhenRemoteFetchFails() async throws {
    let client = HolidayFeedClient(session: .failingMock, cache: .preview)
    let result = try await client.refreshIfNeeded()

    XCTAssertEqual(result.source, .cache)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/HolidayFeedClientTests`
Expected: FAIL because the feed client is missing.

**Step 3: Write minimal implementation**

Implement manifest download, local cache persistence, and fallback to last known good data.

```swift
func refreshIfNeeded() async throws -> RefreshResult {
    // Attempt remote fetch, then fall back to cache.
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/HolidayFeedClientTests`
Expected: PASS.

**Step 5: Commit**

```bash
git add CalendarPro/Infrastructure/Data CalendarProTests/Data
git commit -m "feat: add holiday feed refresh and cache fallback"
```

### Task 12: Polish behavior and ship checklist

**Files:**
- Modify: `CalendarPro/App/StatusBarController.swift`
- Modify: `CalendarPro/Features/MenuBar/MenuBarViewModel.swift`
- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`
- Create: `docs/release-checklist.md`

**Step 1: Write the failing test**

```swift
func testMenuBarSchedulerUsesMinuteGranularityByDefault() {
    let viewModel = MenuBarViewModel(preferences: .default)
    XCTAssertEqual(viewModel.refreshGranularity, .minute)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarViewModelTests`
Expected: FAIL because the scheduler behavior is incomplete.

**Step 3: Write minimal implementation**

Complete:

- minute vs second refresh control
- locale and time zone change observers
- basic release checklist for data validation and smoke testing

```swift
if preferences.showSeconds {
    refreshGranularity = .second
} else {
    refreshGranularity = .minute
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CalendarPro -destination 'platform=macOS'`
Expected: PASS for all unit and UI tests.

**Step 5: Commit**

```bash
git add CalendarPro docs/release-checklist.md
git commit -m "chore: polish refresh behavior and release checklist"
```
