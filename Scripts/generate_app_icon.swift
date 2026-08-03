#!/usr/bin/env swift

import AppKit

// 生成 OpenLedger App 图标（1024x1024 PNG）。
// 用法：swift Scripts/generate_app_icon.swift <输出路径.png>

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let size = NSSize(width: 1024, height: 1024)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("创建位图失败\n", stderr)
    exit(1)
}

let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

// 背景：蓝紫渐变（全幅方形，系统会自动套圆角遮罩）
let rect = NSRect(origin: .zero, size: size)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.18, green: 0.42, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.48, green: 0.20, blue: 0.90, alpha: 1)
])!
gradient.draw(in: rect, angle: -45)

// 玻璃圆盘
let circleRect = NSRect(x: 262, y: 262, width: 500, height: 500)
let circle = NSBezierPath(ovalIn: circleRect)
NSColor(calibratedWhite: 1.0, alpha: 0.20).setFill()
circle.fill()

// 玻璃描边
NSColor(calibratedWhite: 1.0, alpha: 0.55).setStroke()
circle.lineWidth = 18
circle.stroke()

// 高光弧
let shine = NSBezierPath()
shine.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 218, startAngle: 120, endAngle: 205, clockwise: true)
NSColor(calibratedWhite: 1.0, alpha: 0.75).setStroke()
shine.lineWidth = 22
shine.lineCapStyle = .round
shine.stroke()

// ¥ 符号
let font = NSFont.systemFont(ofSize: 310, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]
let symbol = "¥" as NSString
let symbolSize = symbol.size(withAttributes: attributes)
symbol.draw(
    at: NSPoint(
        x: (size.width - symbolSize.width) / 2,
        y: (size.height - symbolSize.height) / 2 - 8
    ),
    withAttributes: attributes
)

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("生成 PNG 失败\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("已生成：\(outputPath)")
