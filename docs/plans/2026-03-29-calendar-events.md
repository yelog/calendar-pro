# 日程列表功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在日历 Popover 中添加日程列表功能，显示 Apple Calendar 日程，支持设置开关

**Architecture:** 使用 EventKit 获取系统日历数据，在 CalendarPopoverView 中添加日期选中状态和日程列表视图，通过 SettingsStore 管理日程显示配置

**Tech Stack:** SwiftUI, EventKit, Combine

---

### Task 1: 添加 EventKit 权限配置

**Files:**

- Modify: `CalendarPro/Info.plist`

**Step 1: 添加权限描述**

在 Info.plist 中添加日历访问权限描述：

```xml
<key>NSCalendarsUsageDescription</key>
<string>用于显示您的日历日程</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>用于显示您的日历日程详情</string>
```

**Step 2: 验证配置**

打开 Xcode 项目，确认 Info.plist 中权限描述已添加。

**Step 3: Commit**

```bash
git add CalendarPro/Info.plist
git commit -m "feat: add EventKit permission descriptions"
```

---

### Task 2: 扩展 MenuBarPreferences 配置模型

**Files:**

- Modify: `CalendarPro/Settings/MenuBarPreferences.swift:34-59`
- Test: `CalendarProTests/Settings/MenuBarPreferencesTests.swift` (新建)

**Step 1: 写测试**

创建 `CalendarProTests/Settings/MenuBarPreferencesTests.swift`：

```swift
import XCTest
@testable import CalendarPro

final class MenuBarPreferencesTests: XCTestCase {
    func testDefaultShowEventsIsTrue() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.showEvents)
    }

    func testDefaultEnabledCalendarIDsIsEmpty() {
        let prefs = MenuBarPreferences.default
        XCTAssertTrue(prefs.enabledCalendarIDs.isEmpty)
    }

    func testCodableRoundTrip() throws {
        let prefs = MenuBarPreferences.default
        let data = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(MenuBarPreferences.self, from: data)
        XCTAssertEqual(prefs.showEvents, decoded.showEvents)
        XCTAssertEqual(prefs.enabledCalendarIDs, decoded.enabledCalendarIDs)
    }
}
```

**Step 2: 运行测试确认失败**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests
```

Expected: FAIL - MenuBarPreferences 缺少 showEvents 字段

**Step 3: 添加配置字段**

修改 `MenuBarPreferences.swift`，在结构体中添加：

```swift
struct MenuBarPreferences: Codable, Equatable {
    var tokens: [DisplayTokenPreference]
    var separator: String
    var showLunarInMenuBar: Bool
    var activeRegionIDs: [String]
    var enabledHolidayIDs: [String]
    var weekStart: WeekStart

    // 新增日程配置
    var showEvents: Bool
    var enabledCalendarIDs: [String]

    // ... existing code ...

    static let `default` = MenuBarPreferences(
        tokens: [
            DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .time, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 2, style: .short),
            DisplayTokenPreference(token: .lunar, isEnabled: false, order: 3, style: .short),
            DisplayTokenPreference(token: .holiday, isEnabled: false, order: 4, style: .short)
        ],
        separator: " ",
        showLunarInMenuBar: false,
        activeRegionIDs: ["mainland-cn"],
        enabledHolidayIDs: [],
        weekStart: .monday,
        showEvents: true,
        enabledCalendarIDs: []
    )
}
```

**Step 4: 运行测试确认通过**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/MenuBarPreferencesTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Settings/MenuBarPreferences.swift CalendarProTests/Settings/MenuBarPreferencesTests.swift
git commit -m "feat: add showEvents and enabledCalendarIDs to MenuBarPreferences"
```

---

### Task 3: 扩展 SettingsStore 添加日程配置方法

**Files:**

- Modify: `CalendarPro/Settings/SettingsStore.swift`
- Test: `CalendarProTests/Settings/SettingsStoreTests.swift`

