import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("Usage: generate_app_icon.swift <output-directory>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true, attributes: nil)

let canvasSize: CGFloat = 1024
let outputSize = NSSize(width: canvasSize, height: canvasSize)
let outputRect = NSRect(origin: .zero, size: outputSize)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize),
        pixelsHigh: Int(canvasSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("Couldn't create bitmap context.\n", stderr)
    exit(1)
}

bitmap.size = outputSize

func color(_ hex: Int, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func withShadow(_ shadow: NSShadow?, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    shadow?.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.setAllowsAntialiasing(true)
context.cgContext.setShouldAntialias(true)

NSColor.clear.setFill()
outputRect.fill()

let cardRect = outputRect.insetBy(dx: 44, dy: 44)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 228, yRadius: 228)

cardPath.addClip()

let baseGradient = NSGradient(colors: [
    color(0x061724),
    color(0x12304a),
    color(0xd85d33),
])!
baseGradient.draw(
    from: NSPoint(x: cardRect.minX + 40, y: cardRect.maxY),
    to: NSPoint(x: cardRect.maxX - 20, y: cardRect.minY + 60),
    options: []
)

let glowTop = NSBezierPath(ovalIn: NSRect(x: 72, y: 540, width: 560, height: 360))
let glowTopGradient = NSGradient(starting: color(0x68f0d4, alpha: 0.28), ending: color(0x68f0d4, alpha: 0.0))!
glowTopGradient.draw(in: glowTop, relativeCenterPosition: NSPoint(x: -0.2, y: 0.0))

let glowBottom = NSBezierPath(ovalIn: NSRect(x: 470, y: 120, width: 430, height: 420))
let glowBottomGradient = NSGradient(starting: color(0xffb36c, alpha: 0.34), ending: color(0xffb36c, alpha: 0.0))!
glowBottomGradient.draw(in: glowBottom, relativeCenterPosition: NSPoint(x: 0.15, y: -0.1))

let backgroundNoise = NSBezierPath()
backgroundNoise.move(to: NSPoint(x: 120, y: 280))
backgroundNoise.curve(
    to: NSPoint(x: 880, y: 400),
    controlPoint1: NSPoint(x: 300, y: 180),
    controlPoint2: NSPoint(x: 640, y: 500)
)
backgroundNoise.lineWidth = 24
color(0xffffff, alpha: 0.06).setStroke()
backgroundNoise.stroke()

let outerStroke = NSBezierPath(roundedRect: cardRect.insetBy(dx: 6, dy: 6), xRadius: 220, yRadius: 220)
color(0xffffff, alpha: 0.10).setStroke()
outerStroke.lineWidth = 4
outerStroke.stroke()

let rearWindowRect = NSRect(x: 170, y: 380, width: 470, height: 330)
let rearWindow = NSBezierPath(roundedRect: rearWindowRect, xRadius: 70, yRadius: 70)
let rearShadow = NSShadow()
rearShadow.shadowBlurRadius = 36
rearShadow.shadowOffset = NSSize(width: 0, height: -18)
rearShadow.shadowColor = color(0x041019, alpha: 0.28)

withShadow(rearShadow) {
    color(0xffffff, alpha: 0.08).setFill()
    rearWindow.fill()
}

color(0x87f5e3, alpha: 0.34).setStroke()
rearWindow.lineWidth = 8
rearWindow.stroke()

let rearHeader = NSBezierPath(roundedRect: NSRect(x: rearWindowRect.minX + 26, y: rearWindowRect.maxY - 56, width: rearWindowRect.width - 52, height: 20), xRadius: 10, yRadius: 10)
color(0xffffff, alpha: 0.10).setFill()
rearHeader.fill()

let frontWindowRect = NSRect(x: 260, y: 210, width: 560, height: 430)
let frontWindow = NSBezierPath(roundedRect: frontWindowRect, xRadius: 84, yRadius: 84)
let frontShadow = NSShadow()
frontShadow.shadowBlurRadius = 56
frontShadow.shadowOffset = NSSize(width: 0, height: -24)
frontShadow.shadowColor = color(0x02070c, alpha: 0.34)

withShadow(frontShadow) {
    color(0x0b1a27, alpha: 0.68).setFill()
    frontWindow.fill()
}

color(0xfff1d8, alpha: 0.88).setStroke()
frontWindow.lineWidth = 10
frontWindow.stroke()

let trafficColors = [0xff7b52, 0xffcf64, 0x73efc7]
for (index, hex) in trafficColors.enumerated() {
    let dotRect = NSRect(x: frontWindowRect.minX + 38 + CGFloat(index) * 34, y: frontWindowRect.maxY - 52, width: 18, height: 18)
    let dotPath = NSBezierPath(ovalIn: dotRect)
    color(hex, alpha: 0.95).setFill()
    dotPath.fill()
}

let headerLine = NSBezierPath(roundedRect: NSRect(x: frontWindowRect.minX + 140, y: frontWindowRect.maxY - 52, width: 250, height: 16), xRadius: 8, yRadius: 8)
color(0xffffff, alpha: 0.12).setFill()
headerLine.fill()

let letterShadow = NSShadow()
letterShadow.shadowBlurRadius = 30
letterShadow.shadowOffset = NSSize(width: 0, height: -10)
letterShadow.shadowColor = color(0xff8b4d, alpha: 0.25)

withShadow(letterShadow) {
    let wPath = NSBezierPath()
    wPath.move(to: NSPoint(x: 356, y: 542))
    wPath.line(to: NSPoint(x: 426, y: 320))
    wPath.line(to: NSPoint(x: 512, y: 476))
    wPath.line(to: NSPoint(x: 598, y: 320))
    wPath.line(to: NSPoint(x: 668, y: 542))
    wPath.lineWidth = 78
    wPath.lineJoinStyle = .round
    wPath.lineCapStyle = .round
    color(0xfff2da, alpha: 0.98).setStroke()
    wPath.stroke()
}

let motionPath = NSBezierPath()
motionPath.appendArc(withCenter: NSPoint(x: 508, y: 470), radius: 248, startAngle: 208, endAngle: 22, clockwise: false)
motionPath.lineWidth = 28
motionPath.lineCapStyle = .round
color(0xffc06f, alpha: 0.92).setStroke()
motionPath.stroke()

for angle in [154.0, 178.0] {
    let radians = CGFloat(angle) * .pi / 180
    let x = 508 + cos(radians) * 248
    let y = 470 + sin(radians) * 248
    let pulseRect = NSRect(x: x - 10, y: y - 10, width: 20, height: 20)
    let pulse = NSBezierPath(ovalIn: pulseRect)
    color(0xffdfba, alpha: 0.32).setFill()
    pulse.fill()
}

let endAngle = CGFloat(22.0) * .pi / 180
let endpoint = NSPoint(x: 508 + cos(endAngle) * 248, y: 470 + sin(endAngle) * 248)
let endpointShadow = NSShadow()
endpointShadow.shadowBlurRadius = 24
endpointShadow.shadowOffset = .zero
endpointShadow.shadowColor = color(0xffb25e, alpha: 0.48)

withShadow(endpointShadow) {
    let endpointDot = NSBezierPath(ovalIn: NSRect(x: endpoint.x - 28, y: endpoint.y - 28, width: 56, height: 56))
    color(0xfff3d6, alpha: 1.0).setFill()
    endpointDot.fill()
}

let accentTriangle = NSBezierPath()
accentTriangle.move(to: NSPoint(x: 705, y: 612))
accentTriangle.line(to: NSPoint(x: 760, y: 666))
accentTriangle.line(to: NSPoint(x: 686, y: 682))
accentTriangle.close()
color(0x89fff0, alpha: 0.86).setFill()
accentTriangle.fill()

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Couldn't encode PNG data.\n", stderr)
    exit(1)
}

let outputFile = outputDirectory.appendingPathComponent("waker-icon.png")
try pngData.write(to: outputFile)
print(outputFile.path)
