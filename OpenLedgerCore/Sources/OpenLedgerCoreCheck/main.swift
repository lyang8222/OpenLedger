import CryptoKit
import Foundation
import OpenLedgerCore

// 轻量校验器：不依赖 XCTest（命令行工具环境可直接 swift run）。
// 与 OpenLedgerCoreTests 覆盖同一批场景。

var failures = 0
var passed = 0

@MainActor
func expect(_ condition: Bool, _ name: String) {
    if condition {
        passed += 1
        print("PASS  \(name)")
    } else {
        failures += 1
        print("FAIL  \(name)")
    }
}

@MainActor
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    expect(actual == expected, "\(name)（期望 \(expected)，实际 \(actual)）")
}

@MainActor
func expectNotNil<T>(_ value: T?, _ name: String) {
    expect(value != nil, "\(name)（期望非空）")
}

@MainActor
func expectNil<T>(_ value: T?, _ name: String) {
    expect(value == nil, "\(name)（期望为空）")
}

@MainActor
func expectThrows(_ name: String, _ body: () throws -> Void) {
    do {
        try body()
        failures += 1
        print("FAIL  \(name)（未抛错）")
    } catch {
        passed += 1
        print("PASS  \(name)（错误：\(error)）")
    }
}

// MARK: - 模板解析

@MainActor
func testParser() {
    let parser = PaymentTemplateParser()

    let wechatDetail = [
        "21:17", "：！今B0", "大红川天椒", "•留言", "主页", "• 交易详情",
        "-35.00", "大红川天椒", "当前状态", "收单机构", "支付时间", "支付方式",
        "交易单号", "经营单号", "支付成功", "财付通支付科技有限公司",
        "2026年08月03日 12:39:43", "建设银行储蓄卡（7023）",
        "4500000272202608037277512581", "103608149539178573197701731868",
        "01", "交易服务", "③ 对订单有疑惑", "园 发起群收款", "本服务由财付通提供"
    ]
    var draft = parser.parse(lines: wechatDetail)
    expectEqual(draft.platform, .wechat, "微信支付详情：平台")
    expectEqual(draft.amount, Decimal(string: "-35.00"), "微信支付详情：金额")
    expectEqual(draft.merchant, "大红川天椒", "微信支付详情：商户")
    expectNotNil(draft.paidAt, "微信支付详情：时间")
    expectEqual(draft.status, "支付成功", "微信支付详情：状态")
    expectEqual(draft.transactionId, "4500000272202608037277512581", "微信支付详情：单号")
    expect(draft.missingFields.isEmpty, "微信支付详情：无缺字段")

    let wechatTransfer = [
        "21:18", "账单", "80", "全部账单", "扫二维码付款-给心想事成", "-3.00",
        "当前状态", "收款方备注", "支付方式", "转账时间", "转账单号", "支付成功",
        "二维码收款", "建设银行储蓄卡（7023）", "2026年4月29日 08:39:49",
        "10001073012026042900290072534", "112", "账单服务",
        "③ 对订单有疑惑", "四 申请电子凭证", "收款方服务", "四 收款方名片",
        "本服务由财付通提供"
    ]
    draft = parser.parse(lines: wechatTransfer)
    expectEqual(draft.platform, .wechat, "微信转账：平台")
    expectEqual(draft.merchant, "心想事成", "微信转账：商户")
    expectEqual(draft.transactionId, "10001073012026042900290072534", "微信转账：单号")

    let alipayDetail = [
        "21:20", "账单详情", "：！！！今19", "全部账单", "支付时间", "付款方式",
        "商品说明", "E2", "1688平台商家", "-24.10", "支付成功",
        "2026-06-25 11:45:48", "招商银行信用卡（7315）＞",
        "全款交易：肤感磁吸手机売适用苹果14", "喷油iphone13pro max磨砂12防摔手机套",
        "查看订单详情＞", "推荐服务", "品领银行卡立减金，支付就可用", "去查看＞",
        "订单号", "2026062523001817881415708158", "商家订单号",
        "T5006ONP5121618481117011523", "账单管理", "账单分类", "标签",
        "本笔登上月支出榜，看看分析吧〉", "数码电器＞", "请选择＞",
        "使用记账本，查看自定义分类、标签统计＞", "计入收支"
    ]
    draft = parser.parse(lines: alipayDetail)
    expectEqual(draft.platform, .alipay, "支付宝账单：平台")
    expectEqual(draft.amount, Decimal(string: "-24.10"), "支付宝账单：金额")
    expectEqual(draft.merchant, "1688平台商家", "支付宝账单：商户")
    expectNotNil(draft.paidAt, "支付宝账单：时间")
    expectEqual(draft.transactionId, "2026062523001817881415708158", "支付宝账单：单号")

    let masked = [
        "账单详情", "全部账单", "双阳区晨宇总超市", "-64.77", "交易成功",
        "订单金额", "碰友日立减", "支付时间", "付款方式", "商品说明", "支付奖励",
        "收单机构", "清算机构", "订单号", "商家订单号", "账单管理", "账单分类",
        "65.77", "-1.00", "2026-07-31 14:50:57", "花呗＞", "二维码支付",
        "中国建设银行股份有限公司吉林省分行", "中国银联股份有限公司",
        "M221****** 点击查看订单号"
    ]
    draft = parser.parse(lines: masked)
    expectNil(draft.transactionId, "支付宝打码单号：为空")
    expect(draft.missingFields.contains("交易单号"), "支付宝打码单号：标记缺失")

    let huabei = [
        "21:20", "账单详情", "：！！今四", "全部账单", "花呗", "780.96",
        "还款成功", "2026-07-10 16:56:41", "建设银行储蓄卡（7023）＞", "花呗",
        "创建时间", "付款方式", "还款到", "服务详情", "鬥",
        "花呗主动还款-2026年07月账单", "查看详情＞", "推荐服务",
        "领银行卡立减金，支付就可用", "去查看＞", "订单号",
        "2026071029020999880132064051", "账单管理", "账单分类", "标签",
        "为您推荐", "信用借还＞", "请选择＞", "还款+", "计入收支"
    ]
    draft = parser.parse(lines: huabei)
    expectEqual(draft.platform, .alipay, "花呗还款：平台")
    expectEqual(draft.amount, Decimal(string: "780.96"), "花呗还款：金额")
    expectEqual(draft.status, "还款成功", "花呗还款：状态")
}

