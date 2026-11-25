import AppKit

@MainActor
final class AboutMenu: NSObject {
    let item = NSMenuItem(title: "About Huan Screen", action: nil, keyEquivalent: "")

    private let updates: UpdateController
    private let versionRow = MenuRowView(title: "")
    private let updateRow = MenuRowView(title: "", symbol: "arrow.down.circle", closesMenu: true)
    private let checkRow = MenuRowView(title: "", symbol: "arrow.clockwise")
    private let githubRow = MenuRowView(title: "View on GitHub", symbol: "chevron.left.forwardslash.chevron.right", closesMenu: true)
    private let versionItem = NSMenuItem()
    private let updateItem = NSMenuItem()
    private let checkItem = NSMenuItem()
    private let githubItem = NSMenuItem()

    init(updates: UpdateController) {
        self.updates = updates
        super.init()

        updateRow.action = { [weak self] in self?.updates.install() }
        checkRow.action = { [weak self] in self?.updates.check() }
        githubRow.action = { NSWorkspace.shared.open(UpdateChecker.repositoryURL) }

        let width = longestTitles.map(MenuRowView.preferredWidth).max() ?? 0
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for (menuItem, row) in [(versionItem, versionRow), (updateItem, updateRow), (checkItem, checkRow), (githubItem, githubRow)] {
            row.frame.size.width = width
            menuItem.view = row
            if menuItem === githubItem { submenu.addItem(.separator()) }
            submenu.addItem(menuItem)
        }
        versionItem.isEnabled = false

        item.submenu = submenu
        item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About")
        update()
    }

    func update() {
        item.title = updates.availableUpdate == nil ? "About Huan Screen" : "About Huan Screen — update available"
        versionRow.title = versionTitle

        switch updates.state {
        case let .available(update):
            updateRow.title = "Update to v\(update.version)"
            updateItem.isHidden = false
            updateItem.isEnabled = true
        case let .installing(update):
            updateRow.title = "Installing v\(update.version)…"
            updateItem.isHidden = false
            updateItem.isEnabled = false
        default:
            updateItem.isHidden = true
        }

        checkRow.title = updates.state == .checking ? "Checking for Updates…" : "Check for Updates"
        checkItem.isEnabled = !isBusy
        for row in [versionRow, updateRow, checkRow] { row.needsDisplay = true }
    }

    private var longestTitles: [String] {
        let version = "Version \(UpdateChecker.currentVersion)"
        return ["\(version) — couldn't check for updates", "Installing v00.00.00…", "Checking for Updates…", "View on GitHub"]
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
}
