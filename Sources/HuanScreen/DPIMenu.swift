import AppKit

@MainActor
final class DPIMenu: NSObject, NSMenuDelegate {
    var mouseInfo: () -> MouseInfo?
    var onSelect: (Int) -> Void

    let item = NSMenuItem(title: "DPI", action: nil, keyEquivalent: "")
    let separator = NSMenuItem.separator()

    init(mouseInfo: @escaping () -> MouseInfo?, onSelect: @escaping (Int) -> Void) {
        self.mouseInfo = mouseInfo
        self.onSelect = onSelect
        super.init()
        let submenu = NSMenu()
        submenu.delegate = self
        item.submenu = submenu
        item.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "DPI")
        update()
    }

    func update() {
        let info = mouseInfo()
        item.isHidden = info?.dpiStages.isEmpty ?? true
        separator.isHidden = item.isHidden
        item.title = info?.dpi.map { "DPI — \($0)" } ?? "DPI"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let info = mouseInfo() else { return }
        for (index, dpi) in info.dpiStages.enumerated() {
            let stage = index + 1
            let stageItem = NSMenuItem(title: "\(dpi) DPI", action: #selector(select(_:)), keyEquivalent: "")
            stageItem.target = self
            stageItem.tag = stage
            stageItem.state = info.activeDPIStage == stage ? .on : .off
            menu.addItem(stageItem)
        }
    }

    @objc private func select(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}
