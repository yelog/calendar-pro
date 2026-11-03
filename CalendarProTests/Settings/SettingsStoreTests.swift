import XCTest
@testable import CalendarPro

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testUTCOffsetTextSupportsZeroPositiveNegativeAndFractionalHours() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let cases: [(Int, String)] = [
            (0, "UTC+0:00"),
            (8 * 3600, "UTC+8:00"),
            (-8 * 3600, "UTC-8:00"),
            (5 * 3600 + 30 * 60, "UTC+5:30"),
            (5 * 3600 + 45 * 60, "UTC+5:45"),
            (-(3 * 3600 + 30 * 60), "UTC-3:30"),
            (14 * 3600, "UTC+14:00")
        ]

        for (seconds, expected) in cases {
            let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: seconds))
            XCTAssertEqual(AppTimeZoneCatalog.utcOffsetText(for: timeZone, at: date), expected)
        }
    }

    func testUTCOffsetTextUsesDaylightSavingRulesForTheRequestedDate() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))

        XCTAssertEqual(AppTimeZoneCatalog.utcOffsetText(for: timeZone, at: winter), "UTC-5:00")
        XCTAssertEqual(AppTimeZoneCatalog.utcOffsetText(for: timeZone, at: summer), "UTC-4:00")
    }

    func testTimeZoneDefaultsToFollowingSystem() {
        let store = makeStore(userDefaults: makeIsolatedUserDefaults())

        XCTAssertNil(store.timeZoneIdentifier)
        XCTAssertEqual(store.effectiveTimeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
        XCTAssertEqual(store.displayCalendar.identifier, .gregorian)
        XCTAssertEqual(store.displayCalendar.timeZone.identifier, store.effectiveTimeZone.identifier)
    }

    func testTimeZonePersistsIndependentlyOfOtherPreferences() throws {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setWeekStart(.sunday)
        store.setSeparator(" · ")
        store.setAppLanguage(.english)
        store.setPomodoroEnabled(true)
        let menuBarData = try XCTUnwrap(userDefaults.data(forKey: "menuBarPreferences"))
        let pomodoroData = try XCTUnwrap(userDefaults.data(forKey: "pomodoroPreferences"))

        store.setTimeZoneIdentifier("America/Los_Angeles")

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.timeZoneIdentifier, "America/Los_Angeles")
        XCTAssertEqual(reloaded.effectiveTimeZone.identifier, "America/Los_Angeles")
        XCTAssertEqual(reloaded.displayCalendar.firstWeekday, 1)
        XCTAssertEqual(reloaded.menuBarPreferences.separator, " · ")
        XCTAssertEqual(reloaded.appLanguage, .english)
        XCTAssertTrue(reloaded.pomodoroPreferences.isEnabled)
        XCTAssertEqual(userDefaults.data(forKey: "menuBarPreferences"), menuBarData)
        XCTAssertEqual(userDefaults.data(forKey: "pomodoroPreferences"), pomodoroData)
    }

    func testFollowingSystemRemovesOnlyTheTimeZoneOverride() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setSeparator(" | ")
        store.setTimeZoneIdentifier("Asia/Shanghai")

        store.setTimeZoneIdentifier(nil)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertNil(reloaded.timeZoneIdentifier)
        XCTAssertNil(userDefaults.object(forKey: "appTimeZoneIdentifier"))
        XCTAssertEqual(reloaded.menuBarPreferences.separator, " | ")
    }

    func testInvalidStoredTimeZoneFallsBackWithoutResettingPreferences() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setWeekStart(.sunday)
        userDefaults.set("Invalid/Time_Zone", forKey: "appTimeZoneIdentifier")

        let reloaded = makeStore(userDefaults: userDefaults)

        XCTAssertNil(reloaded.timeZoneIdentifier)
        XCTAssertEqual(reloaded.effectiveTimeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
        XCTAssertEqual(reloaded.displayCalendar.firstWeekday, 1)
        XCTAssertEqual(userDefaults.string(forKey: "appTimeZoneIdentifier"), "Invalid/Time_Zone")
    }

    func testInvalidTimeZoneInputFallsBackToSystemAndDoesNotPersistInvalidValues() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setTimeZoneIdentifier("Asia/Shanghai")

        for identifier in ["Invalid/Time_Zone", "", "  Asia/Shanghai  "] {
            store.setTimeZoneIdentifier(identifier)

            XCTAssertNil(store.timeZoneIdentifier)
            XCTAssertNil(userDefaults.object(forKey: "appTimeZoneIdentifier"))
            XCTAssertEqual(store.effectiveTimeZone.identifier, TimeZone.autoupdatingCurrent.identifier)
        }
    }

    func testDisplayCalendarPreservesWeekStartWhenTimeZoneChanges() {
        let store = makeStore(userDefaults: makeIsolatedUserDefaults())
        store.setWeekStart(.monday)
        store.setTimeZoneIdentifier("Asia/Shanghai")

        XCTAssertEqual(store.displayCalendar.firstWeekday, 2)
        XCTAssertEqual(store.displayCalendar.timeZone.identifier, "Asia/Shanghai")

        store.setTimeZoneIdentifier("America/Los_Angeles")
        XCTAssertEqual(store.displayCalendar.firstWeekday, 2)
        XCTAssertEqual(store.displayCalendar.timeZone.identifier, "America/Los_Angeles")

        store.setWeekStart(.sunday)
        XCTAssertEqual(store.displayCalendar.firstWeekday, 1)
        XCTAssertEqual(store.displayCalendar.timeZone.identifier, "America/Los_Angeles")
    }

    func testSettingsTimeContextRendersTheSameInstantOnDifferentCalendarYears() throws {
        let store = makeStore(userDefaults: makeIsolatedUserDefaults())
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-12-31T16:30:00Z"))
        let renderer = ClockRenderService()
        var preferences = store.menuBarPreferences
        preferences.separator = " "
        preferences.tokens = [
            DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
            DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .short),
            DisplayTokenPreference(token: .date, isEnabled: true, order: 2, style: .numeric)
        ]

        store.setTimeZoneIdentifier("Asia/Shanghai")
        XCTAssertEqual(store.displayCalendar.component(.year, from: now), 2027)
        XCTAssertEqual(renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: store.displayCalendar,
            timeZone: store.effectiveTimeZone
        ), "00:30 Fri 01/01")

        store.setTimeZoneIdentifier("America/Los_Angeles")
        XCTAssertEqual(store.displayCalendar.component(.year, from: now), 2026)
        XCTAssertEqual(renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: store.displayCalendar,
            timeZone: store.effectiveTimeZone
        ), "08:30 Thu 31/12")
    }

    func testTimeZoneSearchMatchesIdentifiersCityWordsAndLocalizedNames() {
        let english = Locale(identifier: "en")
        let chinese = Locale(identifier: "zh-Hans")
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "  asia/shanghai  ", locale: english).contains("Asia/Shanghai"))
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "Los Angeles", locale: english).contains("America/Los_Angeles"))
        let localizedName = AppTimeZoneCatalog.localizedName(for: "Asia/Shanghai", locale: chinese)
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: localizedName, locale: chinese).contains("Asia/Shanghai"))
        XCTAssertEqual(AppTimeZoneCatalog.matchingIdentifiers(query: " \n ", locale: english), AppTimeZoneCatalog.identifiers)
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "Invalid/Time_Zone", locale: english).isEmpty)
        XCTAssertEqual(AppTimeZoneCatalog.localizedName(for: "Invalid/Time_Zone", locale: english), "Invalid/Time_Zone")
    }

    func testTimeZoneSearchMatchesUTCOffsetsWithAndWithoutPrefix() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let locale = Locale(identifier: "en")
        let matches = AppTimeZoneCatalog.matchingIdentifiers(query: "+8:00", locale: locale, at: date)

        XCTAssertTrue(matches.contains("Asia/Shanghai"))
        XCTAssertTrue(matches.contains("Asia/Singapore"))
        XCTAssertFalse(matches.contains("Asia/Tokyo"))
        XCTAssertFalse(matches.contains("Australia/Eucla"))
        XCTAssertFalse(matches.contains("Etc/GMT+8"))
        for identifier in matches {
            let timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
            XCTAssertEqual(timeZone.secondsFromGMT(for: date), 8 * 3600, identifier)
        }
        for query in ["UTC+8:00", " utc+8:00 "] {
            XCTAssertEqual(AppTimeZoneCatalog.matchingIdentifiers(query: query, locale: locale, at: date), matches)
        }
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "+25:00", locale: locale, at: date).isEmpty)
    }

    func testTimeZoneSearchMatchesFractionalNegativeAndZeroOffsets() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let locale = Locale(identifier: "zh-Hans")
        let cases = [
            ("+5:30", "Asia/Calcutta", 5 * 3600 + 30 * 60),
            ("+5:45", "Asia/Kathmandu", 5 * 3600 + 45 * 60),
            ("-3:30", "America/St_Johns", -(3 * 3600 + 30 * 60)),
            ("UTC+0:00", "UTC", 0)
        ]

        for (query, expectedIdentifier, expectedSeconds) in cases {
            let matches = AppTimeZoneCatalog.matchingIdentifiers(query: query, locale: locale, at: date)
            XCTAssertTrue(matches.contains(expectedIdentifier), query)
            for identifier in matches {
                let timeZone = try XCTUnwrap(TimeZone(identifier: identifier))
                XCTAssertEqual(timeZone.secondsFromGMT(for: date), expectedSeconds, identifier)
            }
        }
    }

    func testTimeZoneOffsetSearchFollowsDaylightSavingChanges() throws {
        let locale = Locale(identifier: "en")
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))

        XCTAssertFalse(AppTimeZoneCatalog.matchingIdentifiers(query: "-4:00", locale: locale, at: winter).contains("America/New_York"))
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "-4:00", locale: locale, at: summer).contains("America/New_York"))
        XCTAssertTrue(AppTimeZoneCatalog.matchingIdentifiers(query: "-5:00", locale: locale, at: winter).contains("America/New_York"))
        XCTAssertFalse(AppTimeZoneCatalog.matchingIdentifiers(query: "-5:00", locale: locale, at: summer).contains("America/New_York"))
    }

    func testDefaultMenuBarPreferencesEnableDateTimeAndWeekday() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        let preferences = store.menuBarPreferences

        XCTAssertTrue(preferences.tokens.contains { $0.token == .date && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .time && $0.isEnabled })
        XCTAssertTrue(preferences.tokens.contains { $0.token == .weekday && $0.isEnabled })
    }

    func testSettingsPersistMenuBarPreferences() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setTokenEnabled(false, for: .weekday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.isEnabled ?? true)
    }

    func testMigratesExplicitMainlandHolidaySelectionToIncludeCommemorativeFestivals() throws {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        preferences.enabledHolidayIDs = [
            "statutory-holidays",
            "adjustment-workdays"
        ]
        try userDefaults.setEncodedMenuBarPreferences(preferences)

        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(
            store.menuBarPreferences.enabledHolidayIDs,
            [
                "statutory-holidays",
                "adjustment-workdays",
                MainlandCNProvider.commemorativeFestivalSetID
            ]
        )

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.enabledHolidayIDs, store.menuBarPreferences.enabledHolidayIDs)
    }

    func testMainlandHolidayMigrationPreservesExplicitOptOutWhenAllMainlandSetsWereDisabled() throws {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        var preferences = MenuBarPreferences.default
        preferences.activeRegionIDs = ["mainland-cn"]
        preferences.enabledHolidayIDs = ["public-holidays"]
        try userDefaults.setEncodedMenuBarPreferences(preferences)

        let store = makeStore(userDefaults: userDefaults)

        XCTAssertFalse(store.menuBarPreferences.enabledHolidayIDs.contains(MainlandCNProvider.commemorativeFestivalSetID))
    }

    func testSetShowEvents() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setShowEvents(false)
        XCTAssertFalse(store.menuBarPreferences.showEvents)

        store.setShowEvents(true)
        XCTAssertTrue(store.menuBarPreferences.showEvents)
    }

    func testSetShowCalendarEvents() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setShowCalendarEvents(false)
        XCTAssertFalse(store.menuBarPreferences.showCalendarEvents)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.showCalendarEvents)
    }

    func testSetCalendarEnabled() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setCalendarEnabled(true, calendarID: "calendar-1")
        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))

        store.setCalendarEnabled(false, calendarID: "calendar-1")
        XCTAssertFalse(store.menuBarPreferences.enabledCalendarIDs.contains("calendar-1"))
    }

    func testSetCalendarEnabledDisablesSingleCalendarWhenEmptyMeansAllSelected() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setCalendarEnabled(
            false,
            calendarID: "calendar-2",
            allCalendarIDs: ["calendar-1", "calendar-2", "calendar-3"]
        )

        XCTAssertEqual(store.menuBarPreferences.enabledCalendarIDs, ["calendar-1", "calendar-3"])

        store.setCalendarEnabled(
            true,
            calendarID: "calendar-2",
            allCalendarIDs: ["calendar-1", "calendar-2", "calendar-3"]
        )

        XCTAssertTrue(store.menuBarPreferences.enabledCalendarIDs.isEmpty)
    }

    func testSetShowEventsDoesNotResetEventSourcePreferences() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        var prefs = store.menuBarPreferences
        prefs.showCalendarEvents = false
        prefs.showReminders = false
        prefs.enabledCalendarIDs = ["calendar-1"]
        prefs.enabledReminderCalendarIDs = ["reminder-1"]
        store.menuBarPreferences = prefs

        store.setShowEvents(false)
        store.setShowEvents(true)

        XCTAssertFalse(store.menuBarPreferences.showCalendarEvents)
        XCTAssertFalse(store.menuBarPreferences.showReminders)
        XCTAssertEqual(store.menuBarPreferences.enabledCalendarIDs, ["calendar-1"])
        XCTAssertEqual(store.menuBarPreferences.enabledReminderCalendarIDs, ["reminder-1"])
    }

    func testSetReminderCalendarEnabledDisablesSingleReminderListWhenEmptyMeansAllSelected() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setReminderCalendarEnabled(
            false,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertEqual(store.menuBarPreferences.enabledReminderCalendarIDs, ["reminder-1"])

        store.setReminderCalendarEnabled(
            true,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertTrue(store.menuBarPreferences.enabledReminderCalendarIDs.isEmpty)
    }

    func testEventListModePersistsAndRestoresWhenViewIsReenabled() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)
        store.setEventListMode(.overview)
        store.setUpcomingDayLimit(180)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.eventListMode, .overview)
        XCTAssertEqual(reloaded.menuBarPreferences.effectiveEventListMode, .overview)
        XCTAssertEqual(reloaded.menuBarPreferences.upcomingDayLimit, 180)

        reloaded.setShowUpcomingSection(false)
        let fallbackStore = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(fallbackStore.menuBarPreferences.eventListMode, .overview)
        XCTAssertEqual(fallbackStore.menuBarPreferences.effectiveEventListMode, .day)

        fallbackStore.setShowUpcomingSection(true)
        let restoredStore = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(restoredStore.menuBarPreferences.effectiveEventListMode, .overview)
        XCTAssertEqual(restoredStore.menuBarPreferences.upcomingDayLimit, 180)
        XCTAssertTrue(restoredStore.menuBarPreferences.showRemindersBoard)
    }

    func testUpcomingAndBoardPreferencesPersistIndependently() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setBoardGroupingMode(.priority)
        store.setBoardCompletedRetentionSeconds(10)
        store.setUpcomingDayLimit(180)
        store.setUpcomingIncludeReminders(false)
        store.setUpcomingDefaultExpanded(false)
        store.setShowUpcomingSection(false)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertTrue(reloaded.menuBarPreferences.showRemindersBoard)
        XCTAssertEqual(reloaded.menuBarPreferences.boardGroupingMode, .priority)
        XCTAssertEqual(reloaded.menuBarPreferences.boardCompletedRetentionSeconds, 10)
        XCTAssertFalse(reloaded.menuBarPreferences.showUpcomingSection)
        XCTAssertEqual(reloaded.menuBarPreferences.upcomingDayLimit, 180)
        XCTAssertFalse(reloaded.menuBarPreferences.upcomingIncludeReminders)
        XCTAssertFalse(reloaded.menuBarPreferences.upcomingDefaultExpanded)

        reloaded.setShowRemindersBoard(false)
        reloaded.setShowUpcomingSection(true)

        let finalStore = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(finalStore.menuBarPreferences.showRemindersBoard)
        XCTAssertEqual(finalStore.menuBarPreferences.boardGroupingMode, .priority)
        XCTAssertEqual(finalStore.menuBarPreferences.boardCompletedRetentionSeconds, 10)
        XCTAssertTrue(finalStore.menuBarPreferences.showUpcomingSection)
        XCTAssertEqual(finalStore.menuBarPreferences.upcomingDayLimit, 180)
        XCTAssertFalse(finalStore.menuBarPreferences.upcomingIncludeReminders)
        XCTAssertFalse(finalStore.menuBarPreferences.upcomingDefaultExpanded)
    }

    func testSetUpcomingSectionPreferencesPersist() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(store.menuBarPreferences.showUpcomingSection)
        XCTAssertEqual(store.menuBarPreferences.upcomingDayLimit, 90)
        XCTAssertTrue(store.menuBarPreferences.upcomingIncludeReminders)
        XCTAssertTrue(store.menuBarPreferences.upcomingDefaultExpanded)

        store.setShowUpcomingSection(false)
        store.setUpcomingDayLimit(180)
        store.setUpcomingIncludeReminders(false)
        store.setUpcomingDefaultExpanded(false)
        store.setUpcomingCalendarEnabled(
            false,
            calendarID: "calendar-1",
            allCalendarIDs: ["calendar-1", "calendar-2"]
        )
        store.setUpcomingReminderCalendarEnabled(
            false,
            calendarID: "reminder-1",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.showUpcomingSection)
        XCTAssertEqual(reloaded.menuBarPreferences.upcomingDayLimit, 180)
        XCTAssertFalse(reloaded.menuBarPreferences.upcomingIncludeReminders)
        XCTAssertFalse(reloaded.menuBarPreferences.upcomingDefaultExpanded)
        XCTAssertEqual(reloaded.menuBarPreferences.upcomingEnabledCalendarIDs, ["calendar-2"])
        XCTAssertEqual(reloaded.menuBarPreferences.upcomingEnabledReminderCalendarIDs, ["reminder-2"])
    }

    func testSetUpcomingCalendarEnabledRestoresEmptyMeansAllSelected() {
        let userDefaults = makeIsolatedUserDefaults()
        let store = makeStore(userDefaults: userDefaults)

        store.setUpcomingCalendarEnabled(
            true,
            calendarID: "calendar-1",
            allCalendarIDs: ["calendar-1", "calendar-2"]
        )
        XCTAssertTrue(store.menuBarPreferences.upcomingEnabledCalendarIDs.isEmpty)

        store.setUpcomingReminderCalendarEnabled(
            true,
            calendarID: "reminder-1",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )
        XCTAssertTrue(store.menuBarPreferences.upcomingEnabledReminderCalendarIDs.isEmpty)
    }

    func testTokenStylePersistsForChineseFormats() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setTokenStyle(.chineseMonthDay, for: .date)
        store.setTokenStyle(.chineseWeekday, for: .weekday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .date })?.style, .chineseMonthDay)
        XCTAssertEqual(reloaded.menuBarPreferences.tokens.first(where: { $0.token == .weekday })?.style, .chineseWeekday)
    }

    func testMenuBarTextStylePersists() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setMenuBarTextBold(true)
        store.setMenuBarTextColorHex("#334155")
        store.setMenuBarFilledBackground(true)
        store.setMenuBarFillColorHex("#E2E8F0")

        let reloaded = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(reloaded.menuBarPreferences.textStyle.isBold)
        XCTAssertEqual(reloaded.menuBarPreferences.textStyle.foregroundColorHex, "#334155")
        XCTAssertTrue(reloaded.menuBarPreferences.textStyle.usesFilledBackground)
        XCTAssertEqual(reloaded.menuBarPreferences.textStyle.backgroundColorHex, "#E2E8F0")
    }

    func testResetMenuBarTextStylePersistsDefault() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setMenuBarTextBold(true)
        store.setMenuBarTextColorHex("#334155")
        store.setMenuBarFilledBackground(true)
        store.resetMenuBarTextStyle()

        let reloaded = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(reloaded.menuBarPreferences.textStyle, .default)
    }

    func testSetWeekStart() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.weekStart, .monday)

        store.setWeekStart(.sunday)
        XCTAssertEqual(store.menuBarPreferences.weekStart, .sunday)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.weekStart, .sunday)

        store.setWeekStart(.monday)
        XCTAssertEqual(store.menuBarPreferences.weekStart, .monday)
    }

    func testInitialLaunchAtLoginStatusReadsControllerState() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testLaunchAtLoginDefaultsToEnabledWhenInitiallyDisabled() {
        let controller = LaunchAtLoginControllerStub(status: .disabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertEqual(controller.recordedRequests, [true])
        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
    }

    func testSetLaunchAtLoginEnabledUpdatesStateOnSuccess() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(controller.recordedRequests, [false])
        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .disabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testSetLaunchAtLoginDisabledUpdatesStateOnSuccess() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertEqual(controller.recordedRequests, [false])
        XCTAssertFalse(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .disabled)
        XCTAssertNil(store.launchAtLoginStatusMessage)
    }

    func testSetLaunchAtLoginEnabledRollsBackAndShowsErrorOnFailure() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        controller.nextError = StubError.operationFailed
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertEqual(
            store.launchAtLoginStatusMessage,
            "无法关闭开机启动：stub operation failed"
        )
    }

    func testSetLaunchAtLoginDisabledRollsBackAndShowsErrorOnFailure() {
        let controller = LaunchAtLoginControllerStub(status: .enabled)
        controller.nextError = StubError.operationFailed
        let store = makeStore(launchAtLoginController: controller)

        store.setLaunchAtLoginEnabled(false)

        XCTAssertTrue(store.launchAtLoginEnabled)
        XCTAssertEqual(store.launchAtLoginStatus, .enabled)
        XCTAssertEqual(
            store.launchAtLoginStatusMessage,
            "无法关闭开机启动：stub operation failed"
        )
    }

    func testSetLocationMode() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.locationMode, .automatic)

        store.setLocationMode(.manual)
        XCTAssertEqual(store.menuBarPreferences.locationMode, .manual)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.locationMode, .manual)
    }

    func testSetManualLocation() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertNil(store.menuBarPreferences.manualLocation)

        let location = WeatherLocation(latitude: 39.9, longitude: 116.4, name: "Beijing", country: "China", admin1: "Beijing")
        store.setManualLocation(location)

        XCTAssertEqual(store.menuBarPreferences.manualLocation?.name, "Beijing")
        XCTAssertEqual(store.menuBarPreferences.manualLocation?.latitude ?? .nan, 39.9, accuracy: 0.01)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.manualLocation?.name, "Beijing")
    }

    func testSetManualLocationToNil() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        let location = WeatherLocation(latitude: 39.9, longitude: 116.4, name: "Beijing", country: nil, admin1: nil)
        store.setManualLocation(location)
        XCTAssertNotNil(store.menuBarPreferences.manualLocation)

        store.setManualLocation(nil)
        XCTAssertNil(store.menuBarPreferences.manualLocation)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertNil(reloaded.menuBarPreferences.manualLocation)
    }

    func testSetWeatherProviderAndQWeatherConfiguration() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.weatherProvider, .openMeteo)
        XCTAssertEqual(store.menuBarPreferences.qWeatherAPIHost, "")
        XCTAssertEqual(store.menuBarPreferences.qWeatherAPIKey, "")

        store.setWeatherProvider(.qWeather)
        store.setQWeatherAPIHost("abc1234xyz.def.qweatherapi.com")
        store.setQWeatherAPIKey("test-key")

        XCTAssertEqual(store.menuBarPreferences.weatherProvider, .qWeather)
        XCTAssertEqual(store.menuBarPreferences.qWeatherAPIHost, "abc1234xyz.def.qweatherapi.com")
        XCTAssertEqual(store.menuBarPreferences.qWeatherAPIKey, "test-key")

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.weatherProvider, .qWeather)
        XCTAssertEqual(reloaded.menuBarPreferences.qWeatherAPIHost, "abc1234xyz.def.qweatherapi.com")
        XCTAssertEqual(reloaded.menuBarPreferences.qWeatherAPIKey, "test-key")

        store.setWeatherProvider(.wttrIn)
        XCTAssertEqual(store.menuBarPreferences.weatherProvider, .wttrIn)
        XCTAssertEqual(store.weatherProviderConfiguration(), .wttrIn)

        store.setWeatherProvider(.sevenTimer)
        XCTAssertEqual(store.menuBarPreferences.weatherProvider, .sevenTimer)
        XCTAssertEqual(store.weatherProviderConfiguration(), .sevenTimer)
    }

    func testSetShowRemindersBoardPersists() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(store.menuBarPreferences.showRemindersBoard)

        store.setShowRemindersBoard(false)
        XCTAssertFalse(store.menuBarPreferences.showRemindersBoard)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertFalse(reloaded.menuBarPreferences.showRemindersBoard)
    }

    func testSetBoardReminderCalendarEnabledDisablesSingleListWhenEmptyMeansAllSelected() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setBoardReminderCalendarEnabled(
            false,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertEqual(store.menuBarPreferences.boardEnabledReminderCalendarIDs, ["reminder-1"])

        store.setBoardReminderCalendarEnabled(
            true,
            calendarID: "reminder-2",
            allCalendarIDs: ["reminder-1", "reminder-2"]
        )

        XCTAssertTrue(store.menuBarPreferences.boardEnabledReminderCalendarIDs.isEmpty)
    }

    func testBoardGroupingModeShowCompletedAndColorModePersist() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.boardGroupingMode, .list)
        XCTAssertFalse(store.menuBarPreferences.boardShowCompleted)
        XCTAssertEqual(store.menuBarPreferences.boardColorMode, .overdue)

        store.setBoardGroupingMode(.priority)
        store.setBoardShowCompleted(true)
        store.setBoardColorMode(.timeBucket)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.boardGroupingMode, .priority)
        XCTAssertTrue(reloaded.menuBarPreferences.boardShowCompleted)
        XCTAssertEqual(reloaded.menuBarPreferences.boardColorMode, .timeBucket)
    }

    func testBoardCompletedRetentionSecondsPersist() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.boardCompletedRetentionSeconds, 3)

        store.setBoardCompletedRetentionSeconds(10)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.boardCompletedRetentionSeconds, 10)
    }

    func testSetBoardColorPresetAppliesPaletteAndPersists() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        XCTAssertEqual(store.menuBarPreferences.boardColorPreset, .classic)

        store.setBoardColorPreset(.warm)

        let warmPalette = BoardColorPreset.warm.colorPreferences
        XCTAssertEqual(store.menuBarPreferences.boardColorPreferences, warmPalette)

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.boardColorPreset, .warm)
        XCTAssertEqual(reloaded.menuBarPreferences.boardColorPreferences, warmPalette)
    }

    func testSetBoardColorHexTransitionsPresetToCustomAndPersists() {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let store = makeStore(userDefaults: userDefaults)

        store.setBoardColorPreset(.cool)
        XCTAssertEqual(store.menuBarPreferences.boardColorPreset, .cool)

        store.setBoardColorHex("#123456", for: .overdue)

        XCTAssertEqual(store.menuBarPreferences.boardColorPreset, .custom)
        XCTAssertEqual(
            store.menuBarPreferences.boardColorPreferences.colorHex(for: .overdue),
            "#123456"
        )
        XCTAssertEqual(
            store.menuBarPreferences.boardColorPreferences.colorHex(for: .today),
            BoardColorPreset.cool.colorPreferences?.colorHex(for: .today)
        )

        let reloaded = makeStore(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.menuBarPreferences.boardColorPreset, .custom)
        XCTAssertEqual(
            reloaded.menuBarPreferences.boardColorPreferences.colorHex(for: .overdue),
            "#123456"
        )
    }

    func testMenuBarPreferencesDecodeFillsBoardDefaultsForLegacyData() throws {
        let suiteName = #function
        let userDefaults = makeIsolatedUserDefaults(name: suiteName)
        let legacyJSON = """
        {
          "tokens": [
            {"token": "date", "isEnabled": true, "order": 0, "style": "short"}
          ],
          "separator": " ",
          "showLunarInMenuBar": false,
          "activeRegionIDs": [],
          "enabledHolidayIDs": [],
          "weekStart": "monday",
          "showEvents": true,
          "enabledCalendarIDs": [],
          "showReminders": true,
          "enabledReminderCalendarIDs": []
        }
        """
        try userDefaults.set(Data(legacyJSON.utf8), forKey: "menuBarPreferences")

        let store = makeStore(userDefaults: userDefaults)

        XCTAssertTrue(store.menuBarPreferences.showRemindersBoard)
        XCTAssertEqual(store.menuBarPreferences.boardGroupingMode, .list)
        XCTAssertFalse(store.menuBarPreferences.boardShowCompleted)
        XCTAssertEqual(store.menuBarPreferences.boardCompletedRetentionSeconds, 3)
        XCTAssertEqual(store.menuBarPreferences.boardColorMode, .overdue)
        XCTAssertEqual(store.menuBarPreferences.boardColorPreferences, .classic)
        XCTAssertEqual(store.menuBarPreferences.boardColorPreset, .classic)
    }

    private func makeIsolatedUserDefaults(name: String = #function) -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return userDefaults
    }

    private func makeStore(
        userDefaults: UserDefaults = UserDefaults(suiteName: #function)!,
        launchAtLoginController: LaunchAtLoginControllerStub = LaunchAtLoginControllerStub()
    ) -> SettingsStore {
        SettingsStore(
            userDefaults: userDefaults,
            launchAtLoginController: launchAtLoginController
        )
    }
}

private final class LaunchAtLoginControllerStub: LaunchAtLoginControlling {
    var statusValue: LaunchAtLoginStatus
    var nextError: Error?
    private(set) var recordedRequests: [Bool] = []

    init(status: LaunchAtLoginStatus = .disabled) {
        self.statusValue = status
    }

    func status() -> LaunchAtLoginStatus {
        statusValue
    }

    func setEnabled(_ enabled: Bool) throws {
        recordedRequests.append(enabled)

        if let nextError {
            self.nextError = nil
            throw nextError
        }

        statusValue = enabled ? .enabled : .disabled
    }
}

private enum StubError: LocalizedError {
    case operationFailed

    var errorDescription: String? {
        "stub operation failed"
    }
}

private extension UserDefaults {
    func setEncodedMenuBarPreferences(_ preferences: MenuBarPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        set(data, forKey: "menuBarPreferences")
    }
}
