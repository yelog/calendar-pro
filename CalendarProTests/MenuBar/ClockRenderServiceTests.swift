import XCTest
@testable import CalendarPro

final class ClockRenderServiceTests: XCTestCase {
    func testTextImageRendererUsesTemplateImageForDefaultStyle() {
        let renderer = MenuBarTextImageRenderer()

        let result = renderer.render(text: "10:30 Tue 04/22", style: .default)

        XCTAssertTrue(result.usesTemplateColor)
        XCTAssertTrue(result.image.isTemplate)
        XCTAssertGreaterThan(result.image.size.width, 0)
    }

    func testTextImageRendererUsesOriginalImageForCustomForegroundColor() {
        let renderer = MenuBarTextImageRenderer()
        let style = MenuBarTextStyle(
            isBold: true,
            foregroundColorHex: "#334155",
            usesFilledBackground: false,
            backgroundColorHex: MenuBarTextStyle.defaultBackgroundColorHex
        )

        let result = renderer.render(text: "10:30 Tue 04/22", style: style)

        XCTAssertFalse(result.usesTemplateColor)
        XCTAssertFalse(result.image.isTemplate)
    }

    func testTextImageRendererUsesOriginalImageForFilledBackground() {
        let renderer = MenuBarTextImageRenderer()
        let style = MenuBarTextStyle(
            isBold: true,
            foregroundColorHex: nil,
            usesFilledBackground: true,
            backgroundColorHex: "#111827"
        )

        let result = renderer.render(text: "10:30 Tue 04/22", style: style)

        XCTAssertFalse(result.usesTemplateColor)
        XCTAssertFalse(result.image.isTemplate)
        XCTAssertGreaterThan(result.image.size.height, 0)
    }

    func testTextImageRendererKeepsTemplateTextWithCalendarColorIndicator() {
        let renderer = MenuBarTextImageRenderer()
        let indicator = MenuBarEventIndicator(
            dots: [
                MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)
            ],
            tooltipText: "会议",
            count: 1
        )

        let plainResult = renderer.render(text: "10:30 Tue 04/22", style: .default)
        let indicatorResult = renderer.render(text: "10:30 Tue 04/22", style: .default, indicator: indicator)

