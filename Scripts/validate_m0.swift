#!/usr/bin/env swift

import Foundation
import Vision
import ImageIO
import CoreGraphics

// M0 概念验证：对 samples/wechat 与 samples/alipay 下的截图做 OCR，
// 用模板规则提取 金额/商户/时间/交易单号/状态，输出识别率报告。
//
// 用法：swift Scripts/validate_m0.swift [samples 目录]

let fm = FileManager.default
let samplesRoot = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "samples"
let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "webp"]

let labelKeywords: [String] = [
    "账单", "详情", "全部", "主页", "留言", "喜欢", "小程序", "服务", "状态",
    "时间", "方式", "商品", "订单", "金额", "机构", "单号", "成功", "管理",
    "记录", "推荐", "积分", "立减", "奖励", "备注", "说明", "请选择", "查看",
    "添加", "标签", "分类", "收支", "关联", "E2", "到"
]

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

func trimmed(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
}

func isLabelish(_ s: String) -> Bool {
    let t = trimmed(s)
    if t.isEmpty { return true }
    if t == "闪购" { return true }
    if t.count <= 2 && t.range(of: #"^\d+$"#, options: .regularExpression) != nil { return true }
    if t.count <= 4 && t.range(of: #"^[：！!…·•:：\dA-Za-z]+$"#, options: .regularExpression) != nil { return true }
    if t.range(of: #"^[0-9]{1,2}:[0-9]{2}$"#, options: .regularExpression) != nil { return true }
    if t.contains("：") || t.contains("！") || t.hasSuffix("＞") || t.hasSuffix(">") { return true }
    return labelKeywords.contains { t.contains($0) }
}

func extractAmount(from lines: [String]) -> (value: String, index: Int)? {
    let pattern = #"^[-+]?[¥￥]?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}$"#
    for (i, line) in lines.enumerated() {
        let t = trimmed(line)
        if t.range(of: pattern, options: .regularExpression) != nil {
            return (t, i)
        }
    }
    return nil
}

func extractMerchant(lines: [String], amountIndex: Int, platform: String) -> String? {
    // 微信转账：扫二维码付款-给XXX
    if let transfer = lines.first(where: { $0.contains("扫二维码付款-给") }),
       let range = transfer.range(of: "给") {
        let name = trimmed(String(transfer[range.upperBound...]))
        if !name.isEmpty { return name }
    }
    // 信用卡还款：交易详情页中"信用卡还款-银行名称" 或 下一行
    if let repayIndex = lines.firstIndex(where: { $0.contains("信用卡还款") }) {
        let repayLine = trimmed(lines[repayIndex])
        if let dash = repayLine.range(of: "-") {
            let name = trimmed(String(repayLine[dash.upperBound...]))
            if !name.isEmpty { return name }
        }
        if repayIndex + 1 < lines.count {
            let next = trimmed(lines[repayIndex + 1])
            if !next.isEmpty && !isLabelish(next) { return next }
        }
        return repayLine
    }
    // 微信：金额下方第一个非标签行（商户名常出现在金额下方）
    if platform == "wechat" {
        for j in (amountIndex + 1)..<min(amountIndex + 6, lines.count) {
            let t = trimmed(lines[j])
            if t.contains("当前状态") || t.contains("支付成功") || t.contains("交易成功") { break }
            if !isLabelish(t) { return t }
        }
    }
    // 通用：取金额上方最近的、不像标签/界面的文本行
    let upper = lines[..<amountIndex].reversed()
    for line in upper {
        let t = trimmed(line)
        if !isLabelish(t) { return t }
    }
    return nil
}

func extractTime(from lines: [String]) -> String? {
    let datePattern = #"[0-9]{4}[-年/][0-9]{1,2}[-月/][0-9]{1,2}[日]?(\s+[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)?"#
    for line in lines {
        if let match = line.range(of: datePattern, options: .regularExpression) {
            return trimmed(String(line[match]))
        }
    }
    return nil
}

func extractStatus(from lines: [String]) -> String? {
    for line in lines {
        if line.contains("支付成功") || line.contains("交易成功") || line.contains("还款成功") {
            return trimmed(line)
        }
    }
    return nil
}

func extractTransactionId(from lines: [String]) -> String? {
    let labels = ["交易单号", "转账单号", "订单号"]
    for (i, line) in lines.enumerated() {
        guard labels.contains(where: { line.contains($0) }) else { continue }
        var sawMasked = false
        for j in (i + 1)..<min(i + 25, lines.count) {
            let t = trimmed(lines[j])
            if t.contains("点击查看订单号") || t.contains("可扫码退款") {
                sawMasked = true
                continue
            }
            if t.range(of: #"^[0-9]{10,}$"#, options: .regularExpression) != nil {
                return t
            }
            if t.range(of: #"[0-9]{8,}"#, options: .regularExpression) != nil,
               !t.contains("："), !t.contains("账单"), !t.contains("订单") {
                return t
            }
        }
        if sawMasked { return "已打码" }
    }
    return nil
}

struct Record {
    let file: String
    let platform: String
    let amount: String?
    let merchant: String?
    let time: String?
    let transactionId: String?
    let status: String?
}

var records: [Record] = []

for platform in ["wechat", "alipay"] {
    let dir = URL(fileURLWithPath: samplesRoot).appendingPathComponent(platform)
    let files = (try? fm.contentsOfDirectory(atPath: dir.path))?
        .filter { imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []

    for name in files {
        let url = dir.appendingPathComponent(name)
        let lines = ocrText(at: url)
        let amount = extractAmount(from: lines)
        let merchant = amount.flatMap { extractMerchant(lines: lines, amountIndex: $0.index, platform: platform) }
        let time = extractTime(from: lines)
        let status = extractStatus(from: lines)
        let transactionId = extractTransactionId(from: lines)
        records.append(Record(
            file: name,
            platform: platform,
            amount: amount?.value,
            merchant: merchant,
            time: time,
            transactionId: transactionId,
            status: status
        ))
    }
}

// 输出控制台报告
print("文件 | 平台 | 金额 | 商户 | 时间 | 单号 | 状态")
print("---|---|---|---|---|---|---")
for r in records {
    let row = [r.file, r.platform, r.amount ?? "-", r.merchant ?? "-",
               r.time ?? "-", r.transactionId ?? "-", r.status ?? "-"]
    print(row.joined(separator: " | "))
}

func rate(_ keyPath: KeyPath<Record, String?>) -> String {
    let total = records.count
    let hit = records.filter { $0[keyPath: keyPath] != nil }.count
    return "\(hit)/\(total)（\(Int(Double(hit) / Double(total) * 100))%）"
}

print("\n=== M0 提取率汇总（共 \(records.count) 张）===")
print("金额：\(rate(\.amount))")
print("商户：\(rate(\.merchant))")
print("时间：\(rate(\.time))")
print("交易单号：\(rate(\.transactionId))")
print("状态：\(rate(\.status))")

for platform in ["wechat", "alipay"] {
    let sub = records.filter { $0.platform == platform }
    let hit = sub.filter { $0.amount != nil && $0.merchant != nil && $0.time != nil && $0.status != nil }.count
    print("\(platform)：核心四字段（金额/商户/时间/状态）全命中 \(hit)/\(sub.count)")
}

// 生成审计报告（含 OCR 原文；位于 samples/ 下，不会被提交）
var md = "# M0 识别验证报告\n\n生成时间：\(Date())\n\n"
md += "样本数：微信 \(records.filter { $0.platform == "wechat" }.count) 张，支付宝 \(records.filter { $0.platform == "alipay" }.count) 张\n\n"
md += "## 提取结果\n\n| 文件 | 金额 | 商户 | 时间 | 交易单号 | 状态 |\n|---|---|---|---|---|---|\n"
for r in records {
    md += "| \(r.file) | \(r.amount ?? "-") | \(r.merchant ?? "-") | \(r.time ?? "-") | \(r.transactionId ?? "-") | \(r.status ?? "-") |\n"
}
md += "\n## OCR 原文\n\n"
for platform in ["wechat", "alipay"] {
    let dir = URL(fileURLWithPath: samplesRoot).appendingPathComponent(platform)
    let files = (try? fm.contentsOfDirectory(atPath: dir.path))?
        .filter { imageExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []
    for name in files {
        let lines = ocrText(at: dir.appendingPathComponent(name))
        md += "### \(platform)/\(name)\n\n```\n\(lines.joined(separator: "\n"))\n```\n\n"
    }
}
let reportURL = URL(fileURLWithPath: samplesRoot).appendingPathComponent("m0-report.md")
try? md.write(to: reportURL, atomically: true, encoding: .utf8)
print("\n报告已写入：\(reportURL.path)")
