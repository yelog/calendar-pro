import Combine
import XCTest
@testable import CalendarPro

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testMenuBarSchedulerUsesMinuteGranularityByDefault() {
        let store = makeStore(name: #function)
        let viewModel = makeViewModel(store: store)

        XCTAssertEqual(viewModel.refreshGranularity, .minute)
    }

    func testMenuBarSchedulerUsesSecondGranularityWhenStyleIsFull() async {
        let store = makeStore(name: #function)
        let viewModel = makeViewModel(store: store)

        store.setTokenStyle(.full, for: .time)
        await Task.yield()

        XCTAssertEqual(viewModel.refreshGranularity, .second)
    }

    func testLocaleChangeNotificationRerendersDisplayText() async {
        let store = makeStore(name: #function)
        let notificationCenter = NotificationCenter()
        let localeBox = MutableBox(Locale(identifier: "en_US_POSIX"))
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { localeBox.value },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: notificationCenter
        )

        let initialText = viewModel.displayText
        localeBox.value = Locale(identifier: "zh_CN")
        notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        await Task.yield()

        XCTAssertNotEqual(viewModel.displayText, initialText)
    }

    func testLocaleChangeNotificationPostedOffMainThreadRerendersDisplayText() async {
        let store = makeStore(name: #function)
        let notificationCenter = NotificationCenter()
        let localeBox = MutableBox(Locale(identifier: "en_US_POSIX"))
        let viewModel = MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { localeBox.value },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: notificationCenter
        )

        let initialText = viewModel.displayText
        let rerendered = expectation(description: "display text rerendered after off-main locale change")
        var cancellable: AnyCancellable?
        cancellable = viewModel.$displayText
            .dropFirst()
            .sink { updatedText in
                if updatedText != initialText {
                    rerendered.fulfill()
                    cancellable?.cancel()
                }
            }

        localeBox.value = Locale(identifier: "zh_CN")
        DispatchQueue.global(qos: .userInitiated).async {
            notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        }

        await fulfillment(of: [rerendered], timeout: 2.0)
        XCTAssertNotEqual(viewModel.displayText, initialText)
        cancellable?.cancel()
    }

    private func makeStore(name: String) -> SettingsStore {
        let userDefaults = UserDefaults(suiteName: name)!
        userDefaults.removePersistentDomain(forName: name)
        return SettingsStore(userDefaults: userDefaults)
    }

    private func makeViewModel(store: SettingsStore) -> MenuBarViewModel {
        MenuBarViewModel(
            settingsStore: store,
            registry: .default,
            now: { Date(timeIntervalSince1970: 0) },
            localeProvider: { Locale(identifier: "en_US_POSIX") },
            calendarProvider: { .gregorianMondayFirst },
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! },
            notificationCenter: NotificationCenter()
        )
    }
}

private final class MutableBox<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