**Step 1: 写测试**

在 `SettingsStoreTests.swift` 添加：

```swift
func testSetShowEvents() {
    let store = SettingsStore(userDefaults: testUserDefaults)
    store.setShowEvents(false)
    XCTAssertFalse(store.menuBarPreferences.showEvents)

    store.setShowEvents(true)
    XCTAssertTrue(store.menuBarPreferences.showEvents)
}

func testSetCalendarEnabled() {
    let store = SettingsStore(userDefaults: testUserDefaults)
    store.setCalendarEnabled(true, calendarID: "calendar-1")
    XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))

    store.setCalendarEnabled(false, calendarID: "calendar-1")
    XCTAssertFalse(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))
}
```

**Step 2: 运行测试确认失败**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests
```

Expected: FAIL - 方法不存在

**Step 3: 实现方法**

在 `SettingsStore.swift` 添加：

```swift
func setShowEvents(_ show: Bool) {
    menuBarPreferences.showEvents = show
}

func setCalendarEnabled(_ enabled: Bool, calendarID: String) {
    var ids = menuBarPreferences.enabledCalendarIDs
    if enabled {
        if !ids.contains(calendarID) {
            ids.append(calendarID)
        }
    } else {
        ids.removeAll { $0 == calendarID }
    }
    menuBarPreferences.enabledCalendarIDs = ids
}
```

**Step 4: 运行测试确认通过**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/SettingsStoreTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Settings/SettingsStore.swift CalendarProTests/Settings/SettingsStoreTests.swift
git commit -m "feat: add event settings methods to SettingsStore"
```

---

### Task 4: 创建 EventService

**Files:**

- Create: `CalendarPro/Features/Events/EventService.swift`
- Test: `CalendarProTests/Events/EventServiceTests.swift`

**Step 1: 创建 EventService**

```swift
import EventKit
import Combine

@MainActor
final class EventService: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var calendars: [EKCalendar] = []
    @Published private(set) var isAuthorized: Bool = false

    private let eventStore = EKEventStore()

    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatusForEntityType(.event)
        isAuthorized = authorizationStatus == .fullAccess || authorizationStatus == .writeOnly
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            checkAuthorizationStatus()
            return granted
        } catch {
            checkAuthorizationStatus()
            return false
        }
    }

    func fetchCalendars() {
        guard isAuthorized else { return }
        calendars = eventStore.calendars(for: .event)
    }

    func fetchEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return calendars.first { $0.calendarIdentifier == identifier }
    }
}
```

**Step 2: 创建测试文件骨架**

```swift
import XCTest
@testable import CalendarPro

final class EventServiceTests: XCTestCase {
    func testInitialAuthorizationStatusIsNotDetermined() {
        let service = EventService()
        XCTAssertEqual(service.authorizationStatus, .notDetermined)
    }

    func testIsAuthorizedInitiallyFalse() {
        let service = EventService()
        XCTAssertFalse(service.isAuthorized)
    }
}
```

**Step 3: 运行测试**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/EventServiceTests
```

Expected: PASS（基础测试）

**Step 4: Commit**

```bash
git add CalendarPro/Features/Events/EventService.swift CalendarProTests/Events/EventServiceTests.swift
git commit -m "feat: create EventService for EventKit access"
```

---

### Task 5: 创建日程卡片视图 EventCardView

**Files:**

- Create: `CalendarPro/Views/Popover/EventCardView.swift`

**Step 1: 创建 EventCardView**

```swift
import SwiftUI
import EventKit

struct EventCardView: View {
    let event: EKEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(cgColor: event.calendar.color))
                .frame(width: 6, height: 6)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(timeRangeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(event.title ?? "无标题")
                    .font(.system(size: 13, weight: .regular))
                    .lineLimit(2)

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeRangeText: String {
        if event.isAllDay {
            return "全天"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)

        return "\(start)-\(end)"
    }
}

