import SwiftUI

struct VacationGuideScrollTargetResolver {
    let calendar: Calendar
    let preferredMonth: Int

    func targetOpportunity(in opportunities: [VacationOpportunity], displayedYear: Int) -> VacationOpportunity? {
        guard !opportunities.isEmpty else {
            return nil
        }

        guard let monthInterval = monthInterval(for: displayedYear) else {
            return opportunities.first
        }

        if let currentMonthMatch = opportunities.first(where: { opportunity in
            opportunity.endDate >= monthInterval.start && opportunity.startDate < monthInterval.end
        }) {
            return currentMonthMatch
        }

        if let nextOpportunity = opportunities.first(where: { $0.startDate >= monthInterval.end }) {
            return nextOpportunity
        }

        return opportunities.last
    }

    private func monthInterval(for year: Int) -> DateInterval? {
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: preferredMonth, day: 1)) else {
            return nil
        }

        return calendar.dateInterval(of: .month, for: monthStart)
    }
}

struct VacationGuideWindowView: View {
    private enum ContentState {
        case list([VacationOpportunity])
        case message(title: String, detail: String)
    }

    @ObservedObject var settingsStore: SettingsStore
    let cacheStore: HolidayCacheStore
    let onLocateDate: (Date) -> Void
    let onClose: () -> Void

    @State private var displayedYear: Int
    @State private var containerHeight: CGFloat = 0
    @State private var listViewportHeight: CGFloat = 0
    @State private var listContentHeight: CGFloat = 0
    @State private var lastReportedPreferredHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private let planningService: VacationPlanningService
    private let onPreferredHeightChange: ((CGFloat) -> Void)?
    private let scrollTargetResolver: VacationGuideScrollTargetResolver

