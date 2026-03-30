import SwiftUI

struct MenuBarSettingsView: View {
    @ObservedObject var store: SettingsStore

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
                        HStack {
                            Text("分隔符")
                            Spacer()
                            TextField("空格", text: separatorBinding)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        Toggle("时间显示秒", isOn: timeShowsSecondsBinding)
                    }
                }

                GroupBox("显示项") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedTokens) { token in
                            HStack(spacing: 12) {
                                Toggle(tokenDisplayName(token.token), isOn: enabledBinding(for: token.token))
                                    .toggleStyle(.checkbox)
                                    .frame(width: 120, alignment: .leading)

                                Picker("样式", selection: styleBinding(for: token.token)) {
                                    ForEach(styleOptions(for: token.token), id: \.self) { style in
                                        Text(styleDisplayName(style)).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 120)

                                Spacer()

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
                }
            }
            .padding(20)
        }
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

    private var timeShowsSecondsBinding: Binding<Bool> {
        Binding(
            get: {
                store.menuBarPreferences.tokens.first(where: { $0.token == .time })?.showsSeconds ?? false
            },
            set: { store.setTimeShowsSeconds($0) }
        )
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
        switch token {
        case .date:
            [.numeric, .short, .full, .chineseMonthDay]
        case .weekday:
            [.short, .full, .chineseWeekday]
        case .time, .lunar, .holiday:
            [.numeric, .short, .full]
        }
    }

    private func defaultStyle(for token: DisplayTokenKind) -> DisplayTokenStyle {
        switch token {
        case .date, .time, .weekday, .lunar, .holiday:
            .short
        }
    }

    private func styleDisplayName(_ style: DisplayTokenStyle) -> String {
        switch style {
        case .numeric:
            "数字"
        case .short:
            "简写"
        case .full:
            "完整"
        case .chineseMonthDay:
            "中文月日"
        case .chineseWeekday:
            "中文周"
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
}
