import AppKit

// Use the same 128-point canvas as Resources/Logo.svg.
func drawPaperStack(in context: CGContext) {
    let green = CGColor(red: 90 / 255, green: 111 / 255, blue: 64 / 255, alpha: 1)
    context.setFillColor(CGColor.white)
    context.addPath(CGPath(roundedRect: CGRect(x: 6, y: 6, width: 116, height: 116),
                           cornerWidth: 26, cornerHeight: 26, transform: nil))
    context.fillPath()
    context.setStrokeColor(green)
    context.setLineWidth(5)

    for (index, origin) in [CGPoint(x: 26, y: 48), CGPoint(x: 43, y: 34), CGPoint(x: 60, y: 20)].enumerated() {
        let sheet = CGPath(roundedRect: CGRect(origin: origin, size: CGSize(width: 43, height: 53)),
                           cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(sheet)
        context.setFillColor(index == 2 ? green : CGColor.white)
        context.drawPath(using: index == 2 ? .fill : .fillStroke)
    }

    context.setStrokeColor(CGColor.white)
    context.setLineWidth(3)
    context.setLineCap(.round)
    for (y, endX) in [(35, 90), (45, 84)] {
        context.move(to: CGPoint(x: 72, y: y))
        context.addLine(to: CGPoint(x: endX, y: y))
    }
    context.strokePath()
}

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: CGFloat(pixels) / 128, y: -CGFloat(pixels) / 128)
        drawPaperStack(in: context)
        let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
        let suffix = scale == 2 ? "@2x" : ""
        let destination = URL(fileURLWithPath: "\(output)/icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
    }
}