#Preview {
    let eventStore = EKEventStore()
    let event = EKEvent(eventStore: eventStore)
    event.title = "产品评审会议"
    event.startDate = Date()
    event.endDate = Date().addingTimeInterval(3600)
    event.isAllDay = false

    return EventCardView(event: event)
        .frame(width: 300)
        .padding()
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/Popover/EventCardView.swift
git commit -m "feat: create EventCardView for event display"
```

---

### Task 6: 创建日程列表视图 EventListView

**Files:**

- Create: `CalendarPro/Views/Popover/EventListView.swift`

**Step 1: 创建 EventListView**

```swift
import SwiftUI
import EventKit

struct EventListView: View {
    let events: [EKEvent]
    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            }
            .frame(height: 60)
        } else if events.isEmpty {
            Text("当天无日程")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 6) {
                ForEach(events, id: \.eventIdentifier) { event in
                    EventCardView(event: event)
                }
            }
        }
    }
}

#Preview("有日程") {
    let eventStore = EKEventStore()
    let event1 = EKEvent(eventStore: eventStore)
    event1.title = "产品评审"
    event1.startDate = Date()
    event1.endDate = Date().addingTimeInterval(3600)

    let event2 = EKEvent(eventStore: eventStore)
    event2.title = "团队会议"
    event2.startDate = Date().addingTimeInterval(7200)
    event2.endDate = Date().addingTimeInterval(10800)

    return EventListView(events: [event1, event2], isLoading: false)
        .frame(width: 300)
        .padding()
}

#Preview("无日程") {
    EventListView(events: [], isLoading: false)
        .frame(width: 300)
        .padding()
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/Popover/EventListView.swift
git commit -m "feat: create EventListView for event list display"
```

---

### Task 7: 扩展 CalendarPopoverViewModel 添加日期选中状态

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarPopoverViewModel.swift`
- Test: `CalendarProTests/Popover/CalendarPopoverViewModelTests.swift`

**Step 1: 添加测试**

在 `CalendarPopoverViewModelTests.swift` 添加：

```swift
func testInitialSelectedDateIsNil() {
    let viewModel = CalendarPopoverViewModel()
    XCTAssertNil(viewModel.selectedDate)
}

func testSelectDate() {
    let viewModel = CalendarPopoverViewModel()
    let date = Date()
    viewModel.selectDate(date)
    XCTAssertEqual(viewModel.selectedDate, date)
}

func testClearSelectedDate() {
    let viewModel = CalendarPopoverViewModel()
    viewModel.selectDate(Date())
    viewModel.clearSelectedDate()
    XCTAssertNil(viewModel.selectedDate)
}
```

**Step 2: 运行测试确认失败**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests
```

Expected: FAIL

**Step 3: 实现**

修改 `CalendarPopoverViewModel.swift`：

```swift
@MainActor
final class CalendarPopoverViewModel: ObservableObject {
    @Published private(set) var displayedMonth: Date
    @Published private(set) var selectedDate: Date?

    init(displayedMonth: Date = .now) {
        self.displayedMonth = displayedMonth
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func clearSelectedDate() {
        selectedDate = nil
    }

    // ... existing methods ...
}
```

**Step 4: 运行测试确认通过**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS' -only-testing:CalendarProTests/CalendarPopoverViewModelTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverViewModel.swift CalendarProTests/Popover/CalendarPopoverViewModelTests.swift
git commit -m "feat: add selectedDate state to CalendarPopoverViewModel"
```

---

### Task 8: 修改 CalendarGridView 支持日期点击

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarGridView.swift`
- Modify: `CalendarPro/Views/Popover/CalendarDay.swift` (添加 isSelected)

**Step 1: 扩展 CalendarDay 添加 isSelected**

```swift
struct CalendarDay: Equatable, Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool  // 新增
    let solarText: String
    let lunarText: String?
    let badges: [DayBadge]

