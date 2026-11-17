import AppKit

enum MenuBarIcon {
    /// The Paper Stack artwork, with transparent cutouts for macOS template tinting.
    static func paperStack() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: 20 / 96, y: 20 / 96)
            context.translateBy(x: -16, y: -12)
            context.setStrokeColor(CGColor.black)
            context.setFillColor(CGColor.black)
            context.setLineWidth(5)

            for (index, origin) in [CGPoint(x: 26, y: 48), CGPoint(x: 43, y: 34), CGPoint(x: 60, y: 20)].enumerated() {
                let sheet = CGPath(roundedRect: CGRect(origin: origin, size: CGSize(width: 43, height: 53)),
                                   cornerWidth: 6, cornerHeight: 6, transform: nil)
                context.setBlendMode(.clear)
                context.addPath(sheet)
                context.fillPath()
                context.setBlendMode(.normal)
                context.addPath(sheet)
                context.drawPath(using: index == 2 ? .fill : .stroke)
            }

            context.setBlendMode(.clear)
            context.setLineWidth(3)
            context.setLineCap(.round)
            for (y, endX) in [(35, 90), (45, 84)] {
                context.move(to: CGPoint(x: 72, y: y))
                context.addLine(to: CGPoint(x: endX, y: y))
            }
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Shelferry Paper Stack"
        return image
    }
}
