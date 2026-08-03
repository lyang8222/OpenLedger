import Foundation

/// 支付截图字段解析器：平台识别 + 金额/商户/时间/状态/交易单号提取。
///
/// 规则来自 M0 真实样本验证：微信页面含"财付通/交易单号/商户单号/经营单号"，
/// 支付宝页面含"付款方式/商品说明/商家订单号/订单金额/清算机构/账单管理"。
public struct PaymentTemplateParser: Sendable {
    public init() {}

    // MARK: - 平台识别

    private static let wechatStrong: [String] = [
        "财付通", "微信支付", "微信支付凭证", "微信团队", "微信零钱", "微信收款",
        "微信安全支付", "微信支付订单号", "转账单号", "收款方备注", "收款方服务",
        "经营单号", "交易单号", "商户单号", "商户全称", "当前状态", "交易详情"
    ]
    private static let wechatWeak: [String] = ["扫二维码付款", "信用卡还款"]

    private static let alipayStrong: [String] = [
        "支付宝", "支付宝到账", "花呗", "余额宝", "支付宝余额", "交易号", "网商银行",
        "商家订单号", "商品说明", "付款方式", "关联记录", "订单金额", "清算机构",
        "收款方全称", "账单管理", "计入收支", "还款成功", "交易成功", "订单号"
    ]
    private static let alipayWeak: [String] = []

    private static let unionpayStrong: [String] = [
        "银联交易详情", "云闪付", "商户编号", "终端编号", "批次号", "凭证号",
        "参考号", "授权号", "发卡机构", "交易类别", "对方卡号", "卡号"
    ]
    private static let unionpayWeak: [String] = ["信用卡还款"]

    private static let douyinStrong: [String] = [
        "抖音支付", "抖音月付", "月付账单信息", "免单奖励", "抽免单",
        "商品订单", "已还清", "商户单号", "交易单号"
    ]
    private static let douyinWeak: [String] = []

    public func classifyPlatform(from lines: [String]) -> PaymentRecord.Platform {
        let text = lines.joined(separator: "\n")
        var wechatScore = 0
        var alipayScore = 0
        var unionpayScore = 0
        var douyinScore = 0

        for marker in Self.wechatStrong where text.contains(marker) {
            wechatScore += 10
        }
        for marker in Self.wechatWeak where text.contains(marker) {
            wechatScore += 1
        }
        for marker in Self.alipayStrong where text.contains(marker) {
            alipayScore += 10
        }
        for marker in Self.alipayWeak where text.contains(marker) {
            alipayScore += 1
        }
        for marker in Self.unionpayStrong where text.contains(marker) {
            unionpayScore += 10
        }
        for marker in Self.unionpayWeak where text.contains(marker) {
            unionpayScore += 1
        }
        for marker in Self.douyinStrong where text.contains(marker) {
            douyinScore += 10
        }
        for marker in Self.douyinWeak where text.contains(marker) {
            douyinScore += 1
        }

        let scores: [(PaymentRecord.Platform, Int)] = [
            (.wechat, wechatScore),
            (.alipay, alipayScore),
            (.unionpay, unionpayScore),
            (.douyin, douyinScore)
        ]
        if let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0 {
            return best.0
        }
        return .unknown
    }

    // MARK: - 解析入口

    public func parse(lines: [String]) -> PaymentDraft {
        let platform = classifyPlatform(from: lines)
        var missing: Set<String> = []

        let amount = Self.extractAmount(from: lines)
        if amount == nil { missing.insert("金额") }

        let merchant = amount.flatMap {
            Self.extractMerchant(lines: lines, amountIndex: $0.index, platform: platform)
        }
        if merchant == nil { missing.insert("商户") }

        let timeText = Self.extractTime(from: lines)
        let paidAt = timeText.flatMap(Self.parseDate)
        if paidAt == nil { missing.insert("时间") }

        let status = Self.extractStatus(from: lines, platform: platform)
        if status == nil { missing.insert("状态") }

        let transactionId = Self.extractTransactionId(from: lines, platform: platform)
        if transactionId == nil { missing.insert("交易单号") }

        return PaymentDraft(
            platform: platform,
            amount: amount?.value,
            merchant: merchant,
            paidAt: paidAt,
            status: status,
            transactionId: transactionId,
            rawText: lines.joined(separator: "\n"),
            missingFields: missing
        )
    }

    // MARK: - 字段提取

    private static let labelKeywords: [String] = [
        "账单", "详情", "全部", "主页", "留言", "喜欢", "小程序", "服务", "状态",
        "时间", "方式", "商品", "订单", "金额", "机构", "单号", "成功",
        "记录", "推荐", "积分", "立减", "奖励", "备注", "说明", "请选择", "查看",
        "添加", "标签", "分类", "收支", "关联", "删除", "E2", "到"
    ]

