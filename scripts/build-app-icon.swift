import AppKit
import CoreGraphics
import CoreText
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: build-app-icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let side = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: side * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("unable to create icon canvas\n", stderr)
    exit(1)
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
let canvas = CGRect(x: 0, y: 0, width: side, height: side)
context.clear(canvas)

// The canvas outside this shape intentionally remains transparent.
let tile = CGPath(
    roundedRect: canvas.insetBy(dx: 52, dy: 52),
    cornerWidth: 220,
    cornerHeight: 220,
    transform: nil
)
context.saveGState()
context.addPath(tile)
context.clip()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(calibratedRed: 0.36, green: 0.55, blue: 0.96, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.17, green: 0.35, blue: 0.80, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 120, y: 930),
    end: CGPoint(x: 900, y: 80),
    options: []
)
context.restoreGState()

let documentRect = CGRect(x: 270, y: 230, width: 484, height: 564)
context.saveGState()
context.setShadow(
    offset: CGSize(width: 0, height: -16),
    blur: 26,
    color: NSColor.black.withAlphaComponent(0.20).cgColor
)
context.setFillColor(NSColor(calibratedWhite: 0.98, alpha: 1).cgColor)
context.fill(documentRect)
context.restoreGState()

// Folded document corner shared with the PDF Viewer family.
let fold = CGMutablePath()
fold.move(to: CGPoint(x: 616, y: 794))
fold.addLine(to: CGPoint(x: 754, y: 656))
fold.addLine(to: CGPoint(x: 616, y: 656))
fold.closeSubpath()
context.setFillColor(NSColor(calibratedRed: 0.74, green: 0.82, blue: 0.98, alpha: 1).cgColor)
context.addPath(fold)
context.fillPath()

context.setStrokeColor(NSColor(calibratedRed: 0.12, green: 0.33, blue: 0.75, alpha: 1).cgColor)
context.setLineWidth(26)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 616, y: 794))
context.addLine(to: CGPoint(x: 616, y: 656))
context.addLine(to: CGPoint(x: 754, y: 656))
context.strokePath()

let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 244, nil)
let textColor = NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.75, alpha: 1).cgColor
let attributedText = NSAttributedString(
    string: "MD",
    attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor
    ]
)
let line = CTLineCreateWithAttributedString(attributedText)
let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
context.textPosition = CGPoint(
    x: documentRect.midX - bounds.width / 2 - bounds.minX,
    y: 392 - bounds.minY
)
CTLineDraw(line, context)

context.setStrokeColor(NSColor(calibratedRed: 0.48, green: 0.62, blue: 0.93, alpha: 1).cgColor)
context.setLineWidth(32)
context.setLineCap(.round)
context.move(to: CGPoint(x: 384, y: 322))
context.addLine(to: CGPoint(x: 640, y: 322))
context.strokePath()

guard let image = context.makeImage() else {
    fputs("unable to create icon image\n", stderr)
    exit(1)
}
let bitmap = NSBitmapImageRep(cgImage: image)
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("unable to encode icon image\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
