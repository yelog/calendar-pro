import SwiftUI

struct MenuBarSettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var availableWidth: CGFloat = .zero

    private let renderer = ClockRenderService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("菜单栏预览") {
                    Text(previewText)
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("基础设置") {
                    VStack(alignment: .leading, spacing: 12) {
                        if usesCompactLayout {
                            Text("分隔符")

                            TextField("空格", text: separatorBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 120, alignment: .leading)
                        } else {
                            HStack {
                                Text("分隔符")
                                Spacer()
                                TextField("空格", text: separatorBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                            }
                        }
                    }
                }

                GroupBox("显示项") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedTokens) { token in
                            if usesCompactLayout {
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle(tokenDisplayName(token.token), isOn: enabledBinding(for: token.token))
                                        .toggleStyle(.checkbox)

                                    HStack(alignment: .center, spacing: 12) {
                                        if styleOptions(for: token.token).count > 1 {
                                            Picker("样式", selection: styleBinding(for: token.token)) {
                                                ForEach(styleOptions(for: token.token), id: \.self) { style in
                                                    Text(stylePreviewText(style, for: token.token)).tag(style)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(maxWidth: 160, alignment: .leading)
                                        }

                                        Spacer(minLength: 0)

                                        movementButtons(for: token)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                HStack(spacing: 12) {
                                    Toggle(tokenDisplayName(token.token), isOn: enabledBinding(for: token.token))
                                        .toggleStyle(.checkbox)
                                        .frame(width: 120, alignment: .leading)

                                    if styleOptions(for: token.token).count > 1 {
                                        Picker("样式", selection: styleBinding(for: token.token)) {
                                            ForEach(styleOptions(for: token.token), id: \.self) { style in
                                                Text(stylePreviewText(style, for: token.token)).tag(style)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 120)
                                    }

                                    Spacer(minLength: 0)

                                    movementButtons(for: token)
                                }
                            }
                        }
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

    private var usesCompactLayout: Bool {
        availableWidth > 0 && availableWidth < 500
    }

    private var previewText: String {
        let now = Date()
        let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
        let day = try? factory.makeDay(for: now, displayedMonth: now, preferences: store.menuBarPreferences)

        return renderer.render(
            now: now,
            preferences: store.menuBarPreferences,
            supplementalText: MenuBarSupplementalText(
                lunarText: day?.lunarText,
                holidayText: day?.badges.first?.text
            )
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
            let base: [DisplayTokenStyle] = [.numeric, .short, .full]
            return showChinese ? base + [.chineseMonthDay, .chineseFull] : base
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
        }
    }

    private func defaultStyle(for token: DisplayTokenKind) -> DisplayTokenStyle {
        switch token {
        case .date, .time, .weekday, .lunar, .holiday:
            .short
        }
    }

    private func stylePreviewText(_ style: DisplayTokenStyle, for token: DisplayTokenKind) -> String {
        let now = Date()
        let factory = CalendarDayFactory(calendar: .autoupdatingCurrent, registry: .live)
        let day = try? factory.makeDay(for: now, displayedMonth: now, preferences: store.menuBarPreferences)

        switch token {
        case .date:
            return renderer.renderPreview(token: token, style: style, now: now)
        case .time:
            return renderer.renderPreview(token: token, style: style, now: now)
        case .weekday:
            return renderer.renderPreview(token: token, style: style, now: now)
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
            return day?.badges.first?.text ?? "节假日"
        }
    }

    private func tokenDisplayName(_ token: DisplayTokenKind) -> String {
        switch token {
        case .date:
            "日期"
        case .time:
            "时间"
        case .weekday:
            "星期"
        case .lunar:
            "农历"
        case .holiday:
            "节假日"
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
