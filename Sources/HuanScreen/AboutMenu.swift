import AppKit

@MainActor
final class AboutMenu: NSObject, NSMenuDelegate {
    let item = NSMenuItem(title: "About Huan Screen", action: nil, keyEquivalent: "")

    private let updates: UpdateController

    init(updates: UpdateController) {
        self.updates = updates
        super.init()
        let submenu = NSMenu()
        submenu.delegate = self
        submenu.autoenablesItems = false
        item.submenu = submenu
        item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        update()
    }

    func update() {
        item.title = updates.availableUpdate == nil ? "About Huan Screen" : "About Huan Screen — update available"
        if let submenu = item.submenu { menuNeedsUpdate(submenu) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabledItem(versionTitle))

        if case let .available(update) = updates.state {
            menu.addItem(actionItem("Update to v\(update.version)", symbol: "arrow.down.circle", action: #selector(installUpdate)))
        }
        if case let .installing(update) = updates.state {
            menu.addItem(disabledItem("Installing v\(update.version)…"))
        }

        let check = actionItem("Check for Updates", symbol: "arrow.clockwise", action: #selector(checkForUpdates))
        check.isEnabled = !isBusy
        menu.addItem(check)
        menu.addItem(.separator())
        menu.addItem(actionItem("View on GitHub", symbol: "safari", action: #selector(openRepository)))
    }

    private var versionTitle: String {
        let version = "Version \(UpdateChecker.currentVersion)"
        return switch updates.state {
        case .unknown, .available, .installing: version
        case .checking: "\(version) — checking…"
        case .upToDate: "\(version) — up to date"
        case .failed: "\(version) — couldn't check for updates"
        }
    }

    private var isBusy: Bool {
        switch updates.state {
        case .checking, .installing: true
        default: false
        }
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, symbol: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    @objc private func checkForUpdates() { updates.check() }

    @objc private func installUpdate() { updates.install() }

    @objc private func openRepository() { NSWorkspace.shared.open(UpdateChecker.repositoryURL) }
}
