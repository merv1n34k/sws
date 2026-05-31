#!/usr/bin/env swift
// Generates AppIcon.iconset (PNG files at the standard macOS sizes).
// Pipe through iconutil to produce AppIcon.icns. Driven by `make icon`.
//
// Design: dark rounded-square background with a thin white rounded
// outline inset from the edge. In the center, a stylized swiss-army
// knife composition, rotated 45° CCW to form an 'S' silhouette:
//   - vertical body capsule (in the body's own frame)
//   - lanyard hole (o) at the top of the body — this point is also the
//     saw's pivot
//   - "+" emblem at the bottom — also the knife's pivot
//   - saw extends rightward from the top pivot (becomes upper-right
//     after the 45° CCW composition rotation)
//   - knife extends leftward from the bottom pivot, flipped so the
//     flat cutting edge is on the OUTER side of the S
//   - whole composition rotated 45° CCW so the body is on a \ diagonal
//
// All strokes use the same thin line weight as the outer outline so
// the icon reads as a single coherent line drawing.

import AppKit

private let bgColor = NSColor.black

// MARK: - Knife composition

private func drawSwissKnife(canvasSize s: CGFloat, center: NSPoint, lineWidth: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    ctx.saveGState()
    defer { ctx.restoreGState() }

    // Origin at icon center, rotated 45° CCW so the body's vertical
    // axis becomes the \ diagonal of the S.
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: .pi / 4)

    // Body 1.5× the prior 0.50s; tool length unchanged; tool height
    // bumped 1.2×; o and + pushed closer to the body's tips.
    let bodyW = s * 0.20
    let bodyH = s * 0.75
    let toolLen = s * 0.42
    let toolFull = bodyW * 0.85 * 1.2

    let bodyRect = NSRect(
        x: -bodyW / 2,
        y: -bodyH / 2,
        width: bodyW,
        height: bodyH
    )
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: bodyW / 2, yRadius: bodyW / 2)
    body.lineWidth = lineWidth
    body.lineJoinStyle = .round

    // o and + sit a hair inside the body tips; tools attach here.
    let symOffset = bodyH * 0.32
    let sawPivot = NSPoint(x: 0, y: +symOffset)
    let knifePivot = NSPoint(x: 0, y: -symOffset)

    NSColor.white.setStroke()

    // 1. Saw — at the top pivot. Additional -45° (CW) rotation —
    //    opposite direction from the previous +45°.
    ctx.saveGState()
    ctx.translateBy(x: sawPivot.x, y: sawPivot.y)
    ctx.rotate(by: -.pi / 4)
    drawHalfPill(
        length: toolLen,
        fullHeight: toolFull,
        flatOnTop: false,
        sawTooth: true,
        lineWidth: lineWidth
    )
    ctx.restoreGState()

    // 2. Knife — 180° base flip so it extends leftward; additional
    //    -45° to match the saw's direction reversal.
    ctx.saveGState()
    ctx.translateBy(x: knifePivot.x, y: knifePivot.y)
    ctx.rotate(by: .pi)
    ctx.rotate(by: -.pi / 4)
    drawHalfPill(
        length: toolLen,
        fullHeight: toolFull,
        flatOnTop: false,
        sawTooth: false,
        lineWidth: lineWidth
    )
    ctx.restoreGState()

    // 3. Mask body interior so tool stems don't bleed through.
    bgColor.setFill()
    body.fill()

    // 4. Body outline on top.
    NSColor.white.setStroke()
    body.stroke()

    // 5. Lanyard hole at the saw pivot.
    let holeR = bodyW * 0.22
    let hole = NSBezierPath(ovalIn: NSRect(
        x: sawPivot.x - holeR,
        y: sawPivot.y - holeR,
        width: holeR * 2,
        height: holeR * 2
    ))
    hole.lineWidth = lineWidth
    hole.stroke()

    // 6. "+" emblem at the knife pivot.
    let plusSize = holeR * 1.6
    let plus = NSBezierPath()
    plus.move(to: NSPoint(x: knifePivot.x - plusSize / 2, y: knifePivot.y))
    plus.line(to: NSPoint(x: knifePivot.x + plusSize / 2, y: knifePivot.y))
    plus.move(to: NSPoint(x: knifePivot.x, y: knifePivot.y - plusSize / 2))
    plus.line(to: NSPoint(x: knifePivot.x, y: knifePivot.y + plusSize / 2))
    plus.lineWidth = lineWidth
    plus.lineCapStyle = .round
    plus.stroke()
}

