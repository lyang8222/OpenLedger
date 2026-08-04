#!/usr/bin/env swift

import Foundation
import Vision
import ImageIO
import CoreGraphics

// 打印 OCR 文本及其归一化位置（top-origin：y 越小越靠上，x 越小越靠左）。
// 用法：swift Scripts/ocr_positions.swift <图片>

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""
guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("无法读取图片\n", stderr)
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["zh-Hans", "en-US"]

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
try handler.perform([request])

for observation in (request.results ?? []) {
    guard let candidate = observation.topCandidates(1).first else { continue }
    let box = observation.boundingBox
    let yTop = 1 - box.midY
    let text = candidate.string
    if text.contains("图表") || text.contains("账单") || text.contains("隐私") ||
       text.contains("对账") || text.contains("本地") || text.contains("数据") ||
       text.contains("提醒") {
        print(String(format: "y=%.3f x=%.3f  %@", yTop, box.midX, text))
    }
}
