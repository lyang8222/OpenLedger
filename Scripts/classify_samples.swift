#!/usr/bin/env swift

import Foundation
import Vision
import ImageIO
import CoreGraphics

// 用法：swift Scripts/classify_samples.swift <截图目录> <归档目录>
// 示例：swift Scripts/classify_samples.swift ~/Downloads samples
//
// 对目录内每张图片做 Vision OCR，按关键词识别平台（微信/支付宝），
// 并把文件移动到 <归档目录>/wechat 或 <归档目录>/alipay，统一命名为 wechat_01.jpeg 等。

let fm = FileManager.default

let sourceDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let destRoot = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "samples"

let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "webp"]

// 强特征：出现即基本确定平台；弱特征：仅在强特征缺失时用于倾向判断。
let wechatStrong: [String] = [
    "财付通", "微信支付", "微信支付凭证", "微信团队", "微信零钱", "微信收款",
    "微信安全支付", "微信支付订单号", "转账单号", "收款方备注", "收款方服务",
    "经营单号", "交易单号", "商户单号", "商户全称", "当前状态", "交易详情"
]
let wechatWeak: [String] = ["扫二维码付款", "信用卡还款"]

let alipayStrong: [String] = [
    "支付宝", "支付宝到账", "花呗", "余额宝", "支付宝余额",
    "交易号", "网商银行", "商家订单号", "商品说明", "付款方式", "关联记录",
    "订单金额", "清算机构", "收款方全称", "账单管理", "计入收支", "还款成功",
    "交易成功", "订单号"
]
let alipayWeak: [String] = []

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

func classify(_ lines: [String]) -> String {
    let text = lines.joined(separator: "\n")
    var wechatScore = 0
    var alipayScore = 0
    var wechatHits: [String] = []
    var alipayHits: [String] = []

    for marker in wechatStrong where text.contains(marker) {
        wechatScore += 10
        wechatHits.append(marker)
    }
    for marker in wechatWeak where text.contains(marker) {
        wechatScore += 1
        wechatHits.append(marker)
    }
    for marker in alipayStrong where text.contains(marker) {
        alipayScore += 10
        alipayHits.append(marker)
    }
    for marker in alipayWeak where text.contains(marker) {
        alipayScore += 1
        alipayHits.append(marker)
    }

    if wechatScore > alipayScore {
        return "wechat(\(wechatHits.joined(separator: ",")))"
    } else if alipayScore > wechatScore {
        return "alipay(\(alipayHits.joined(separator: ",")))"
    } else if wechatScore > 0 {
        return "wechat(\(wechatHits.joined(separator: ",")))"
    } else if alipayScore > 0 {
        return "alipay(\(alipayHits.joined(separator: ",")))"
    }
    return "unknown()"
}

guard let allFiles = try? fm.contentsOfDirectory(atPath: sourceDir) else {
    print("无法读取目录：\(sourceDir)")
    exit(1)
}

let images = allFiles
    .filter { imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
    .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

print("共找到 \(images.count) 张图片\n")

var wechatCount = 0
var alipayCount = 0
var unknownCount = 0

for name in images {
    let url = URL(fileURLWithPath: sourceDir).appendingPathComponent(name)
    let lines = ocrText(at: url)
    let result = classify(lines)

    guard result.hasPrefix("wechat(") || result.hasPrefix("alipay(") else {
        print("\(name) -> \(result)")
        print("  OCR 文本：")
        for line in lines.prefix(15) {
            print("    \(line)")
        }
        unknownCount += 1
        continue
    }

    print("\(name) -> \(result)")

    let platform = result.hasPrefix("wechat(") ? "wechat" : "alipay"
    let index = platform == "wechat" ? wechatCount + 1 : alipayCount + 1
    let ext = (name as NSString).pathExtension.lowercased()
    let destDir = URL(fileURLWithPath: destRoot).appendingPathComponent(platform)
    try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)

    // 找到目录中下一个可用序号，绝不覆盖已有文件
    var candidate = index
    var dest = destDir.appendingPathComponent("\(platform)_\(String(format: "%02d", candidate)).\(ext)")
    while fm.fileExists(atPath: dest.path) && url.standardizedFileURL != dest.standardizedFileURL {
        candidate += 1
        dest = destDir.appendingPathComponent("\(platform)_\(String(format: "%02d", candidate)).\(ext)")
    }

    do {
        if url.standardizedFileURL == dest.standardizedFileURL {
            if platform == "wechat" { wechatCount += 1 } else { alipayCount += 1 }
            continue
        }
        try fm.moveItem(at: url, to: dest)
        if platform == "wechat" { wechatCount += 1 } else { alipayCount += 1 }
    } catch {
        print("  移动失败：\(error.localizedDescription)")
        unknownCount += 1
    }
}

print("\n归档完成：微信 \(wechatCount) 张，支付宝 \(alipayCount) 张，未识别 \(unknownCount) 张")
