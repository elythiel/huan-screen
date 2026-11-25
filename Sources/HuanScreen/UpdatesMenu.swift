import AppKit

@MainActor
final class UpdatesMenu: NSObject {
    let item = NSMenuItem(title: localized("Updates"), action: nil, keyEquivalent: "")

    private let updates: UpdateController
    private let firmware: FirmwareController
    private let firmwareRows: FirmwareRows
    private let versionRow = MenuRowView(title: "")
    private let updateRow = MenuRowView(title: "", symbol: "arrow.down.circle", closesMenu: true)
    private let checkRow = MenuRowView(title: "", symbol: "arrow.clockwise")
    private let githubRow = MenuRowView(title: localized("View on GitHub"), symbol: "chevron.left.forwardslash.chevron.right", closesMenu: true)
    private let versionItem = NSMenuItem()
    private let updateItem = NSMenuItem()
    private let checkItem = NSMenuItem()
    private let githubItem = NSMenuItem()

    init(updates: UpdateController, firmware: FirmwareController) {
        self.updates = updates
        self.firmware = firmware
        firmwareRows = FirmwareRows(firmware: firmware)
        super.init()

        updateRow.action = { [weak self] in self?.updates.install() }
        checkRow.action = { [weak self] in self?.updates.check() }
        githubRow.action = { NSWorkspace.shared.open(UpdateChecker.repositoryURL) }

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for (menuItem, row) in [(versionItem, versionRow), (updateItem, updateRow), (checkItem, checkRow), (githubItem, githubRow)] {
            menuItem.view = row
        }
        versionItem.isEnabled = false
        for menuItem in [versionItem, updateItem, checkItem] + firmwareRows.items + [.separator(), githubItem] {
            submenu.addItem(menuItem)
        }
        let width = (longestTitles + firmwareRows.longestTitles).map(MenuRowView.preferredWidth).max() ?? 0
        for menuItem in submenu.items { menuItem.view?.frame.size.width = width }

        item.submenu = submenu
        item.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: localized("Updates"))
        update()
    }

    func update() {
        let hasUpdate = updates.availableUpdate != nil || firmware.status?.isUpdateAvailable == true
        item.title = hasUpdate ? localized("Updates — update available") : localized("Updates")
        versionRow.title = versionTitle

        switch updates.state {
        case let .available(update):
            updateRow.title = localized("Update to v%@", update.version)
            updateItem.isHidden = false
            updateItem.isEnabled = true
        case let .installing(update):
            updateRow.title = localized("Installing v%@…", update.version)
            updateItem.isHidden = false
            updateItem.isEnabled = false
        default:
            updateItem.isHidden = true
        }

        checkRow.title = updates.state == .checking ? localized("Checking for Updates…") : localized("Check for Updates")
        checkItem.isEnabled = !isBusy
        for row in [versionRow, updateRow, checkRow] { row.needsDisplay = true }
        firmwareRows.update()
    }

    private var longestTitles: [String] {
        let version = UpdateChecker.currentVersion
        return [
            localized("Version %@ — couldn't check for updates", version),
            localized("Version %@ — up to date", version),
            localized("Installing v%@…", "00.00.00"),
            localized("Update to v%@", "00.00.00"),
            localized("Checking for Updates…"),
            localized("View on GitHub"),
        ]
    }

    private var versionTitle: String {
        let version = UpdateChecker.currentVersion
        return switch updates.state {
        case .unknown, .available, .installing: localized("Version %@", version)
        case .checking: localized("Version %@ — checking…", version)
        case .upToDate: localized("Version %@ — up to date", version)
        case .failed: localized("Version %@ — couldn't check for updates", version)
        }
    }

    private var isBusy: Bool {
        switch updates.state {
        case .checking, .installing: true
        default: firmware.state == .checking
        }
    }
}
