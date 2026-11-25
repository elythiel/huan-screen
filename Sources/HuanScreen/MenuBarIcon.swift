import AppKit

enum MenuBarIcon {
    private static let catSymbol = "cat.fill"
    private static let boltSymbol = "bolt.fill"
    private static var boltConfiguration: NSImage.SymbolConfiguration { .init(pointSize: 10, weight: .semibold) }
    private static let gap: CGFloat = 2

    static func image(isCharging: Bool) -> NSImage? {
        guard let cat = NSImage(systemSymbolName: catSymbol, accessibilityDescription: "Huan Screen") else { return nil }
        guard isCharging,
              let bolt = NSImage(systemSymbolName: boltSymbol, accessibilityDescription: localized("Charging"))?
                  .withSymbolConfiguration(boltConfiguration)
        else { return template(cat) }

        let size = NSSize(width: cat.size.width + gap + bolt.size.width, height: max(cat.size.height, bolt.size.height))
        let image = NSImage(size: size, flipped: false) { _ in
            cat.draw(in: NSRect(x: 0, y: (size.height - cat.size.height) / 2, width: cat.size.width, height: cat.size.height))
            let boltOrigin = NSPoint(x: cat.size.width + gap, y: (size.height - bolt.size.height) / 2)
            bolt.draw(in: NSRect(origin: boltOrigin, size: bolt.size))
            return true
        }
        image.accessibilityDescription = localized("Charging")
        return template(image)
    }

    private static func template(_ image: NSImage) -> NSImage {
        image.isTemplate = true
        return image
    }
}
