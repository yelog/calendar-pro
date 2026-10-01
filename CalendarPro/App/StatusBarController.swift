import AppKit
import Combine

private final class StatusIndicatorOverlayView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }
    weak var statusButton: NSStatusBarButton?

    override func layout() {
        super.layout()
        guard let statusButton else { return }
        let imageRect = statusButton.cell?.imageRect(forBounds: statusButton.bounds) ?? statusButton.bounds
        if frame != imageRect {
            frame = imageRect
        }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private let statusItemAutosaveName = "CalendarProStatusBarItem"

@MainActor
final class StatusBarController {
    private var statusItems: [NSStatusItem] = []
    private var popoverController: PopoverController
    private let menuBarViewModel: MenuBarViewModel
    private let upcomingEventMonitor: UpcomingEventMonitor
    private let textImageRenderer = MenuBarTextImageRenderer()
    private let settingsStore: SettingsStore
    private let eventService: EventService
    private let timeRefreshCoordinator = TimeRefreshCoordinator()
    private let pomodoroStatsStore: PomodoroStatsStore
    private let pomodoroReminderService = PomodoroReminderService()
    private let pomodoroTimer: PomodoroTimerController
    private var indicatorOverlayViews: [ObjectIdentifier: StatusIndicatorOverlayView] = [:]

    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore,
        eventService: EventService,
        pomodoroStatsStore: PomodoroStatsStore = PomodoroStatsStore()
    ) {
        self.settingsStore = settingsStore
        self.eventService = eventService
        self.pomodoroStatsStore = pomodoroStatsStore
        pomodoroTimer = PomodoroTimerController(
            statsStore: pomodoroStatsStore,
            reminderService: pomodoroReminderService,
            reminderPreferences: { settingsStore.pomodoroPreferences.reminders }
        )
        popoverController = PopoverController(
            settingsStore: settingsStore,
            eventService: eventService,
            timeRefreshCoordinator: timeRefreshCoordinator,
            pomodoroTimer: pomodoroTimer,
            pomodoroStatsStore: pomodoroStatsStore
        )
        menuBarViewModel = MenuBarViewModel(
            settingsStore: settingsStore,
            timeRefreshCoordinator: timeRefreshCoordinator
        )
        upcomingEventMonitor = UpcomingEventMonitor(
            eventService: eventService,
            settingsStore: settingsStore,
            timeRefreshCoordinator: timeRefreshCoordinator
        )

        configureStatusItems()
        bindViewModel()
        menuBarViewModel.start()
        upcomingEventMonitor.start()
        
        Task {
            await eventService.requestAccess()
            await eventService.requestReminderAccess()
        }
        
        // NOTE: 不监听屏幕变化通知。macOS 会自动处理菜单栏布局，
        // autosaveName 会确保位置持久化。重建 StatusItem 会丢失 window ID
        // 导致 Ice 等菜单栏管理器无法识别同一个 item。
    }
    
    nonisolated deinit {
        // StatusBarController 生命周期与应用相同，由 AppDelegate 持有
        // 应用退出时所有 status items 会自动移除
    }

    private func configureStatusItems() {
        guard statusItems.isEmpty else { return }
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = statusItemAutosaveName
        configureStatusButton(statusItem.button)
        statusItems.append(statusItem)
    }
    
    private func configureStatusButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        // 默认使用模板图片；自定义颜色或填充背景时切换为彩色图片。
        button.imagePosition = .imageOnly
        applyStatusImage(
            menuBarViewModel.displayText,
            style: settingsStore.menuBarPreferences.textStyle,
            indicator: nil,
            to: button
        )
    }

    private func bindViewModel() {
        let menuBarStylePublisher = settingsStore.$menuBarPreferences
            .map { $0.textStyle }
            .removeDuplicates()

        Publishers.CombineLatest(
            Publishers.CombineLatest4(
                menuBarViewModel.$displayText,
                menuBarStylePublisher,
                upcomingEventMonitor.$activeIndicator,
                pomodoroTimer.$state
            ),
            settingsStore.$pomodoroPreferences.removeDuplicates()
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] combined, pomodoroPreferences in
                guard let self else { return }
                let (text, style, indicator, pomodoroState) = combined
                let displayText = self.displayText(text, pomodoroState: pomodoroState, pomodoroPreferences: pomodoroPreferences)
                self.statusItems.forEach {
                    if let button = $0.button {
                        self.applyStatusImage(
                            displayText,
                            style: style,
                            indicator: indicator,
                            pomodoroState: pomodoroState,
                            pomodoroPreferences: pomodoroPreferences,
                            to: button
                        )
                    }
                }
            }
            .store(in: &cancellables)

        settingsStore.$pomodoroPreferences
            .map(\.isEnabled)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] isEnabled in
                if !isEnabled {
                    self?.pomodoroTimer.end()
                }
            }
            .store(in: &cancellables)
    }

    private func displayText(
        _ text: String,
        pomodoroState: PomodoroTimerController.State,
        pomodoroPreferences: PomodoroPreferences
    ) -> String {
        guard let suffix = PomodoroMenuBarFormatter.suffix(for: pomodoroState, preferences: pomodoroPreferences) else { return text }
        return "\(text)  \(suffix)"
    }

    private func applyStatusImage(
        _ text: String,
        style: MenuBarTextStyle,
        indicator: MenuBarEventIndicator?,
        pomodoroState: PomodoroTimerController.State = .idle,
        pomodoroPreferences: PomodoroPreferences = .default,
        to button: NSStatusBarButton
    ) {
        let renderResult = textImageRenderer.render(text: text, style: style, indicator: indicator)
        button.image = renderResult.image
        applyIndicatorOverlay(renderResult.indicatorOverlayImage, to: button)
        let tooltip = tooltipText(
            text: text,
            indicator: indicator,
            pomodoroState: pomodoroState,
            pomodoroPreferences: pomodoroPreferences
        )
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private func applyIndicatorOverlay(_ image: NSImage?, to button: NSStatusBarButton) {
        let key = ObjectIdentifier(button)
        guard let image else {
            indicatorOverlayViews.removeValue(forKey: key)?.removeFromSuperview()
            return
        }

        let overlay = indicatorOverlayViews[key] ?? {
            let view = StatusIndicatorOverlayView(frame: .zero)
            view.statusButton = button
            button.addSubview(view)
            indicatorOverlayViews[key] = view
            return view
        }()

        overlay.image = image
        overlay.frame = button.cell?.imageRect(forBounds: button.bounds) ?? button.bounds
    }

    private func tooltipText(
        text: String,
        indicator: MenuBarEventIndicator?,
        pomodoroState: PomodoroTimerController.State,
        pomodoroPreferences: PomodoroPreferences
    ) -> String {
        var lines: [String] = []
        if let indicator {
            lines.append(indicator.tooltipText)
        }
        if pomodoroPreferences.isEnabled,
           let pomodoroTooltip = PomodoroMenuBarFormatter.tooltip(for: pomodoroState) {
            lines.append(pomodoroTooltip)
        }
        lines.append(text)
        return lines.joined(separator: "\n")
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = sender as? NSStatusBarButton else { return }
        popoverController.toggle(relativeTo: button)
    }

    func popoverContentWindow() -> NSWindow? {
        popoverController.popoverContentWindow()
    }
}
