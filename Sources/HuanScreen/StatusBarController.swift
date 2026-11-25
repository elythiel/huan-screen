import AppKit
import ServiceManagement

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let refreshInterval: TimeInterval = 15

    private let receiver: Receiver
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var mode: ScreenMode?
    private var refreshTimer: Timer?

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

        let header = NSMenuItem(title: receiver.isConnected ? "HUAN receiver connected" : "HUAN receiver not found", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
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
