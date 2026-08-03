#!/usr/bin/env swift

import Foundation
import Vision
import ImageIO
import CoreGraphics

// 用法：swift Scripts/ocr_dump.swift <图片或目录>
// 打印图片 OCR 结果（带行号），用于观察支付截图字段排版。

let fm = FileManager.default
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "webp"]

func ocrText(at url: URL) -> [String] {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return []
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["zh-Hans", "en-US"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return []
    }

    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
}

var isDir: ObjCBool = false
guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
    print("路径不存在：\(path)")
    exit(1)
}

if isDir.boolValue {
    let files = (try? fm.contentsOfDirectory(atPath: path))?
        .filter { imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []
    for name in files {
        print("\n===== \(name) =====")
        let lines = ocrText(at: URL(fileURLWithPath: path).appendingPathComponent(name))
        for (i, line) in lines.enumerated() {
            print("\(i + 1): \(line)")
        }
    }
} else {
    print("===== \(path) =====")
    let lines = ocrText(at: URL(fileURLWithPath: path))
    for (i, line) in lines.enumerated() {
        print("\(i + 1): \(line)")
    }
}
