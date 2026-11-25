import AppKit
import ServiceManagement

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let refreshInterval: TimeInterval = 15
    private static let catSymbol = "cat.fill"
    private static let statusSymbol = "gauge.with.dots.needle.67percent"

    private let receiver: Receiver
    private let lowBatteryNotifier = LowBatteryNotifier()
    private let updates = UpdateController()
    private let firmware: FirmwareController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var mode: ScreenMode?
    private var mouseInfo: MouseInfo?
    private var isReadingMouse = false
    private var refreshTimer: Timer?
    private weak var batteryItem: NSMenuItem?
    private var mouseSettings: MouseSettingsMenus?
    private var updatesMenu: UpdatesMenu?

    init(receiver: Receiver) {
        self.receiver = receiver
        firmware = FirmwareController(receiver: receiver)
        super.init()

        receiver.onConnectionChange = { [weak self] in self?.refresh() }
        receiver.watchConnections()

        updates.onChange = { [weak self] in self?.updatesMenu?.update() }
        updates.onCheck = { [weak self] notify in self?.firmware.check(notify: notify) }
        firmware.onChange = { [weak self] in self?.updatesMenu?.update() }
        updates.start()

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
        if !firmware.isInstalledKnown { firmware.refreshInstalled() }
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
        case .cat: localized("Cat mode")
        case .status: localized("Status mode")
        case nil: localized("Receiver not found")
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

        menu.addItem(modeItem(title: localized("Cat mode"), mode: .cat, symbol: Self.catSymbol, action: #selector(selectCat)))
        menu.addItem(modeItem(title: localized("Status mode"), mode: .status, symbol: Self.statusSymbol, action: #selector(selectStatus)))
        menu.addItem(.separator())

        let mouseSettings = MouseSettingsMenus(
            receiver: receiver,
            mouseInfo: { [weak self] in self?.mouseInfo },
            onUpdate: { [weak self] info in
                self?.mouseInfo = info
                self?.updateMouseItems()
            }
        )
        self.mouseSettings = mouseSettings
        for item in mouseSettings.items { menu.addItem(item) }

        let login = NSMenuItem(title: localized("Open at Login"), action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        login.target = self
        login.image = symbolImage("power", label: localized("Open at Login"))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let updatesMenu = UpdatesMenu(updates: updates, firmware: firmware)
        self.updatesMenu = updatesMenu
        menu.addItem(updatesMenu.item)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: localized("Quit Huan Screen"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func addHeader(to menu: NSMenu) {
        guard receiver.isConnected else { return menu.addItem(infoItem(localized("HUAN receiver not found"))) }
        let battery = infoItem("")
        menu.addItem(battery)
        batteryItem = battery
        updateMouseItems()
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func updateMouseItems() {
        mouseSettings?.update()
        guard let batteryItem else { return }
        guard let mouseInfo else {
            batteryItem.attributedTitle = nil
            batteryItem.title = isReadingMouse ? localized("Reading mouse…") : localized("Mouse not responding")
            return
        }
        batteryItem.attributedTitle = BatteryIcon.label(level: mouseInfo.batteryLevel, isCharging: mouseInfo.isCharging)
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
