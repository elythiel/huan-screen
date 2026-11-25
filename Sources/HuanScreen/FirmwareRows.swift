import AppKit

@MainActor
final class FirmwareRows {
    private static let placeholderVersion = "00.00.00.00"

    let items: [NSMenuItem]

    private let firmware: FirmwareController
    private let mouseRow = MenuRowView(title: "")
    private let receiverRow = MenuRowView(title: "")
    private let actionRow = MenuRowView(title: "", symbol: "arrow.up.forward.app", closesMenu: true)
    private let mouseItem = NSMenuItem()
    private let receiverItem = NSMenuItem()
    private let actionItem = NSMenuItem()
    private let separator = NSMenuItem.separator()

    init(firmware: FirmwareController) {
        self.firmware = firmware
        items = [separator, mouseItem, receiverItem, actionItem]
        actionRow.action = { [weak firmware] in firmware?.openHub() }
        for (item, row) in zip([mouseItem, receiverItem, actionItem], [mouseRow, receiverRow, actionRow]) { item.view = row }
        mouseItem.isEnabled = false
        receiverItem.isEnabled = false
    }

    var longestTitles: [String] {
        let version = Self.placeholderVersion
        return [
            localized("Mouse firmware %@ → %@", version, version),
            localized("Receiver firmware %@ → %@", version, version),
            localized("Update in WLMOUSE Hub…"),
            localized("Couldn't check firmware"),
        ]
    }

    func update() {
        let installed = firmware.installed
        let status = firmware.status
        let isVisible = installed.mouse != nil || installed.receiver != nil
        for item in items { item.isHidden = !isVisible }
        guard isVisible else { return }

        let mouse = installed.mouse ?? "—"
        let receiver = installed.receiver ?? "—"
        let latestMouse = status?.isMouseOutdated == true ? status?.latest.mouse : nil
        let latestReceiver = status?.isReceiverOutdated == true ? status?.latest.receiver : nil
        mouseRow.title = latestMouse.map { localized("Mouse firmware %@ → %@", mouse, $0) } ?? localized("Mouse firmware %@", mouse)
        receiverRow.title = latestReceiver.map { localized("Receiver firmware %@ → %@", receiver, $0) } ?? localized("Receiver firmware %@", receiver)

        let isUpdateAvailable = status?.isUpdateAvailable == true
        actionItem.isEnabled = isUpdateAvailable
        actionItem.isHidden = firmware.state == .unknown
        actionRow.title = switch firmware.state {
        case .checked where isUpdateAvailable: localized("Update in WLMOUSE Hub…")
        case .checked: localized("Firmware up to date")
        case .checking: localized("Checking firmware…")
        case .failed: localized("Couldn't check firmware")
        case .unknown: ""
        }
        for row in [mouseRow, receiverRow, actionRow] { row.needsDisplay = true }
    }
}