    var id: Date { date }
}
```

**Step 2: 修改 CalendarGridView**

```swift
struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let onSelectDate: (Date) -> Void  // 新增回调

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(monthDays) { day in
                    CalendarDayCellView(day: day)
                        .onTapGesture {
                            onSelectDate(day.date)
                        }
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }
}

private struct CalendarDayCellView: View {
    let day: CalendarDay

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 2) {
                Text(day.solarText)
                    .font(.system(size: 13, weight: day.isToday ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(day.isInDisplayedMonth ? Color.primary : Color.secondary.opacity(0.5))

                Text(day.badges.first?.text ?? day.lunarText ?? "")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.vertical, 2)

            // ... badges ...
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(cellBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())  // 确保整个区域可点击
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(dayIdentifier)
    }

    private var cellBackground: some View {
        Group {
            if day.isSelected {
                Color.accentColor.opacity(0.3)  // 选中状态
            } else if day.isToday {
                Color.accentColor.opacity(0.15)
            } else if let badge = day.badges.first {
                // ... existing badge logic ...
            } else {
                Color.clear
            }
        }
    }

    // ... rest of existing code ...
}
```

**Step 3: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarGridView.swift CalendarPro/Features/Calendar/CalendarDay.swift
git commit -m "feat: add date selection interaction to CalendarGridView"
```

---

### Task 9: 修改 CalendarDayFactory 支持 isSelected

**Files:**

- Modify: `CalendarPro/Features/Calendar/CalendarDayFactory.swift`
- Test: `CalendarProTests/Calendar/CalendarDayFactoryTests.swift`

**Step 1: 修改 makeDay 方法**

```swift
func makeDay(
    for date: Date,
    displayedMonth: Date,
    preferences: MenuBarPreferences,
    selectedDate: Date? = nil  // 新增参数
) throws -> CalendarDay {
    // ... existing logic ...

    return CalendarDay(
        date: date,
        isInDisplayedMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
        isToday: calendar.isDate(date, inSameDayAs: now()),
        isSelected: selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!),  // 新增
        solarText: String(calendar.component(.day, from: date)),
        lunarText: lunarText,
        badges: badges
    )
}

func makeMonthGrid(
    for month: Date,
    preferences: MenuBarPreferences,
    selectedDate: Date? = nil  // 新增参数
) throws -> [CalendarDay] {
    // ... use makeDay with selectedDate ...
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Features/Calendar/CalendarDayFactory.swift CalendarProTests/Calendar/CalendarDayFactoryTests.swift
git commit -m "feat: add isSelected support to CalendarDayFactory"
```

---

### Task 10: 集成 EventService 到 RootPopoverView

**Files:**

- Modify: `CalendarPro/Views/RootPopoverView.swift`

**Step 1: 添加 EventService 和日程数据**

