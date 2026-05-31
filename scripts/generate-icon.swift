#!/usr/bin/env swift
// Generates AppIcon.iconset (PNG files at the standard macOS sizes).
// Pipe through iconutil to produce AppIcon.icns. Driven by `make icon`.
//
// Design:
//   - Dark rounded-square background, edge-to-edge.
//   - White rounded outline inset from the edge, so the very edge is
//     still the dark background (gives the icon a "framed" look).
//   - Center: white SF Symbol (wrench.and.screwdriver.fill) — closest
//     stock symbol to a swiss-army multi-tool.

import AppKit

private func renderIconPNG(size: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let s = CGFloat(size)
    let fullRect = NSRect(x: 0, y: 0, width: s, height: s)

    // Dark rounded background.
    let bgRadius = s * 0.225
    let bg = NSBezierPath(roundedRect: fullRect, xRadius: bgRadius, yRadius: bgRadius)
    NSColor(red: 0.09, green: 0.10, blue: 0.13, alpha: 1).setFill()
    bg.fill()

    // White outline inset from the edge.
    let inset = s * 0.085
    let outlineRect = fullRect.insetBy(dx: inset, dy: inset)
    let outlineRadius = bgRadius * 0.65
    let outline = NSBezierPath(
        roundedRect: outlineRect,
        xRadius: outlineRadius,
        yRadius: outlineRadius
    )
    outline.lineWidth = max(1, s * 0.018)
    NSColor.white.setStroke()
    outline.stroke()

    // Center symbol — white SF Symbol.
    let pointSize = s * 0.42
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let symbolName = "wrench.and.screwdriver.fill"
    if let raw = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil),
       let configured = raw.withSymbolConfiguration(config) {
        let sz = configured.size
        let symRect = NSRect(
            x: (s - sz.width) / 2,
            y: (s - sz.height) / 2,
            width: sz.width,
            height: sz.height
        )
        configured.draw(in: symRect)
    } else {
        FileHandle.standardError.write(Data("warning: SF symbol '\(symbolName)' unavailable\n".utf8))
    }

    return bitmap.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift <output-iconset-dir>\n".utf8))
    exit(1)
}

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(
    atPath: outDir, withIntermediateDirectories: true
)

// (file name, pixel size) pairs that `iconutil` expects in an .iconset.
let entries: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in entries {
    guard let data = renderIconPNG(size: size) else {
        FileHandle.standardError.write(Data("failed to render \(name)\n".utf8))
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

print("wrote \(entries.count) PNGs to \(outDir)")
