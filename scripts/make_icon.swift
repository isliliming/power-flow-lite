import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make_icon.swift OUTPUT_PNG\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("could not create graphics context\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
let bounds = CGRect(origin: .zero, size: size)
let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 54, dy: 54), xRadius: 220, yRadius: 220)
NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.20, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.37, alpha: 1)
])?.draw(in: background, angle: -55)

func drawFlow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat) {
    let path = NSBezierPath()
    path.move(to: start)
    path.curve(
        to: end,
        controlPoint1: CGPoint(x: 455, y: start.y),
        controlPoint2: CGPoint(x: 565, y: end.y)
    )
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

drawFlow(
    from: CGPoint(x: 220, y: 650),
    to: CGPoint(x: 790, y: 650),
    color: NSColor.systemOrange.withAlphaComponent(0.92),
    width: 112
)
drawFlow(
    from: CGPoint(x: 220, y: 365),
    to: CGPoint(x: 790, y: 545),
    color: NSColor.systemCyan.withAlphaComponent(0.88),
    width: 112
)

let source = NSBezierPath(roundedRect: CGRect(x: 142, y: 276, width: 174, height: 466), xRadius: 72, yRadius: 72)
NSColor(calibratedWhite: 0.12, alpha: 0.96).setFill()
source.fill()

let destination = NSBezierPath(roundedRect: CGRect(x: 706, y: 440, width: 176, height: 306), xRadius: 72, yRadius: 72)
NSColor(calibratedWhite: 0.96, alpha: 0.96).setFill()
destination.fill()

let screen = NSBezierPath(roundedRect: CGRect(x: 746, y: 542, width: 96, height: 68), xRadius: 12, yRadius: 12)
NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.37, alpha: 1).setStroke()
screen.lineWidth = 18
screen.stroke()
let base = NSBezierPath()
base.move(to: CGPoint(x: 728, y: 520))
base.line(to: CGPoint(x: 860, y: 520))
base.lineWidth = 18
base.lineCapStyle = .round
base.stroke()

let bolt = NSBezierPath()
bolt.move(to: CGPoint(x: 244, y: 698))
bolt.line(to: CGPoint(x: 188, y: 618))
bolt.line(to: CGPoint(x: 229, y: 618))
bolt.line(to: CGPoint(x: 197, y: 548))
bolt.line(to: CGPoint(x: 279, y: 650))
bolt.line(to: CGPoint(x: 236, y: 650))
bolt.close()
NSColor.systemYellow.setFill()
bolt.fill()

let battery = NSBezierPath(roundedRect: CGRect(x: 174, y: 335, width: 106, height: 55), xRadius: 18, yRadius: 18)
NSColor.white.withAlphaComponent(0.92).setStroke()
battery.lineWidth = 14
battery.stroke()
let terminal = NSBezierPath(roundedRect: CGRect(x: 280, y: 350, width: 18, height: 25), xRadius: 6, yRadius: 6)
NSColor.white.withAlphaComponent(0.92).setFill()
terminal.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("could not encode icon\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