```swift
import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var viewModel = CalendarPopoverViewModel()
    @StateObject private var eventService = EventService()  // 新增
    let onQuit: () -> Void

    @State private var eventsForSelectedDate: [EKEvent] = []
    @State private var isLoadingEvents: Bool = false

    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            regionSummary: regionSummary,
            showEvents: settingsStore.menuBarPreferences.showEvents && eventService.isAuthorized,  // 新增
            selectedDate: viewModel.selectedDate,  // 新增
            events: eventsForSelectedDate,  // 新增
            isLoadingEvents: isLoadingEvents,  // 新增
            onPreviousMonth: {
                viewModel.showPreviousMonth(using: displayCalendar)
            },
            onNextMonth: {
                viewModel.showNextMonth(using: displayCalendar)
            },
            onSelectDate: { date in  // 新增
                viewModel.selectDate(date)
                loadEvents(for: date)
            },
            onResetToToday: {
                viewModel.resetToToday()
                viewModel.clearSelectedDate()
            },
            onQuit: onQuit
        )
        .onAppear {
            eventService.checkAuthorizationStatus()
            if settingsStore.menuBarPreferences.showEvents {
                eventService.fetchCalendars()
            }
        }
        .onChange(of: viewModel.selectedDate) { _, newDate in
            if let date = newDate {
                loadEvents(for: date)
            }
        }
    }

    private func loadEvents(for date: Date) {
        guard settingsStore.menuBarPreferences.showEvents else {
            eventsForSelectedDate = []
            return
        }

        isLoadingEvents = true
        Task {
            let events = eventService.fetchEvents(for: date)
            let filtered = filterEventsByEnabledCalendars(events)
            await MainActor.run {
                eventsForSelectedDate = filtered
                isLoadingEvents = false
            }
        }
    }

    private func filterEventsByEnabledCalendars(_ events: [EKEvent]) -> [EKEvent] {
        let enabledIDs = settingsStore.menuBarPreferences.enabledCalendarIDs
        if enabledIDs.isEmpty {
            return events
        }
        return events.filter { enabledIDs.contains($0.calendar.calendarIdentifier) }
    }

    // ... existing computed properties with selectedDate passed to factory ...

    private var monthDays: [CalendarDay] {
        let factory = CalendarDayFactory(calendar: displayCalendar, registry: .live)
        return (try? factory.makeMonthGrid(
            for: viewModel.displayedMonth,
            preferences: settingsStore.menuBarPreferences,
            selectedDate: viewModel.selectedDate
        )) ?? monthService.makeMonthGrid(for: viewModel.displayedMonth)
    }
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/RootPopoverView.swift
git commit -m "feat: integrate EventService into RootPopoverView"
```

---

### Task 11: 修改 CalendarPopoverView 集成日程列表

**Files:**

- Modify: `CalendarPro/Views/Popover/CalendarPopoverView.swift`

**Step 1: 修改视图结构**

```swift
import SwiftUI
import EventKit

struct CalendarPopoverView: View {
    let displayedMonth: Date
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let regionSummary: String
    let showEvents: Bool
    let selectedDate: Date?
    let events: [EKEvent]
    let isLoadingEvents: Bool
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectDate: (Date) -> Void
    let onResetToToday: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthHeaderView(
                displayedMonth: displayedMonth,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth
            )

            CalendarGridView(
                weekdaySymbols: weekdaySymbols,
                monthDays: monthDays,
                onSelectDate: onSelectDate
            )

            // 日程列表区域
            if showEvents, let date = selectedDate {
                Divider()
                    .padding(.horizontal, -16)

                EventListView(events: events, isLoading: isLoadingEvents)
            }

            Text(regionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.horizontal, -16)

            HStack {
                SettingsLink {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)

                Spacer()

                Button(action: onResetToToday) {
                    Label("今日", systemImage: "calendar")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)

                Spacer()

                Button(action: onQuit) {
                    Label("退出", systemImage: "power")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 340, height: dynamicHeight)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var dynamicHeight: CGFloat {
        if showEvents, selectedDate != nil {
            return 540  // 展开时的高度
        }
        return 400  // 默认高度
    }
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/Popover/CalendarPopoverView.swift
git commit -m "feat: integrate EventListView into CalendarPopoverView"
```

---

### Task 12: 创建日程设置视图 EventsSettingsView

**Files:**

- Create: `CalendarPro/Views/Settings/EventsSettingsView.swift`

**Step 1: 创建设置视图**

