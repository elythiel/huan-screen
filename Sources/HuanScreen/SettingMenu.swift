import AppKit

struct SettingOption {
    let title: String
    let value: Int
    let isSelected: Bool
}

@MainActor
final class SettingMenu: NSObject, NSMenuDelegate {
    let item: NSMenuItem

    private let name: String
    private let currentValue: () -> String?
    private let options: () -> [SettingOption]
    private let onSelect: (Int) -> Void

    init(
        name: String,
        symbol: String,
        currentValue: @escaping () -> String?,
        options: @escaping () -> [SettingOption],
        onSelect: @escaping (Int) -> Void
    ) {
        self.name = name
        self.currentValue = currentValue
        self.options = options
        self.onSelect = onSelect
        item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        super.init()
        let submenu = NSMenu()
        submenu.delegate = self
        item.submenu = submenu
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: name)
        update()
    }

    func update() {
        item.isHidden = options().isEmpty
        item.title = currentValue().map { localized("%@: %@", name, $0) } ?? name
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for option in options() {
            let optionItem = NSMenuItem(title: option.title, action: #selector(select(_:)), keyEquivalent: "")
            optionItem.target = self
            optionItem.tag = option.value
            optionItem.state = option.isSelected ? .on : .off
            menu.addItem(optionItem)
        }
    }

    @objc private func select(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}
