// make-icon.swift
// ------------------------------------------------------------
// Generates a 1024x1024 PNG app icon with no external tools:
// an orange "squircle" with the Swift bird in white. The
// make-icon.sh script turns this PNG into an .icns.
//
// Run indirectly via: ./Scripts/make-icon.sh
// ------------------------------------------------------------

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon_1024.png"

let size: CGFloat = 1024

// Tint an image to a solid color (used to make the SF Symbol white).
func tint(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect)
    color.set()
    rect.fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

// Rounded-rect (squircle-ish) background with an orange gradient.
let inset = size * 0.06
let bgRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.22, yRadius: size * 0.22)
bgPath.addClip()
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.20, alpha: 1.0),
    NSColor(calibratedRed: 0.90, green: 0.18, blue: 0.13, alpha: 1.0)
])!
gradient.draw(in: bgRect, angle: -90)

// The Swift bird symbol, in white, centered.
if let symbol = NSImage(systemSymbolName: "swift", accessibilityDescription: "Swift") {
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .bold)
    let configured = symbol.withSymbolConfiguration(config) ?? symbol
    let white = tint(configured, .white)
    let s = white.size
    let drawRect = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height)
    white.draw(in: drawRect)
} else {
    // Fallback: draw ">_" if the SF Symbol isn't available.
    let text = ">_" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: size * 0.30, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let ts = text.size(withAttributes: attrs)
    text.draw(at: NSPoint(x: (size - ts.width) / 2, y: (size - ts.height) / 2), withAttributes: attrs)
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    FileHandle.standardError.write(Data("Failed to write \(outputPath): \(error)\n".utf8))
    exit(1)
}
