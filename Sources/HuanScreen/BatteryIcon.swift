import AppKit

enum BatteryIcon {
    static let lowThreshold = 20

    static func label(level: Int, isCharging: Bool) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let text = isCharging ? localized(" %ld%% (charging)", level) : localized(" %ld%%", level)
        let label = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.disabledControlTextColor])
        guard let image = image(level: level, isCharging: isCharging) else { return label }

        let attachment = NSTextAttachment()
        attachment.image = image
        let height = font.capHeight + 2
        attachment.bounds = NSRect(x: 0, y: (font.capHeight - height) / 2, width: height * image.size.width / image.size.height, height: height)
        label.insert(NSAttributedString(attachment: attachment), at: 0)
        return label
    }

    static func image(level: Int, isCharging: Bool) -> NSImage? {
        let fillColor: NSColor = level <= lowThreshold ? .systemRed : .systemGreen
        let configuration: NSImage.SymbolConfiguration = isCharging ? .preferringMulticolor() : .init(paletteColors: [fillColor, .labelColor])
        return NSImage(systemSymbolName: symbolName(level: level, isCharging: isCharging), accessibilityDescription: localized("Battery %ld%%", level))?
            .withSymbolConfiguration(configuration)
    }

    private static func symbolName(level: Int, isCharging: Bool) -> String {
        if isCharging { return "battery.100percent.bolt" }
        return switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