/// Draws a half-pill at the current origin extending in +x direction.
///   - flatOnTop: when true, the flat (or sawtooth) edge is on the
///     upper side of the path (y = r) and the curve is on the lower
///     side. When false, the flat edge is at y=0 and the curve arches
///     upward.
///   - sawTooth: replaces the flat edge with triangular teeth.
///   - teethInward: when true, teeth point INTO the half-pill (toward
///     the curve) so the saw's overall extent matches a plain
///     half-pill of the same dimensions. When false, teeth point
///     outward, giving the saw extra height.
private func drawHalfPill(
    length L: CGFloat,
    fullHeight H: CGFloat,
    flatOnTop: Bool,
    sawTooth: Bool,
    teethInward: Bool = false,
    lineWidth: CGFloat
) {
    let r = H / 2
    let path = NSBezierPath()

    let flatY: CGFloat = flatOnTop ? r : 0
    let arcCY: CGFloat = flatOnTop ? r : 0       // y of arc centers
    let outwardDir: CGFloat = flatOnTop ? 1 : -1 // outward from the curve
    let toothDir: CGFloat = teethInward ? -outwardDir : outwardDir

    path.move(to: NSPoint(x: 0, y: flatY))

    if sawTooth {
        let teeth = 7
        let teethW = L / CGFloat(teeth)
        let toothDepth = r * 0.30
        for i in 0..<teeth {
            let peakX = CGFloat(i) * teethW + teethW * 0.5
            let endX = CGFloat(i + 1) * teethW
            path.line(to: NSPoint(x: peakX, y: flatY + toothDir * toothDepth))
            path.line(to: NSPoint(x: endX, y: flatY))
        }
    } else {
        path.line(to: NSPoint(x: L, y: flatY))
    }

    // Tip end (away from body) is rounded; body-side end is a sharp
    // 90° corner so the half-pill meets the body cleanly without a
    // rounded shoulder.
    if flatOnTop {
        // Curve sweeps down from (L, r) to (L-r, 0) then a straight
        // edge to (0, 0), and a straight vertical back up to (0, r).
        path.appendArc(
            withCenter: NSPoint(x: L - r, y: arcCY),
            radius: r,
            startAngle: 0,
            endAngle: -90,
            clockwise: true
        )
        path.line(to: NSPoint(x: 0, y: 0))
        path.line(to: NSPoint(x: 0, y: r))
    } else {
        // Curve arches up from (L, 0) to (L-r, r), straight to (0, r),
        // and straight vertical down to (0, 0).
        path.appendArc(
            withCenter: NSPoint(x: L - r, y: arcCY),
            radius: r,
            startAngle: 0,
            endAngle: 90,
            clockwise: false
        )
        path.line(to: NSPoint(x: 0, y: r))
        path.line(to: NSPoint(x: 0, y: 0))
    }

    path.close()
    path.lineWidth = lineWidth
    path.lineJoinStyle = .miter   // sharp 90° corner at the body-side end
    path.miterLimit = 4
    path.lineCapStyle = .round
    path.stroke()
}

// MARK: - Icon canvas

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
    let lineWidth = max(1, s * 0.018)

    // Dark rounded background.
    let bgRadius = s * 0.225
    let bg = NSBezierPath(roundedRect: fullRect, xRadius: bgRadius, yRadius: bgRadius)
    bgColor.setFill()
    bg.fill()

    // White rounded outline inset from the edge — sets the line weight
    // used throughout the icon.
    let inset = s * 0.085
    let outlineRect = fullRect.insetBy(dx: inset, dy: inset)
    let outlineRadius = bgRadius * 0.65
    let outline = NSBezierPath(
        roundedRect: outlineRect,
        xRadius: outlineRadius,
        yRadius: outlineRadius
    )
    outline.lineWidth = lineWidth
    NSColor.white.setStroke()
    outline.stroke()

    drawSwissKnife(
        canvasSize: s,
        center: NSPoint(x: s / 2, y: s / 2),
        lineWidth: lineWidth
    )

    return bitmap.representation(using: .png, properties: [:])
}

// MARK: - Driver

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: generate-icon.swift <output-iconset-dir>\n".utf8))
    exit(1)
}

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(
    atPath: outDir, withIntermediateDirectories: true
)

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