// MARK: - 加密

@MainActor
func testCrypto() {
    let storage = InMemoryKeyStorage()
    let crypto = CryptoService(keys: storage)

    do {
        let first = try crypto.masterKey()
        let second = try crypto.masterKey()
        let firstData = first.withUnsafeBytes { Data($0) }
        let secondData = second.withUnsafeBytes { Data($0) }
        expectEqual(firstData, secondData, "主密钥稳定")

        let key = SymmetricKey(size: .bits256)
        struct SamplePayload: Codable, Equatable {
            let text: String
            let number: Int
        }

        let payload = SamplePayload(text: "世界", number: 42)
        let sealed = try crypto.encrypt(payload, using: key)
        let opened: SamplePayload = try crypto.decrypt(SamplePayload.self, from: sealed, using: key)
        expectEqual(opened.text, "世界", "加密解密回环：文本")
        expectEqual(opened.number, 42, "加密解密回环：数字")

        let wrong = SymmetricKey(size: .bits256)
        expectThrows("错误密钥解密失败") {
            _ = try crypto.decrypt(String.self, from: sealed, using: wrong)
        }
    } catch {
        expect(false, "加密测试异常：\(error)")
    }
}

// MARK: - 加密备份

@MainActor
func testArchive() {
    let archive = EncryptedArchive()
    let records = [
        PaymentRecord(
            amount: Decimal(string: "-35.00")!,
            merchant: "大红川天椒",
            paidAt: Date(timeIntervalSince1970: 1_700_000_000),
            platform: .wechat,
            transactionId: "4500000272202608037277512581",
            transactionIdHash: "abc123",
            status: "支付成功"
        ),
        PaymentRecord(
            amount: Decimal(string: "780.96")!,
            merchant: "花呗",
            paidAt: Date(timeIntervalSince1970: 1_700_000_100),
            platform: .alipay,
            transactionId: "2026071029020999880132064051",
            status: "还款成功"
        )
    ]

    do {
        let data = try archive.export(records: records, passphrase: "正确口令123")
        let restored = try archive.importArchive(data: data, passphrase: "正确口令123")
        expectEqual(restored.count, 2, "备份恢复：数量")
        expectEqual(restored[0].merchant, "大红川天椒", "备份恢复：商户")
        expectEqual(restored[0].transactionId, "4500000272202608037277512581", "备份恢复：单号")
        expectEqual(restored[1].amount, Decimal(string: "780.96"), "备份恢复：金额")

        expectThrows("错误口令恢复失败") {
            _ = try archive.importArchive(data: data, passphrase: "错误口令")
        }

        var tampered = data
        tampered[tampered.count - 1] ^= 0xFF
        expectThrows("篡改数据恢复失败") {
            _ = try archive.importArchive(data: tampered, passphrase: "正确口令123")
        }
    } catch {
        expect(false, "备份测试异常：\(error)")
    }
}

// MARK: - 执行

testParser()
testCrypto()
testArchive()

print("")
print("结果：\(passed) 通过，\(failures) 失败")
exit(failures == 0 ? 0 : 1)
