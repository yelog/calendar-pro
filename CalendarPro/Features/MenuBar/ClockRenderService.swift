import AppKit
import Foundation

struct MenuBarSupplementalText: Equatable {
    var lunarText: String?
    var holidayText: String?

    static let empty = MenuBarSupplementalText()
}

struct ClockRenderService {
    func render(
        now: Date,
        preferences: MenuBarPreferences,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        supplementalText: MenuBarSupplementalText = .empty
    ) -> String {
        preferences.tokens
            .filter(\.isEnabled)
            .sorted { $0.order < $1.order }
            .compactMap { tokenPreference in
                renderToken(
                    tokenPreference,
                    now: now,
                    locale: locale,
                    calendar: calendar,
                    timeZone: timeZone,
                    supplementalText: supplementalText
                )
            }
            .filter { !$0.isEmpty }
            .joined(separator: preferences.separator)
    }

    func renderPreview(
        token: DisplayTokenKind,
        style: DisplayTokenStyle,
        now: Date = Date(),
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        supplementalText: MenuBarSupplementalText = .empty
    ) -> String {
        let preference = DisplayTokenPreference(token: token, isEnabled: true, order: 0, style: style)
        return renderToken(preference, now: now, locale: locale, calendar: calendar, timeZone: timeZone, supplementalText: supplementalText) ?? ""
    }

    func renderToken(
        _ tokenPreference: DisplayTokenPreference,
        now: Date,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone,
        supplementalText: MenuBarSupplementalText
    ) -> String? {
        switch tokenPreference.token {
        case .date:
            return renderDate(now: now, style: tokenPreference.style, locale: locale, timeZone: timeZone)
        case .time:
            return renderTime(now: now, showSeconds: tokenPreference.style == .full, locale: locale, timeZone: timeZone)
        case .weekday:
            return renderWeekday(now: now, style: tokenPreference.style, locale: locale, calendar: calendar, timeZone: timeZone)
        case .lunar:
            guard LocaleFeatureAvailability.showLunarFeatures else { return nil }
            return supplementalText.lunarText
        case .holiday:
            return supplementalText.holidayText
        }
    }

    private func renderDate(now: Date, style: DisplayTokenStyle, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)

        switch style {
        case .numeric:
            formatter.dateFormat = "dd/MM"
        case .numericUnpadded:
            formatter.dateFormat = "d/M"
        case .short:
            formatter.setLocalizedDateFormatFromTemplate("yMMdd")
        case .shortUnpadded:
            formatter.setLocalizedDateFormatFromTemplate("yMd")
        case .full:
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        case .chineseMonthDay:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("MMMMdd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM月dd日"
        case .chineseMonthDayUnpadded:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("MMMd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
        case .chineseFull:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.dateStyle = .long
                formatter.timeStyle = .none
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年MM月dd日"
        case .chineseFullUnpadded:
            guard LocaleFeatureAvailability.showChineseDateStyles else {
                formatter.setLocalizedDateFormatFromTemplate("yMMMd")
                return formatter.string(from: now)
            }
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年M月d日"
        case .chineseWeekday:
            formatter.setLocalizedDateFormatFromTemplate("yMMdd")
        }

        return formatter.string(from: now)
    }

    private func renderTime(now: Date, showSeconds: Bool, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .none
        formatter.dateFormat = showSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: now)
    }

    private func renderWeekday(
        now: Date,
        style: DisplayTokenStyle,
        locale: Locale,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> String {
        if style == .chineseWeekday && LocaleFeatureAvailability.showChineseDateStyles {
            var localizedCalendar = calendar
            localizedCalendar.timeZone = timeZone
            let weekday = localizedCalendar.component(.weekday, from: now)
            let chineseWeekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            return chineseWeekdays[weekday - 1]
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = calendar
        formatter.dateFormat = style == .full ? "EEEE" : "EEE"
        return formatter.string(from: now)
    }
}

struct MenuBarTextImageRenderResult {
    let image: NSImage
    let usesTemplateColor: Bool
}

struct MenuBarTextImageRenderer {
    func render(text: String, style: MenuBarTextStyle) -> MenuBarTextImageRenderResult {
        let showsFilledBackground = style.usesFilledBackground && !text.isEmpty
        let usesTemplateColor = style.foregroundColorHex == nil && !showsFilledBackground
        let attributes: [NSAttributedString.Key: Any] = [
            .font: statusBarFont(for: style),
            .foregroundColor: usesTemplateColor ? NSColor.black : foregroundColor(for: style)
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()

        let horizontalPadding: CGFloat = showsFilledBackground ? 8 : 2
        let verticalPadding: CGFloat = showsFilledBackground ? 3 : 0
        let imageHeight = max(ceil(textSize.height) + verticalPadding * 2, showsFilledBackground ? 18 : 1)
        let imageSize = NSSize(
            width: max(ceil(textSize.width) + horizontalPadding * 2, 1),
            height: imageHeight
        )

        let image = NSImage(size: imageSize, flipped: false) { rect in
            if showsFilledBackground {
                self.backgroundColor(for: style).setFill()
                NSBezierPath(
                    roundedRect: rect,
                    xRadius: 6,
                    yRadius: 6
                ).fill()
            }

            let drawRect = NSRect(
                x: horizontalPadding,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedText.draw(in: drawRect)
            return true
        }
        image.isTemplate = usesTemplateColor

        return MenuBarTextImageRenderResult(image: image, usesTemplateColor: usesTemplateColor)
    }

    private func statusBarFont(for style: MenuBarTextStyle) -> NSFont {
        .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize,
            weight: style.isBold ? .semibold : .regular
        )
    }

    private func foregroundColor(for style: MenuBarTextStyle) -> NSColor {
        if let foregroundColorHex = style.foregroundColorHex,
           let foregroundColor = NSColor(menuBarHex: foregroundColorHex) {
            return foregroundColor
        }

        if style.usesFilledBackground,
           let foregroundColor = NSColor(
               menuBarHex: MenuBarTextStyle.automaticForegroundColorHex(for: style.backgroundColorHex)
           ) {
            return foregroundColor
        }

        return .black
    }

    private func backgroundColor(for style: MenuBarTextStyle) -> NSColor {
        NSColor(menuBarHex: style.backgroundColorHex)
            ?? NSColor(menuBarHex: MenuBarTextStyle.defaultBackgroundColorHex)
            ?? .white
    }
}

extension NSColor {
    convenience init?(menuBarHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let integer = UInt64(value, radix: 16) else { return nil }

        self.init(
            calibratedRed: CGFloat((integer >> 16) & 0xFF) / 255,
            green: CGFloat((integer >> 8) & 0xFF) / 255,
            blue: CGFloat(integer & 0xFF) / 255,
            alpha: 1
        )
    }

    func menuBarHexString() -> String? {
        guard let color = usingColorSpace(.sRGB) else { return nil }

        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }
}
