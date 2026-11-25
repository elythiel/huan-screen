import AppKit
import ServiceManagement

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let refreshInterval: TimeInterval = 15
    private static let catSymbol = "cat.fill"
    private static let statusSymbol = "gauge.with.dots.needle.67percent"

    private let receiver: Receiver
    private let lowBatteryNotifier = LowBatteryNotifier()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var mode: ScreenMode?
    private var mouseInfo: MouseInfo?
    private var isReadingMouse = false
    private var refreshTimer: Timer?
    private weak var batteryItem: NSMenuItem?
    private weak var specsItem: NSMenuItem?
    private var dpiMenu: DPIMenu?

    init(receiver: Receiver) {
        self.receiver = receiver
        super.init()

        receiver.onConnectionChange = { [weak self] in self?.refresh() }
        receiver.watchConnections()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu)
        statusItem.button?.sendAction(on: [.leftMouseDown])

        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    private func apply(_ target: ScreenMode) {
        receiver.setMode(target)
        refresh()
    }

    private func refresh() {
        mode = receiver.mode
        updateButton()
        refreshMouseInfo()
    }

    private func refreshMouseInfo() {
        guard receiver.isConnected else {
            mouseInfo = nil
            return updateMouseItems()
        }
        guard !isReadingMouse else { return }
        isReadingMouse = true
        Task {
            if let info = await receiver.readMouseInfo() {
                mouseInfo = info
                lowBatteryNotifier.update(with: info)
            }
            isReadingMouse = false
            updateMouseItems()
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        button.image = symbolImage(Self.catSymbol, label: "Huan Screen")
        button.appearsDisabled = mode == nil
        button.toolTip = switch mode {
        case .cat: "Cat mode"
        case .status: "Status mode"
        case nil: "Receiver not found"
        }
    }

    private func symbolImage(_ name: String, label: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        return image
    }

    @objc private func showMenu() {
        refresh()
        statusItem.menu = buildMenu()
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        addHeader(to: menu)
        menu.addItem(.separator())

        menu.addItem(modeItem(title: "Cat mode", mode: .cat, symbol: Self.catSymbol, action: #selector(selectCat)))
        menu.addItem(modeItem(title: "Status mode", mode: .status, symbol: Self.statusSymbol, action: #selector(selectStatus)))
        menu.addItem(.separator())

        let dpiMenu = DPIMenu(mouseInfo: { [weak self] in self?.mouseInfo }, onSelect: { [weak self] in self?.selectDPIStage($0) })
        self.dpiMenu = dpiMenu
        menu.addItem(dpiMenu.item)
        menu.addItem(dpiMenu.separator)

        let login = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Huan Screen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func addHeader(to menu: NSMenu) {
        guard receiver.isConnected else { return menu.addItem(infoItem("HUAN receiver not found")) }
        let battery = infoItem("")
        let specs = infoItem("")
        menu.addItem(battery)
        menu.addItem(specs)
        batteryItem = battery
        specsItem = specs
        updateMouseItems()
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func selectDPIStage(_ stage: Int) {
        guard var info = mouseInfo, receiver.selectDPIStage(stage, profile: info.profile) else { return }
        info.activeDPIStage = stage
        mouseInfo = info
        updateMouseItems()
    }

    private func updateMouseItems() {
        dpiMenu?.update()
        guard let batteryItem, let specsItem else { return }
        guard let mouseInfo else {
            batteryItem.attributedTitle = nil
            batteryItem.title = isReadingMouse ? "Reading mouse…" : "Mouse not responding"
            specsItem.isHidden = true
            return
        }
        batteryItem.attributedTitle = BatteryIcon.label(level: mouseInfo.batteryLevel, isCharging: mouseInfo.isCharging)
        specsItem.title = mouseInfo.specsDescription
        specsItem.isHidden = mouseInfo.specsDescription.isEmpty
    }

    private func modeItem(title: String, mode itemMode: ScreenMode, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: receiver.isConnected ? action : nil, keyEquivalent: "")
        item.target = self
        item.image = symbolImage(symbol, label: title)
        item.state = mode == itemMode ? .on : .off
        return item
    }

    @objc private func selectCat() { apply(.cat) }

    @objc private func selectStatus() { apply(.status) }

    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