    private static func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isLabelish(_ s: String) -> Bool {
        let t = trimmed(s)
        if t.isEmpty { return true }
        if t == "闪购" { return true }
        if t.count <= 2 && t.range(of: #"^\d+$"#, options: .regularExpression) != nil { return true }
        if t.count <= 4 && t.range(of: #"^[0-9]{1,3}[）)]?$"#, options: .regularExpression) != nil { return true }
        if t.count <= 4 && t.range(of: #"^[：！!…·•:：\dA-Za-z]+$"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^[0-9]{1,2}:[0-9]{2}$"#, options: .regularExpression) != nil { return true }
        if t.contains("：") || t.contains("！") || t.hasSuffix("＞") || t.hasSuffix(">") { return true }
        return labelKeywords.contains { t.contains($0) }
    }

    private static func strippingTrailingChevron(_ s: String) -> String {
        trimmed(s)
            .replacingOccurrences(of: "＞", with: "")
            .replacingOccurrences(of: ">", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractAmount(from lines: [String]) -> (value: Decimal, index: Int)? {
        let pattern = #"^[-+]?[¥￥]?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}$"#
        let locale = Locale(identifier: "en_US_POSIX")
        for (i, line) in lines.enumerated() {
            let t = trimmed(line)
            if t.range(of: pattern, options: .regularExpression) != nil,
               let value = Decimal(string: t.replacingOccurrences(of: "¥", with: "")
                    .replacingOccurrences(of: "￥", with: ""), locale: locale) {
                return (value, i)
            }
        }
        return nil
    }

    static func extractMerchant(
        lines: [String],
        amountIndex: Int,
        platform: PaymentRecord.Platform
    ) -> String? {
        // 微信转账：扫二维码付款-给XXX
        if let transfer = lines.first(where: { $0.contains("扫二维码付款-给") }),
           let range = transfer.range(of: "给") {
            let name = trimmed(String(transfer[range.upperBound...]))
            if !name.isEmpty { return name }
        }

        // 信用卡还款
        if let repayIndex = lines.firstIndex(where: { $0.contains("信用卡还款") }) {
            let repayLine = trimmed(lines[repayIndex])
            if let dash = repayLine.range(of: "-") {
                let name = trimmed(String(repayLine[dash.upperBound...]))
                if !name.isEmpty { return name }
            }
            if repayIndex + 1 < lines.count {
                let next = trimmed(lines[repayIndex + 1])
                let amountPattern = #"^[-+]?[¥￥]?[0-9]{1,3}(?:,[0-9]{3})*\.[0-9]{2}$"#
                if next.range(of: amountPattern, options: .regularExpression) == nil,
                   !next.isEmpty, !isLabelish(next) {
                    return next
                }
            }
            return repayLine
        }

        // 微信：金额下方第一个非标签行
        if platform == .wechat {
            for j in (amountIndex + 1)..<min(amountIndex + 6, lines.count) {
                let raw = trimmed(lines[j])
                if raw.contains("当前状态") || raw.contains("支付成功") || raw.contains("交易成功") { break }
                let t = strippingTrailingChevron(raw)
                if !isLabelish(t) { return t }
            }
        }

        // 通用：金额上方最近的非标签行
        for line in lines[..<amountIndex].reversed() {
            let t = strippingTrailingChevron(line)
            if !isLabelish(t) { return t }
        }
        return nil
    }

    static func extractTime(from lines: [String]) -> String? {
        let pattern = #"[0-9]{4}[-年/][0-9]{1,2}[-月/][0-9]{1,2}[日]?(\s+[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?)?"#
        for line in lines {
            if let match = line.range(of: pattern, options: .regularExpression) {
                return trimmed(String(line[match]))
            }
        }
        return nil
    }

    static func extractStatus(from lines: [String], platform: PaymentRecord.Platform) -> String? {
        for line in lines {
            if line.contains("支付成功") || line.contains("交易成功") || line.contains("还款成功") {
                return trimmed(line)
            }
        }
        // 云闪付：状态为"交易类别"的值（消费/入账/转账）
        if platform == .unionpay,
           let labelIndex = lines.firstIndex(where: { $0.contains("交易类别") }) {
            for j in (labelIndex + 1)..<lines.count {
                let t = trimmed(lines[j])
                if ["消费", "入账", "转账"].contains(t) {
                    return t
                }
            }
        }
        return nil
    }

    static func extractTransactionId(from lines: [String], platform: PaymentRecord.Platform) -> String? {
        // 云闪付：参考号是最后一个纯数字长串（商户编号/终端号等在前）
        if platform == .unionpay {
            let pattern = #"^[0-9]{10,}$"#
            var last: String?
            for line in lines {
                let t = trimmed(line)
                if t.range(of: pattern, options: .regularExpression) != nil {
                    last = t
                }
            }
            return last
        }

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
            if sawMasked { return nil }
        }
        return nil
    }

    static func parseDate(_ raw: String) -> Date? {
        let formats = [
            "yyyy年MM月dd日 HH:mm:ss",
            "yyyy年M月d日 HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy-MM-dd HH:mm"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return nil
    }
}