```swift
import SwiftUI
import EventKit

struct EventsSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var eventService: EventService

    var body: some View {
        GroupBox("日历日程") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("显示日程", isOn: showEventsBinding)
                    .toggleStyle(.checkbox)

                if !eventService.isAuthorized {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("需要日历访问权限")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Button("请求权限") {
                            Task {
                                await eventService.requestAccess()
                                eventService.fetchCalendars()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                if eventService.isAuthorized && store.menuBarPreferences.showEvents {
                    Divider()

                    Text("选择日历")
                        .font(.system(size: 12, weight: .medium))

                    ForEach(eventService.calendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(cgColor: calendar.color))
                                .frame(width: 12, height: 12)

                            Text(calendar.title)
                                .font(.system(size: 12))

                            Spacer()

                            Toggle("", isOn: calendarEnabledBinding(for: calendar.calendarIdentifier))
                                .toggleStyle(.checkbox)
                        }
                    }
                }
            }
        }
    }

    private var showEventsBinding: Binding<Bool> {
        Binding(
            get: { store.menuBarPreferences.showEvents },
            set: { store.setShowEvents($0) }
        )
    }

    private func calendarEnabledBinding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: {
                let enabledIDs = store.menuBarPreferences.enabledCalendarIDs
                return enabledIDs.isEmpty || enabledIDs.contains(calendarID)
            },
            set: { store.setCalendarEnabled($0, calendarID: calendarID) }
        )
    }
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/Settings/EventsSettingsView.swift
git commit -m "feat: create EventsSettingsView for event settings"
```

---

### Task 13: 集成日程设置到 SettingsRootView

**Files:**

- Modify: `CalendarPro/Views/Settings/SettingsRootView.swift`

**Step 1: 添加 EventService 和 Tab**

```swift
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @StateObject private var regionViewModel: RegionSettingsViewModel
    @StateObject private var eventService = EventService()  // 新增

    init(store: SettingsStore) {
        self.store = store
        _regionViewModel = StateObject(
            wrappedValue: RegionSettingsViewModel(
                store: store,
                registry: .live,
                feedClient: HolidayFeedClient.configuredClient()
            )
        )
    }

    var body: some View {
        TabView {
            GeneralSettingsView(store: store)
                .tabItem { Text("通用") }

            MenuBarSettingsView(store: store)
                .tabItem { Text("菜单栏") }

            EventsSettingsView(store: store, eventService: eventService)  // 新增
                .tabItem { Text("日程") }

            RegionSettingsView(viewModel: regionViewModel)
                .tabItem { Text("地区与节假日") }
        }
        .frame(width: 480, height: 380)  // 高度稍微增加
        .onAppear {
            eventService.checkAuthorizationStatus()
            eventService.fetchCalendars()
        }
    }
}
```

**Step 2: Commit**

```bash
git add CalendarPro/Views/Settings/SettingsRootView.swift
git commit -m "feat: integrate EventsSettingsView into SettingsRootView"
```

---

### Task 14: 整合测试

**Files:**

- 无新增，运行全部测试

**Step 1: 运行完整测试套**

```bash
xcodebuild test -scheme CalendarPro -destination 'platform=macOS'
```

Expected: PASS

**Step 2: 手动测试清单**

1. 打开设置，确认"日程" Tab 存在
2. 关闭"显示日程"开关，确认 Popover 无日程列表
3. 打开"显示日程"，请求权限
4. 授权后，确认日历列表显示
5. 点击日期，确认日程列表展开
6. 关闭单个日历，确认对应日程不显示
7. 点击今日按钮，确认选中状态清除

**Step 3: 最终 Commit**

```bash
git add -A
git commit -m "feat: complete calendar events integration"
```

---

## 完成标志

- [ ] EventKit 权限配置完成
- [ ] MenuBarPreferences 扩展完成
- [ ] SettingsStore 方法添加完成
- [ ] EventService 创建完成
- [ ] EventCardView 创建完成
- [ ] EventListView 创建完成
- [ ] CalendarPopoverViewModel 选中状态完成
- [ ] CalendarGridView 点击交互完成
- [ ] CalendarDayFactory isSelected 支持
- [ ] RootPopoverView 集成完成
- [ ] CalendarPopoverView 集成完成
- [ ] EventsSettingsView 创建完成
- [ ] SettingsRootView 集成完成
- [ ] 全部测试通过
