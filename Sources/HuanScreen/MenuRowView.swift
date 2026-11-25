import AppKit

@MainActor
final class MenuRowView: NSView {
    private static let height: CGFloat = 24
    private static let highlightInset: CGFloat = 5
    private static let highlightRadius: CGFloat = 6
    private static let imageX: CGFloat = 12
    private static let imageColumnWidth: CGFloat = 20
    private static let textX: CGFloat = 35
    private static let trailingPadding: CGFloat = 20
    private static let font = NSFont.menuFont(ofSize: 0)

    var title: String {
        didSet { needsDisplay = true }
    }

    var action: () -> Void = {}

    private let symbol: String?
    private let closesMenu: Bool

    init(title: String, symbol: String? = nil, closesMenu: Bool = false) {
        self.title = title
        self.symbol = symbol
        self.closesMenu = closesMenu
        super.init(frame: NSRect(x: 0, y: 0, width: Self.preferredWidth(for: title), height: Self.height))
        autoresizingMask = [.width]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    static func preferredWidth(for title: String) -> CGFloat {
        ceil(textX + title.size(withAttributes: [.font: font]).width + trailingPadding)
    }

    override func draw(_ dirtyRect: NSRect) {
        let isEnabled = enclosingMenuItem?.isEnabled ?? false
        let isHighlighted = isEnabled && enclosingMenuItem?.isHighlighted == true

        if isHighlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            let highlight = bounds.insetBy(dx: Self.highlightInset, dy: 0)
            NSBezierPath(roundedRect: highlight, xRadius: Self.highlightRadius, yRadius: Self.highlightRadius).fill()
        }

        let color: NSColor = if !isEnabled { .disabledControlTextColor } else if isHighlighted { .selectedMenuItemTextColor } else { .labelColor }
        drawImage(color: color)
        drawTitle(color: color)
    }

    override func mouseUp(with event: NSEvent) {
        guard enclosingMenuItem?.isEnabled == true else { return }
        action()
        guard closesMenu else { return }
        var menu = enclosingMenuItem?.menu
        while let parent = menu?.supermenu { menu = parent }
        menu?.cancelTracking()
    }

    private func drawTitle(color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: color]
        let size = title.size(withAttributes: attributes)
        title.draw(at: NSPoint(x: Self.textX, y: (bounds.height - size.height) / 2), withAttributes: attributes)
    }

    private func drawImage(color: NSColor) {
        guard let symbol else { return }
        let configuration = NSImage.SymbolConfiguration(pointSize: Self.font.pointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)?.withSymbolConfiguration(configuration) else { return }
        let origin = NSPoint(
            x: Self.imageX + (Self.imageColumnWidth - image.size.width) / 2,
            y: (bounds.height - image.size.height) / 2
        )
        image.draw(in: NSRect(origin: origin, size: image.size))
    }
}
