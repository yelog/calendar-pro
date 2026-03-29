import SwiftUI

struct RootPopoverView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var viewModel = CalendarPopoverViewModel()

    var body: some View {
        CalendarPopoverView(
            displayedMonth: viewModel.displayedMonth,
            weekdaySymbols: viewModel.weekdaySymbols(using: displayCalendar),
            monthDays: monthDays,
            regionSummary: regionSummary,
            onPreviousMonth: {
                viewModel.showPreviousMonth(using: displayCalendar)
            },
            onNextMonth: {
                viewModel.showNextMonth(using: displayCalendar)
            }
        )
    }

    private var displayCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = settingsStore.menuBarPreferences.weekStart == .monday ? 2 : 1
        return calendar
    }

    private var monthService: MonthCalendarService {
        MonthCalendarService(calendar: displayCalendar)
    }

    private var monthDays: [CalendarDay] {
        let factory = CalendarDayFactory(calendar: displayCalendar, registry: .live)
        return (try? factory.makeMonthGrid(
            for: viewModel.displayedMonth,
            preferences: settingsStore.menuBarPreferences
        )) ?? monthService.makeMonthGrid(for: viewModel.displayedMonth)
    }

    private var regionSummary: String {
        let names = settingsStore.menuBarPreferences.activeRegionIDs.compactMap { regionID in
            HolidayProviderRegistry.live.provider(for: regionID)?.descriptor.displayName
        }

        if names.isEmpty {
            return "未启用地区节假日"
        }

        return "地区：\(names.joined(separator: "、"))"
    }
}
