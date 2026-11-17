import AppKit
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let unit = CGFloat(pixels) / 1024
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: unit, y: unit)
        let background = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210)
        NSGradient(starting: NSColor(red: 0.1, green: 0.72, blue: 0.85, alpha: 1), ending: NSColor(red: 0.08, green: 0.30, blue: 0.67, alpha: 1))!.draw(in: background, angle: -90)
        NSColor.white.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: NSRect(x: 295, y: 420, width: 370, height: 380), xRadius: 35, yRadius: 35).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 355, y: 370, width: 370, height: 350), xRadius: 35, yRadius: 35).fill()
        NSColor(red: 0.08, green: 0.29, blue: 0.56, alpha: 1).setFill()
        let boat = NSBezierPath()
        boat.move(to: NSPoint(x: 200, y: 440)); boat.line(to: NSPoint(x: 824, y: 440))
        boat.line(to: NSPoint(x: 725, y: 250)); boat.line(to: NSPoint(x: 300, y: 250)); boat.close(); boat.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let line = NSBezierPath(); line.move(to: NSPoint(x: 290, y: 195)); line.line(to: NSPoint(x: 735, y: 195)); line.lineWidth = 25; line.lineCapStyle = .round; line.stroke()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png"))
    }
}
