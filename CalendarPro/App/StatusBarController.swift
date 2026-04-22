import AppKit
import Combine

private let statusItemAutosaveName = "CalendarProStatusBarItem"

@MainActor
final class StatusBarController {
    private var statusItems: [NSStatusItem] = []
    private var popoverController: PopoverController
    private let menuBarViewModel: MenuBarViewModel
    private let settingsStore: SettingsStore
    private let eventService: EventService
    private let timeRefreshCoordinator = TimeRefreshCoordinator()

    private var cancellables = Set<AnyCancellable>()

    init(settingsStore: SettingsStore, eventService: EventService) {
        self.settingsStore = settingsStore
        self.eventService = eventService
        popoverController = PopoverController(
            settingsStore: settingsStore,
            eventService: eventService,
            timeRefreshCoordinator: timeRefreshCoordinator
        )
        menuBarViewModel = MenuBarViewModel(
            settingsStore: settingsStore,
            timeRefreshCoordinator: timeRefreshCoordinator
        )

        configureStatusItems()
        bindViewModel()
        menuBarViewModel.start()
        
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
            to: button
        )
    }

    private func bindViewModel() {
        Publishers.CombineLatest(
            menuBarViewModel.$displayText,
            settingsStore.$menuBarPreferences
                .map { $0.textStyle }
                .removeDuplicates()
        )
            .receive(on: RunLoop.main)
            .sink { [weak self] text, style in
                guard let self else { return }
                self.statusItems.forEach {
                    if let button = $0.button {
                        self.applyStatusImage(text, style: style, to: button)
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func applyStatusImage(_ text: String, style: MenuBarTextStyle, to button: NSStatusBarButton) {
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

        button.image = image
        button.toolTip = text
        button.setAccessibilityLabel(text)
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
        NSColor(menuBarHex: style.backgroundColorHex) ?? NSColor(menuBarHex: MenuBarTextStyle.defaultBackgroundColorHex) ?? .white
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

private extension NSColor {
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
}
