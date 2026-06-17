import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: SettingsStore
    @State private var availableWidth: CGFloat = .zero

    private let clockRenderer = ClockRenderService()
    private let textImageRenderer = MenuBarTextImageRenderer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(L("Menu Bar Preview")) {
                    HStack {
                        previewMenuBarText

                        Spacer(minLength: 0)
                    }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(L("Font Style")) {
                    fontStyleControls
                }

                GroupBox(L("Basic Settings")) {
                    VStack(alignment: .leading, spacing: 12) {
                        if usesCompactLayout {
                            Text(L("Separator"))

                            TextField(L("Space"), text: separatorBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120, alignment: .leading)
                        } else {
                            HStack {
                                Text(L("Separator"))
                                Spacer()
                                TextField(L("Space"), text: separatorBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                    }
                }

                GroupBox(L("Display Items")) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedTokens) { token in
                            let weatherControlsDisabled = token.token == .weather && !store.menuBarPreferences.showWeather

                            if usesCompactLayout {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle(tokenDisplayName(token.token), isOn: enabledBinding(for: token.token))
                                        .toggleStyle(.checkbox)
                                        .disabled(weatherControlsDisabled)

                                    HStack(alignment: .center, spacing: 12) {
                                        if styleOptions(for: token.token).count > 1 {
                                            Picker(L("Style"), selection: styleBinding(for: token.token)) {
                                                ForEach(styleOptions(for: token.token), id: \.self) { style in
                                                    Text(stylePreviewText(style, for: token.token)).tag(style)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(maxWidth: 160, alignment: .leading)
                                            .disabled(weatherControlsDisabled)
                                        }

                                        Spacer(minLength: 0)

                                        movementButtons(for: token)
                                    }

                                    if weatherControlsDisabled {
                                        Text(L("Enable Weather First"))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack(spacing: 12) {
                                    Toggle(tokenDisplayName(token.token), isOn: enabledBinding(for: token.token))
                                        .toggleStyle(.checkbox)
                                        .frame(width: 120, alignment: .leading)
                                        .disabled(weatherControlsDisabled)

                                    if styleOptions(for: token.token).count > 1 {
                                        Picker(L("Style"), selection: styleBinding(for: token.token)) {
                                            ForEach(styleOptions(for: token.token), id: \.self) { style in
                                                Text(stylePreviewText(style, for: token.token)).tag(style)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 120)
                                        .disabled(weatherControlsDisabled)
                                    }

                                    if weatherControlsDisabled {
                                        Text(L("Enable Weather First"))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 0)

                                    movementButtons(for: token)
                                }
                            }
                        }

                        pomodoroDisplayItem
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: MenuBarSettingsContentWidthKey.self, value: proxy.size.width)
                }
            }
        }
        .onPreferenceChange(MenuBarSettingsContentWidthKey.self) { availableWidth = $0 }
    }

    private var sortedTokens: [DisplayTokenPreference] {
        store.menuBarPreferences.tokens.sorted { $0.order < $1.order }
    }

    private var separatorBinding: Binding<String> {
        Binding(
            get: { store.menuBarPreferences.separator },
            set: { store.setSeparator($0) }
        )
    }

    private var pomodoroEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.pomodoroPreferences.isEnabled },
            set: { store.setPomodoroEnabled($0) }
        )
    }

    private var pomodoroStyleBinding: Binding<PomodoroMenuBarStyle> {
        Binding(
            get: { store.pomodoroPreferences.menuBarStyle },
            set: { store.setPomodoroMenuBarStyle($0) }
        )
    }

    private var usesCompactLayout: Bool {
        availableWidth > 0 && availableWidth < 500
    }

    private var previewText: String {
        let now = Date()
        let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
        let day = try? factory.makeDay(for: now, displayedMonth: now, preferences: store.menuBarPreferences)

        return clockRenderer.render(
            now: now,
            preferences: store.menuBarPreferences,
            supplementalText: MenuBarSupplementalText(
                lunarText: day?.lunarText,
                holidayText: day?.badges.first?.text,
                weatherText: MenuBarViewModel.menuBarWeatherText(
                    for: Self.previewWeatherDescriptor,
                    preferences: store.menuBarPreferences
                )
            )
        )
    }

    private static let previewWeatherDescriptor = WeatherDescriptor(
        locationName: "Beijing",
        temperatureText: "23°",
        apparentTemperature: 28,
        forecastDate: nil,
        weatherCode: 2,
        isDaytime: true,
        isCurrentConditions: true,
        airQualityIndex: 42,
        pm25: 18
    )

    private var textStyle: MenuBarTextStyle {
        store.menuBarPreferences.textStyle
    }

    private var previewMenuBarText: some View {
        let renderResult = textImageRenderer.render(text: previewText, style: textStyle, indicator: nil)

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(previewBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(previewBorderColor, lineWidth: 0.5)
            )
            .overlay(alignment: .leading) {
                previewImage(for: renderResult)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .frame(minWidth: 160, minHeight: 28, alignment: .leading)
            .shadow(color: previewShadowColor, radius: 2, y: 1)
    }

    @ViewBuilder
    private func previewImage(for renderResult: MenuBarTextImageRenderResult) -> some View {
        let image = Image(nsImage: renderResult.image)

        if renderResult.usesTemplateColor {
            image
                .renderingMode(.template)
                .foregroundStyle(previewTemplateForegroundColor)
        } else {
            image
                .renderingMode(.original)
        }
    }

    private var previewBackgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.16, green: 0.17, blue: 0.20)
            : Color.white
    }

    private var previewBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var previewShadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.06)
    }

    private var previewTemplateForegroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color.black.opacity(0.88)
    }

    private var fontStyleControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if usesCompactLayout {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L("Bold"), isOn: boldBinding)
                        .toggleStyle(.checkbox)

                    textColorControl
                    fillColorControl
                    resetStyleButton
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Toggle(L("Bold"), isOn: boldBinding)
                        .toggleStyle(.checkbox)

                    textColorControl
                    fillColorControl

                    Spacer(minLength: 0)

                    resetStyleButton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pomodoroDisplayItem: some View {
        Group {
            if usesCompactLayout {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L("Pomodoro"), isOn: pomodoroEnabledBinding)
                        .toggleStyle(.checkbox)

                    pomodoroStylePicker

                    Text(L("Pomodoro Menu Bar Display Hint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    Toggle(L("Pomodoro"), isOn: pomodoroEnabledBinding)
                        .toggleStyle(.checkbox)
                        .frame(width: 120, alignment: .leading)

                    pomodoroStylePicker
                        .frame(width: 120)

                    Text(L("Pomodoro Menu Bar Display Hint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var pomodoroStylePicker: some View {
        Picker(L("Style"), selection: pomodoroStyleBinding) {
            ForEach(PomodoroMenuBarStyle.allCases) { style in
                Text(pomodoroStyleTitle(style)).tag(style)
            }
        }
        .labelsHidden()
        .disabled(!store.pomodoroPreferences.isEnabled)
    }

    private func pomodoroStyleTitle(_ style: PomodoroMenuBarStyle) -> String {
        switch style {
        case .countdown:
            return L("Countdown")
        case .progress:
            return L("Progress")
        case .pie:
            return L("Pie")
        }
    }

    private var textColorControl: some View {
        HStack(spacing: 8) {
            Toggle(L("Custom Text Color"), isOn: customTextColorBinding)
                .toggleStyle(.checkbox)

            ColorPicker(L("Text Color"), selection: textColorBinding)
                .labelsHidden()
                .disabled(textStyle.foregroundColorHex == nil)
        }
    }

    private var fillColorControl: some View {
        HStack(spacing: 8) {
            Toggle(L("Filled Background"), isOn: filledBackgroundBinding)
                .toggleStyle(.checkbox)

            ColorPicker(L("Fill Color"), selection: fillColorBinding)
                .labelsHidden()
                .disabled(!textStyle.usesFilledBackground)
        }
    }

    private var resetStyleButton: some View {
        Button {
            store.resetMenuBarTextStyle()
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.borderless)
        .help(L("Reset Font Style"))
        .accessibilityLabel(L("Reset Font Style"))
    }

    private var boldBinding: Binding<Bool> {
        Binding(
            get: { textStyle.isBold },
            set: { store.setMenuBarTextBold($0) }
        )
    }

    private var customTextColorBinding: Binding<Bool> {
        Binding(
            get: { textStyle.foregroundColorHex != nil },
            set: { enabled in
                store.setMenuBarTextColorHex(
                    enabled
                        ? (textStyle.foregroundColorHex ?? MenuBarTextStyle.defaultCustomForegroundColorHex)
                        : nil
                )
            }
        )
    }

    private var filledBackgroundBinding: Binding<Bool> {
        Binding(
            get: { textStyle.usesFilledBackground },
            set: { store.setMenuBarFilledBackground($0) }
        )
    }

    private var textColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(menuBarHex: textStyle.foregroundColorHex ?? MenuBarTextStyle.defaultCustomForegroundColorHex)
            },
            set: { color in
                store.setMenuBarTextColorHex(color.menuBarHexString() ?? MenuBarTextStyle.defaultCustomForegroundColorHex)
            }
        )
    }

    private var fillColorBinding: Binding<Color> {
        Binding(
            get: { Color(menuBarHex: textStyle.backgroundColorHex) },
            set: { color in
                store.setMenuBarFillColorHex(color.menuBarHexString() ?? MenuBarTextStyle.defaultBackgroundColorHex)
            }
        )
    }

    private func enabledBinding(for token: DisplayTokenKind) -> Binding<Bool> {
        Binding(
            get: {
                store.menuBarPreferences.tokens.first(where: { $0.token == token })?.isEnabled ?? false
            },
            set: { store.setTokenEnabled($0, for: token) }
        )
    }

    private func styleBinding(for token: DisplayTokenKind) -> Binding<DisplayTokenStyle> {
        Binding(
            get: {
                resolvedStyle(for: token)
            },
            set: { store.setTokenStyle($0, for: token) }
        )
    }

    private func resolvedStyle(for token: DisplayTokenKind) -> DisplayTokenStyle {
        let storedStyle = store.menuBarPreferences.tokens.first(where: { $0.token == token })?.style ?? defaultStyle(for: token)
        return styleOptions(for: token).contains(storedStyle) ? storedStyle : defaultStyle(for: token)
    }

    private func styleOptions(for token: DisplayTokenKind) -> [DisplayTokenStyle] {
        let showChinese = LocaleFeatureAvailability.showChineseDateStyles
        switch token {
        case .date:
            let base: [DisplayTokenStyle] = [.numeric, .numericUnpadded, .short, .shortUnpadded, .full]
            return showChinese
                ? base + [.chineseMonthDay, .chineseMonthDayUnpadded, .chineseFull, .chineseFullUnpadded]
                : base
        case .weekday:
            let base: [DisplayTokenStyle] = [.short, .full]
            return showChinese ? base + [.chineseWeekday] : base
        case .time:
            return [.short, .full] as [DisplayTokenStyle]
        case .lunar:
            guard LocaleFeatureAvailability.showLunarFeatures else { return [] as [DisplayTokenStyle] }
            let base: [DisplayTokenStyle] = [.short, .full]
            return showChinese ? [.short, .chineseMonthDay, .full] : base
        case .holiday:
            return [.short] as [DisplayTokenStyle]
        case .weather:
            return [
                .weatherTemperature,
                .weatherConditionTemperature,
                .weatherTemperaturePM25,
                .weatherTemperatureAQI,
                .weatherFeelsLike
            ] as [DisplayTokenStyle]
        }
    }

    private func defaultStyle(for token: DisplayTokenKind) -> DisplayTokenStyle {
        switch token {
        case .date, .time, .weekday, .lunar, .holiday:
            .short
        case .weather:
            .weatherTemperature
        }
    }

    private func stylePreviewText(_ style: DisplayTokenStyle, for token: DisplayTokenKind) -> String {
        let now = Date()
        let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
        let day = try? factory.makeDay(for: now, displayedMonth: now, preferences: store.menuBarPreferences)

        switch token {
        case .date:
            return clockRenderer.renderPreview(token: token, style: style, now: now)
        case .time:
            return clockRenderer.renderPreview(token: token, style: style, now: now)
        case .weekday:
            return clockRenderer.renderPreview(token: token, style: style, now: now)
        case .lunar:
            let lunarService = LunarService()
            let lunarDescriptor = lunarService.describe(date: now, timeZone: .autoupdatingCurrent)
            let lunarStyle: LunarDisplayStyle
            switch style {
            case .short:
                lunarStyle = .day
            case .chineseMonthDay:
                lunarStyle = .monthDay
            case .full:
                lunarStyle = .yearMonthDay
            default:
                lunarStyle = .day
            }
            return lunarDescriptor.displayText(style: lunarStyle)
        case .holiday:
            return day?.badges.first?.text ?? L("Holiday")
        case .weather:
            return weatherStylePreviewText(style)
        }
    }

    private func weatherStylePreviewText(_ style: DisplayTokenStyle) -> String {
        switch style {
        case .weatherConditionTemperature:
            return L("Weather Format Condition Temperature")
        case .weatherTemperaturePM25:
            return L("Weather Format Temperature PM25")
        case .weatherTemperatureAQI:
            return L("Weather Format Temperature AQI")
        case .weatherFeelsLike:
            return L("Weather Format Feels Like")
        case .weatherTemperature, .short:
            return L("Weather Format Temperature")
        default:
            return L("Weather Format Temperature")
        }
    }

    private func tokenDisplayName(_ token: DisplayTokenKind) -> String {
        switch token {
        case .date:
            L("Date")
        case .time:
            L("Time")
        case .weekday:
            L("Weekday")
        case .lunar:
            L("Lunar")
        case .holiday:
            L("Holiday")
        case .weather:
            L("Weather")
        }
    }

    @ViewBuilder
    private func movementButtons(for token: DisplayTokenPreference) -> some View {
        HStack(spacing: 8) {
            Button {
                store.moveToken(token.token, by: -1)
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(token.order == 0)

            Button {
                store.moveToken(token.token, by: 1)
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(token.order == sortedTokens.count - 1)
        }
    }
}

private struct MenuBarSettingsContentWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension Color {
    init(menuBarHex hex: String) {
        self.init(nsColor: NSColor(menuBarHex: hex) ?? .labelColor)
    }

    func menuBarHexString() -> String? {
        NSColor(self).menuBarHexString()
    }
}