    init(
        settingsStore: SettingsStore,
        referenceMonth: Date,
        cacheStore: HolidayCacheStore = .default,
        planningService: VacationPlanningService = VacationPlanningService(),
        onLocateDate: @escaping (Date) -> Void,
        onClose: @escaping () -> Void,
        onPreferredHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        let scrollCalendar = Calendar.autoupdatingCurrent

        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.planningService = planningService
        self.onLocateDate = onLocateDate
        self.onClose = onClose
        self.onPreferredHeightChange = onPreferredHeightChange
        self.scrollTargetResolver = VacationGuideScrollTargetResolver(
            calendar: scrollCalendar,
            preferredMonth: scrollCalendar.component(.month, from: referenceMonth)
        )
        _displayedYear = State(initialValue: scrollCalendar.component(.year, from: referenceMonth))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if showsAdjustmentWarning {
                warningBanner
            }

            content

            footer
        }
        .padding(PopoverSurfaceMetrics.outerPadding)
        .frame(width: 460, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(surfaceBackground)
        .background(
            HeightReporter { height in
                containerHeight = height
                reportPreferredHeightIfNeeded()
            }
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("休假建议")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Text("基于当前节假日与调休数据生成")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                yearButton(systemImage: "chevron.left", action: { displayedYear -= 1 })

                Text("\(displayedYear)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(minWidth: 56)

                yearButton(systemImage: "chevron.right", action: { displayedYear += 1 })
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch contentState {
        case let .list(opportunities):
            opportunityList(opportunities)

        case let .message(title, detail):
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Text(detail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PopoverSurfaceMetrics.elevatedCardFillColor(for: colorScheme))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(PopoverSurfaceMetrics.elevatedCardBorderColor(for: colorScheme), lineWidth: 0.8)
            }
        }
    }

    private func opportunityList(_ opportunities: [VacationOpportunity]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(opportunities) { opportunity in
                        VacationOpportunityCardView(opportunity: opportunity) { date in
                            onLocateDate(date)
                        }
                        .id(opportunity.id)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .background(
                    HeightReporter { height in
                        listContentHeight = height
                        reportPreferredHeightIfNeeded()
                    }
                )
            }
            .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .top)
            .task(id: scrollTaskKey(for: opportunities)) {
                await scrollToPreferredOpportunity(in: opportunities, proxy: proxy)
            }
            .background(
                HeightReporter { height in
                    listViewportHeight = height
                    reportPreferredHeightIfNeeded()
                }
            )
        }
    }

    private var footer: some View {
        Text(dataStatusText)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func yearButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }

    private var warningBanner: some View {
        Text("当前未启用调休上班日，推荐结果可能不完整。")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.12))
            }
    }

    private var contentState: ContentState {
        guard LocaleFeatureAvailability.showVacationGuideFeatures else {
            return .message(
                title: "当前语言下暂不显示休假建议",
                detail: "休假建议 V1 仅面向中文场景下的中国大陆节假日规则。"
            )
        }

        let preferences = settingsStore.menuBarPreferences

        guard preferences.activeRegionIDs.contains("mainland-cn") else {
            return .message(
                title: "未启用中国大陆地区",
                detail: "请先在“地区与节假日”中启用中国大陆，再查看休假建议。"
            )
        }

        guard isHolidaySetEnabled("statutory-holidays", in: preferences) else {
            return .message(
                title: "法定节假日未启用",
                detail: "休假建议依赖法定节假日数据，请先在地区设置中启用。"
            )
        }

        do {
            let opportunities = try planningService.opportunities(
                forYear: displayedYear,
                activeRegionIDs: preferences.activeRegionIDs,
                enabledHolidaySetIDs: preferences.enabledHolidayIDs
            )

            guard !opportunities.isEmpty else {
                return .message(
                    title: "当年放假安排尚未发布",
                    detail: "当前没有可用的节假日数据，休假建议会在数据可用后自动生成。"
                )
            }

            return .list(opportunities)
        } catch {
            return .message(
                title: "休假建议暂时无法生成",
                detail: "请稍后重试，或先检查当前节假日数据是否可用。"
            )
        }
    }

    private var showsAdjustmentWarning: Bool {
        let preferences = settingsStore.menuBarPreferences
        return preferences.activeRegionIDs.contains("mainland-cn")
            && !isHolidaySetEnabled("adjustment-workdays", in: preferences)
    }

    private var dataStatusText: String {
        if
            let manifest = try? cacheStore.cachedManifest(),
            manifest.payloads.contains(where: { $0.regionID == "mainland-cn" && $0.year == displayedYear })
        {
            return "基于缓存节假日数据 v\(manifest.version) 生成"
        }

        return "基于内置节假日数据生成"
    }

    private func isHolidaySetEnabled(_ holidaySetID: String, in preferences: MenuBarPreferences) -> Bool {
        preferences.enabledHolidayIDs.isEmpty || preferences.enabledHolidayIDs.contains(holidaySetID)
    }

    private func scrollTaskKey(for opportunities: [VacationOpportunity]) -> String {
        let opportunityIDs = opportunities.map(\.id).joined(separator: "|")
        return "\(displayedYear)-\(opportunityIDs)"
    }

    @MainActor
    private func scrollToPreferredOpportunity(
        in opportunities: [VacationOpportunity],
        proxy: ScrollViewProxy
    ) async {
        guard let target = scrollTargetResolver.targetOpportunity(in: opportunities, displayedYear: displayedYear) else {
            return
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(target.id, anchor: .top)
        }
    }

    private func reportPreferredHeightIfNeeded() {
        guard case .list = contentState else { return }
        guard containerHeight > 0, listViewportHeight > 0, listContentHeight > 0 else { return }

        let preferredHeight = containerHeight - listViewportHeight + listContentHeight
        guard abs(preferredHeight - lastReportedPreferredHeight) > 1 else { return }

        lastReportedPreferredHeight = preferredHeight
        onPreferredHeightChange?(preferredHeight)
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
            .fill(PopoverSurfaceMetrics.floatingPanelBaseFill(for: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .fill(PopoverSurfaceMetrics.floatingPanelTintOverlay(accent: .accentColor, for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PopoverSurfaceMetrics.cornerRadius, style: .continuous)
                    .stroke(PopoverSurfaceMetrics.floatingPanelBorderColor(for: colorScheme), lineWidth: 1)
            )
    }
}

private struct HeightReporter: View {
    let onChange: (CGFloat) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    report(proxy.size.height)
                }
                .onChange(of: proxy.size.height) { _, newValue in
                    report(newValue)
                }
        }
        .allowsHitTesting(false)
    }

    private func report(_ height: CGFloat) {
        DispatchQueue.main.async {
            onChange(height)
        }
    }
}
