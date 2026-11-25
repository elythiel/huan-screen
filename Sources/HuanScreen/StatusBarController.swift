import AppKit
import ServiceManagement

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let refreshInterval: TimeInterval = 15

    private let receiver: Receiver
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var mode: ScreenMode?
    private var mouseInfo: MouseInfo?
    private var isReadingMouse = false
    private var refreshTimer: Timer?
    private weak var batteryItem: NSMenuItem?
    private weak var specsItem: NSMenuItem?

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
            if let info = await receiver.readMouseInfo() { mouseInfo = info }
            isReadingMouse = false
            updateMouseItems()
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let (symbol, label) = switch mode {
        case .cat: ("cat.fill", "Cat mode")
        case .status: ("gauge.with.dots.needle.67percent", "Status mode")
        case nil: ("computermouse", "Receiver not found")
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = mode == nil
        button.toolTip = label
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

        menu.addItem(modeItem(title: "Cat mode", mode: .cat, action: #selector(selectCat)))
        menu.addItem(modeItem(title: "Status mode", mode: .status, action: #selector(selectStatus)))
        menu.addItem(.separator())

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

    private func updateMouseItems() {
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

    private func modeItem(title: String, mode itemMode: ScreenMode, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: receiver.isConnected ? action : nil, keyEquivalent: "")
        item.target = self
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