        XCTAssertTrue(indicatorResult.usesTemplateColor)
        XCTAssertTrue(indicatorResult.image.isTemplate)
        XCTAssertNotNil(indicatorResult.indicatorOverlayImage)
        XCTAssertGreaterThan(indicatorResult.image.size.width, plainResult.image.size.width)
    }

    func testTextImageRendererRemovesIndicatorOverlayWhenIndicatorDisappears() {
        let renderer = MenuBarTextImageRenderer()
        let indicator = MenuBarEventIndicator(
            dots: [MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)],
            tooltipText: "会议",
            count: 1
        )

        XCTAssertNotNil(renderer.render(text: "10:30", style: .default, indicator: indicator).indicatorOverlayImage)
        XCTAssertNil(renderer.render(text: "10:30", style: .default, indicator: nil).indicatorOverlayImage)
        XCTAssertNil(
            renderer.render(
                text: "10:30",
                style: .default,
                indicator: MenuBarEventIndicator(dots: [], tooltipText: "", count: 0)
            ).indicatorOverlayImage
        )
    }

    func testTextImageRendererKeepsCalendarDotColorInOverlay() {
        let indicator = MenuBarEventIndicator(
            dots: [MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)],
            tooltipText: "会议",
            count: 1
        )
        let result = MenuBarTextImageRenderer().render(text: "10:30", style: .default, indicator: indicator)
        let overlay = result.indicatorOverlayImage!

        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(overlay.size.width)),
            pixelsHigh: Int(ceil(overlay.size.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        overlay.draw(in: NSRect(origin: .zero, size: overlay.size))
        NSGraphicsContext.restoreGraphicsState()

        let dotX = Int(ceil(overlay.size.width)) - 5
        let dotY = Int(ceil(overlay.size.height)) / 2
        let color = bitmap.colorAt(x: dotX, y: dotY)?.usingColorSpace(.deviceRGB)
        XCTAssertEqual(color?.alphaComponent ?? 0, 1, accuracy: 0.05)
        XCTAssertEqual(color?.greenComponent ?? 0, 0.78, accuracy: 0.12)
        XCTAssertEqual(color?.redComponent ?? 1, 0.20, accuracy: 0.12)
    }

    func testTextImageRendererKeepsTemplateImageTransparentWhereIndicatorIsDrawn() {
        let indicator = MenuBarEventIndicator(
            dots: [MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)],
            tooltipText: "会议",
            count: 1
        )
        let image = MenuBarTextImageRenderer().render(text: "10:30", style: .default, indicator: indicator).image
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(ceil(image.size.width)),
            pixelsHigh: Int(ceil(image.size.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()

        let dotX = Int(ceil(image.size.width)) - 5
        let dotY = Int(ceil(image.size.height)) / 2
        XCTAssertEqual(bitmap.colorAt(x: dotX, y: dotY)?.alphaComponent ?? 1, 0, accuracy: 0.05)
    }

    func testTextImageRendererUsesCompactTwoRowLayoutForMultipleIndicators() {
        let renderer = MenuBarTextImageRenderer()
        let text = "10:30 Tue 04/22"
        let oneDotResult = renderer.render(
            text: text,
            style: .default,
            indicator: MenuBarEventIndicator(
                dots: [MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing)],
                tooltipText: "会议",
                count: 1
            )
        )
        let twoDotResult = renderer.render(
            text: text,
            style: .default,
            indicator: MenuBarEventIndicator(
                dots: [
                    MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing),
                    MenuBarEventIndicatorDot(colorHex: "#007AFF", status: .upcoming)
                ],
                tooltipText: "会议\n评审",
                count: 2
            )
        )
        let threeDotResult = renderer.render(
            text: text,
            style: .default,
            indicator: MenuBarEventIndicator(
                dots: [
                    MenuBarEventIndicatorDot(colorHex: "#34C759", status: .ongoing),
                    MenuBarEventIndicatorDot(colorHex: "#007AFF", status: .upcoming),
                    MenuBarEventIndicatorDot(colorHex: "#FF9500", status: .upcoming)
                ],
                tooltipText: "会议\n评审\n同步",
                count: 3
            )
        )

        XCTAssertTrue(oneDotResult.usesTemplateColor)
        XCTAssertTrue(twoDotResult.usesTemplateColor)
        XCTAssertTrue(threeDotResult.usesTemplateColor)
        XCTAssertTrue(twoDotResult.image.isTemplate)
        XCTAssertNotNil(twoDotResult.indicatorOverlayImage)
        XCTAssertEqual(twoDotResult.image.size.width, oneDotResult.image.size.width, accuracy: 0.5)
        XCTAssertLessThan(threeDotResult.image.size.width, oneDotResult.image.size.width + 20)
    }

    func testRendererRespectsTokenOrderAndShortStyles() {
        let renderer = ClockRenderService()
        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: .previewShort,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00 Thu 01/01")
    }

    func testRendererSkipsEmptySupplementalTokens() {
        let renderer = ClockRenderService()
        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .time, isEnabled: true, order: 0, style: .short),
                DisplayTokenPreference(token: .lunar, isEnabled: true, order: 1, style: .short)
            ],
            separator: " ",
            showLunarInMenuBar: true,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false,
            showUpcomingIndicator: true,
            upcomingReminderMinutes: 15
        )

        let text = renderer.render(
            now: Date(timeIntervalSince1970: 0),
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )

        XCTAssertEqual(text, "00:00")
    }

    func testRendererSupportsChineseDateAndWeekdayStyles() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 9, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .chineseMonthDay),
                DisplayTokenPreference(token: .weekday, isEnabled: true, order: 1, style: .chineseWeekday)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false,
            showUpcomingIndicator: true,
            upcomingReminderMinutes: 15
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "03月30日 周一")
    }

    func testRendererNumericFormatUsesDayFirst() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .numeric)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false,
            showUpcomingIndicator: true,
            upcomingReminderMinutes: 15
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "05/04")
    }

    func testRendererChineseFullFormat() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        let preferences = MenuBarPreferences(
            tokens: [
                DisplayTokenPreference(token: .date, isEnabled: true, order: 0, style: .chineseFull)
            ],
            separator: " ",
            showLunarInMenuBar: false,
            activeRegionIDs: ["mainland-cn"],
            enabledHolidayIDs: [],
            weekStart: .monday,
            highlightWeekends: true,
            showEvents: true,
            showCalendarEvents: true,
            enabledCalendarIDs: [],
            showReminders: true,
            enabledReminderCalendarIDs: [],
            showAlmanac: false,
            showWeather: false,
            showUpcomingIndicator: true,
            upcomingReminderMinutes: 15
        )

        let text = renderer.render(
            now: now,
            preferences: preferences,
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: calendar,
            timeZone: timeZone
        )

        XCTAssertEqual(text, "2026年04月05日")
    }

    func testRendererSupportsUnpaddedDateStyles() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5, hour: 10, minute: 0))!

        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .numericUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "5/4"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .shortUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026/4/5"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseMonthDayUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "4月5日"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseFullUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026年4月5日"
        )
    }

    func testRendererUnpaddedDateStylesStayDistinctForDoubleDigitDay() {
        let renderer = ClockRenderService()
        let timeZone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 22, hour: 10, minute: 0))!

        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .numericUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "22/4"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .shortUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026/4/22"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseMonthDayUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "4月22日"
        )
        XCTAssertEqual(
            renderer.renderPreview(
                token: .date,
                style: .chineseFullUnpadded,
                now: now,
                locale: Locale(identifier: "zh_CN"),
                calendar: calendar,
                timeZone: timeZone
            ),
            "2026年4月22日"
        )
    }
}
