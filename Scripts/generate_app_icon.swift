#!/usr/bin/env swift

import AppKit

// 生成 OpenLedger App 图标（1024x1024 PNG，代码绘制：张开的手掌托住玻璃硬币）。
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
context.imageInterpolation = .high

// MARK: 背景（蓝紫渐变，App Store 图标要求不透明）
let rect = NSRect(origin: .zero, size: size)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.36, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.45, green: 0.18, blue: 0.88, alpha: 1)
])!
background.draw(in: rect, angle: -45)

// 背景光斑，让玻璃材质有内容可透
let glow = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.18),
    NSColor(calibratedWhite: 1.0, alpha: 0.0)
])!
glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 312, y: 312, width: 400, height: 400)), angle: -90)

// MARK: 工具函数：玻璃质感圆头线段（手指）
func glassCapsule(from start: NSPoint, to end: NSPoint, width: CGFloat) {
    let base = NSBezierPath()
    base.move(to: start)
    base.line(to: end)
    base.lineWidth = width
    base.lineCapStyle = .round
    NSColor(calibratedWhite: 1.0, alpha: 0.30).setStroke()
    base.stroke()

    let highlight = NSBezierPath()
    highlight.move(to: start)
    highlight.line(to: end)
    highlight.lineWidth = width * 0.42
    highlight.lineCapStyle = .round
    NSColor(calibratedWhite: 1.0, alpha: 0.55).setStroke()
    highlight.stroke()
}

// MARK: 手掌（张开的手，绘制在硬币下层）
let palm = NSBezierPath(ovalIn: NSRect(x: 322, y: 470, width: 380, height: 290))
NSColor(calibratedWhite: 1.0, alpha: 0.28).setFill()
palm.fill()
NSColor(calibratedWhite: 1.0, alpha: 0.50).setStroke()
palm.lineWidth = 14
palm.stroke()

glassCapsule(from: NSPoint(x: 330, y: 620), to: NSPoint(x: 232, y: 500), width: 72)   // 拇指
glassCapsule(from: NSPoint(x: 408, y: 470), to: NSPoint(x: 404, y: 226), width: 66)   // 食指
glassCapsule(from: NSPoint(x: 502, y: 470), to: NSPoint(x: 510, y: 188), width: 72)   // 中指
glassCapsule(from: NSPoint(x: 596, y: 470), to: NSPoint(x: 606, y: 236), width: 66)   // 无名指
glassCapsule(from: NSPoint(x: 682, y: 490), to: NSPoint(x: 700, y: 306), width: 56)   // 小指

// 硬币在掌心的投影
let coinShadow = NSBezierPath(ovalIn: NSRect(x: 392, y: 486, width: 240, height: 64))
NSColor(calibratedWhite: 0.0, alpha: 0.16).setFill()
coinShadow.fill()

// MARK: 玻璃硬币
let coinRect = NSRect(x: 362, y: 386, width: 300, height: 300)
let coin = NSBezierPath(ovalIn: coinRect)
let coinFill = NSGradient(colors: [
    NSColor(calibratedWhite: 1.0, alpha: 0.42),
    NSColor(calibratedWhite: 1.0, alpha: 0.08)
])!
coinFill.draw(in: coin, angle: -35)
NSColor(calibratedWhite: 1.0, alpha: 0.78).setStroke()
coin.lineWidth = 12
coin.stroke()

// 币面内环
let innerRing = NSBezierPath(ovalIn: NSRect(x: 408, y: 432, width: 208, height: 208))
NSColor(calibratedWhite: 1.0, alpha: 0.32).setStroke()
innerRing.lineWidth = 6
innerRing.stroke()

// 高光弧
let shine = NSBezierPath()
shine.appendArc(
    withCenter: NSPoint(x: 512, y: 536),
    radius: 128,
    startAngle: 115,
    endAngle: 205,
    clockwise: false
)
NSColor(calibratedWhite: 1.0, alpha: 0.85).setStroke()
shine.lineWidth = 16
shine.lineCapStyle = .round
shine.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("生成 PNG 失败\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("已生成：\(outputPath)")
