import CryptoKit
import CoreFoundation
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

    let unionpay = [
        "22:16", "64", "银联交易详情", "信用卡还款", "-￥100.00", "卡号",
        "交易时间", "订单金额", "交易渠道", "对方姓名", "对方卡号", "交易类别",
        "分类", "发卡机构", "收单机构", "商户编号", "终端编号", "批次号",
        "凭证号", "参考号", "建设银行银联储蓄卡［7023］", "2026-07-24 09:55:43",
        "¥100.00", "云闪付APP", "鲁阳", "交通银行银联信用卡［4543］", "消费",
        "资金往来-转账", "建设银行", "银联商务股份有限公司", "001980099990002",
        "01080209", "095543", "811465", "095543138907", "在此商户交易", "￥Q", "余额查询"
    ]
    draft = parser.parse(lines: unionpay)
    expectEqual(draft.platform, .unionpay, "云闪付：平台")
    expectEqual(draft.amount, Decimal(string: "-100.00"), "云闪付：金额")
    expectEqual(draft.merchant, "信用卡还款", "云闪付：商户")
    expectNotNil(draft.paidAt, "云闪付：时间")
    expectEqual(draft.status, "消费", "云闪付：状态")
    expectEqual(draft.transactionId, "095543138907", "云闪付：参考号")

    let douyin = [
        "22:19", "63", "账单详情", "全部账单", "49", "上海华莱士贸易有限公司",
        "-9.89", "支付成功", "抖音支付优惠", "付款方式", "免单奖励", "抽免单资格已过期",
        "¥0.01", "小抖音月付＞", "免下单后抽免单へ", "规则",
        "恭喜你，有机会获得20元支付红包＞", "月付账单信息", "支付时间", "交易单号",
        "商户单号", "已还清", "2026-05-24 15:29:56", "2001022605240105005401321141",
        "1095184204395227346", "商品订单", "W生莱士国", "味滋脆鸡肉堡两个（",
        "【经典双堡】咔滋脆鸡肉堡两个-可配送C1 >", "21"
    ]
    draft = parser.parse(lines: douyin)
    expectEqual(draft.platform, .douyin, "抖音：平台")
    expectEqual(draft.amount, Decimal(string: "-9.89"), "抖音：金额")
    expectEqual(draft.merchant, "上海华莱士贸易有限公司", "抖音：商户")
    expectNotNil(draft.paidAt, "抖音：时间")
    expectEqual(draft.status, "支付成功", "抖音：状态")
    expectEqual(draft.transactionId, "2001022605240105005401321141", "抖音：交易单号")

    let douyinWithDelete = [
        "22:19", "账单详情", "删除", "49", "福州塔斯汀䬸饮管理有限公司",
        "-68.90", "支付成功", "付款方式", "月付账单信息", "支付时间", "交易单号",
        "商户单号", "2026-05-24 15:29:18", "2001022605240105002198931488",
        "1095142965546587346", "商品订单"
    ]
    draft = parser.parse(lines: douyinWithDelete)
    expectEqual(draft.merchant, "福州塔斯汀䬸饮管理有限公司", "抖音（删除按钮）：商户")
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

// MARK: - 账单解析与对账

func gbkData(_ s: String) -> Data? {
    let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
    let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
    return s.data(using: String.Encoding(rawValue: nsEncoding))
}

func sha256Hex(_ s: String) -> String {
    SHA256.hash(data: Data(s.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
}

// MARK: 最小 ZIP 写入（仅测试用）

private let crcTable: [UInt32] = {
    var table = [UInt32](repeating: 0, count: 256)
    for n in 0..<256 {
        var c = UInt32(n)
        for _ in 0..<8 {
            c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1
        }
        table[n] = c
    }
    return table
}()

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
    return crc ^ 0xFFFF_FFFF
}

private struct ZipCryptoWriter {
    private var key0: UInt32 = 0x12345678
    private var key1: UInt32 = 0x23456789
    private var key2: UInt32 = 0x34567890

    init(password: String) {
        for byte in Data(password.utf8) {
            update(byte)
        }
    }

    mutating func encrypt(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity(data.count)
        for byte in data {
            let temp = (key2 & 0xFFFF) | 2
            let keyByte = UInt8(truncatingIfNeeded: ((temp &* (temp ^ 1)) >> 8) & 0xFF)
            let cipher = byte ^ keyByte
            output.append(cipher)
            update(byte)
        }
        return output
    }

    mutating func decrypt(_ data: Data) -> Data {
        var output = Data()
        output.reserveCapacity(data.count)
        for byte in data {
            let temp = (key2 & 0xFFFF) | 2
            let keyByte = UInt8(truncatingIfNeeded: ((temp &* (temp ^ 1)) >> 8) & 0xFF)
            let plain = byte ^ keyByte
            output.append(plain)
            update(plain)
        }
        return output
    }

    private mutating func update(_ byte: UInt8) {
        key0 = crc32Update(key0, byte)
        key1 = key1 &+ (key0 & 0xFF)
        key1 = key1 &* 134775813 &+ 1
        key2 = crc32Update(key2, UInt8(truncatingIfNeeded: key1 >> 24))
    }

    private func crc32Update(_ crc: UInt32, _ byte: UInt8) -> UInt32 {
        crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
    }
}

private func buildZip(entries: [(name: String, data: Data)], password: String? = nil) -> Data {
    var localParts: [Data] = []
    var centralParts: [Data] = []
    var offset: UInt32 = 0

    for entry in entries {
        let nameData = Data(entry.name.utf8)
        let crc = crc32(entry.data)
        let flags: UInt16 = password == nil ? 0 : 1
        let payload: Data
        if let password {
            var writer = ZipCryptoWriter(password: password)
            var header = Data()
            for _ in 0..<11 {
                header.append(UInt8.random(in: 0...255))
            }
            header.append(UInt8(truncatingIfNeeded: crc >> 24))
            payload = writer.encrypt(header) + writer.encrypt(entry.data)
        } else {
            payload = entry.data
        }

        var local = Data()
        local.append(UInt32(0x04034B50).littleEndianData)
        local.append(UInt16(20).littleEndianData)   // version needed
        local.append(flags.littleEndianData)
        local.append(UInt16(0).littleEndianData)    // method: stored
        local.append(UInt16(0).littleEndianData)    // mod time
        local.append(UInt16(0).littleEndianData)    // mod date
        local.append(crc.littleEndianData)
        local.append(UInt32(payload.count).littleEndianData)
        local.append(UInt32(entry.data.count).littleEndianData)
        local.append(UInt16(nameData.count).littleEndianData)
        local.append(UInt16(0).littleEndianData)    // extra len
        local.append(nameData)
        local.append(payload)
        localParts.append(local)

        var central = Data()
        central.append(UInt32(0x02014B50).littleEndianData)
        central.append(UInt16(20).littleEndianData) // version made by
        central.append(UInt16(20).littleEndianData) // version needed
        central.append(flags.littleEndianData)
        central.append(UInt16(0).littleEndianData)  // method: stored
        central.append(UInt16(0).littleEndianData)  // time
        central.append(UInt16(0).littleEndianData)  // date
        central.append(crc.littleEndianData)
        central.append(UInt32(payload.count).littleEndianData)
        central.append(UInt32(entry.data.count).littleEndianData)
        central.append(UInt16(nameData.count).littleEndianData)
        central.append(UInt16(0).littleEndianData)  // extra len
        central.append(UInt16(0).littleEndianData)  // comment len
        central.append(UInt16(0).littleEndianData)  // disk number
        central.append(UInt16(0).littleEndianData)  // internal attrs
        central.append(UInt32(0).littleEndianData)  // external attrs
        central.append(offset.littleEndianData)
        central.append(nameData)
        centralParts.append(central)

        offset += UInt32(local.count)
    }

    var output = Data()
    for part in localParts { output.append(part) }
    let centralStart = UInt32(output.count)
    for part in centralParts { output.append(part) }

    var eocd = Data()
    eocd.append(UInt32(0x06054B50).littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    eocd.append(UInt16(entries.count).littleEndianData)
    eocd.append(UInt16(entries.count).littleEndianData)
    eocd.append(UInt32(centralParts.reduce(0) { $0 + $1.count }).littleEndianData)
    eocd.append(centralStart.littleEndianData)
    eocd.append(UInt16(0).littleEndianData)
    output.append(eocd)
    return output
}

private extension UInt16 {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}

private extension UInt32 {
    var littleEndianData: Data {
        var value = littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

@MainActor
func testBillParsers() {
    let alipayCSV = """
    --------------------------------
    导出信息：
    姓名：测试
    共2笔记录

    交易时间,交易分类,交易对方,对方账号,商品说明,收/支,金额,收/付款方式,交易状态,交易订单号,商家订单号,备注,
    2026-08-01 19:13:57,商业服务,杭州深度求索,/,DeepSeek-API服务,支出,9.88,农业银行信用卡(5561),交易成功,2026080123001417881433911615,10P2088431103081731,,
    2026-07-10 16:56:41,信用借还,花呗,/,花呗主动还款,不计收支,780.96,建设银行储蓄卡(7023),还款成功,2026071029020999880132064051,,,
    """
    guard let alipayData = gbkData(alipayCSV) else {
        expect(false, "支付宝 CSV 编码失败")
        return
    }
    do {
        let entries = try AlipayBillParser().parse(data: alipayData)
        expectEqual(entries.count, 2, "支付宝 CSV：数量")
        expectEqual(entries[0].platform, .alipay, "支付宝 CSV：平台")
        expectEqual(entries[0].amount, Decimal(string: "-9.88"), "支付宝 CSV：支出为负")
        expectEqual(entries[0].direction, .expense, "支付宝 CSV：方向")
        expectEqual(entries[0].transactionId, "2026080123001417881433911615", "支付宝 CSV：订单号")
        expectEqual(entries[1].direction, .neutral, "支付宝 CSV：不计收支")
        expectEqual(entries[1].amount, Decimal(string: "780.96"), "支付宝 CSV：中性金额")
    } catch {
        expect(false, "支付宝 CSV 解析异常：\(error)")
    }

    // 合成微信 xlsx
    let shared = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <si><t>交易时间</t></si><si><t>交易类型</t></si><si><t>交易对方</t></si><si><t>商品</t></si>
    <si><t>收/支</t></si><si><t>金额(元)</t></si><si><t>支付方式</t></si><si><t>当前状态</t></si>
    <si><t>交易单号</t></si><si><t>商户单号</t></si><si><t>备注</t></si>
    <si><t>商户消费</t></si><si><t>长春肿瘤医院</t></si><si><t>挂号支付交易378156</t></si>
    <si><t>支出</t></si><si><t>支付成功</t></si><si><t>招商银行信用卡(7315)</t></si>
    <si><t>4200003111202607259992563953</t></si><si><t>PT2080875367899734019</t></si>
    </sst>
    """
    let sheet = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
    <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c><c r="F1" t="s"><v>5</v></c><c r="G1" t="s"><v>6</v></c><c r="H1" t="s"><v>7</v></c><c r="I1" t="s"><v>8</v></c><c r="J1" t="s"><v>9</v></c><c r="K1" t="s"><v>10</v></c></row>
    <row r="2"><c r="A2"><v>46228.52690972222</v></c><c r="B2" t="s"><v>11</v></c><c r="C2" t="s"><v>12</v></c><c r="D2" t="s"><v>13</v></c><c r="E2" t="s"><v>14</v></c><c r="F2"><v>5</v></c><c r="G2" t="s"><v>16</v></c><c r="H2" t="s"><v>15</v></c><c r="I2" t="s"><v>17</v></c><c r="J2" t="s"><v>18</v></c></row>
    </sheetData></worksheet>
    """
    let zip = buildZip(entries: [
        ("xl/sharedStrings.xml", Data(shared.utf8)),
        ("xl/worksheets/sheet1.xml", Data(sheet.utf8))
    ])
    do {
        let entries = try WeChatBillParser().parse(data: zip)
        expectEqual(entries.count, 1, "微信 xlsx：数量")
        expectEqual(entries[0].platform, .wechat, "微信 xlsx：平台")
        expectEqual(entries[0].amount, Decimal(string: "-5.00"), "微信 xlsx：支出为负")
        expectEqual(entries[0].counterparty, "长春肿瘤医院", "微信 xlsx：交易对方")
        expectEqual(entries[0].transactionId, "4200003111202607259992563953", "微信 xlsx：交易单号")
        expectEqual(entries[0].method, "招商银行信用卡(7315)", "微信 xlsx：支付方式")
        expectNotNil(entries[0].paidAt, "微信 xlsx：时间")
    } catch {
        expect(false, "微信 xlsx 解析异常：\(error)")
    }
}

@MainActor
func testReconciliation() {
    let records = [
        PaymentRecord(
            amount: Decimal(string: "-9.88")!,
            merchant: "杭州深度求索",
            paidAt: Date(timeIntervalSince1970: 1_784_954_000),
            platform: .alipay,
            transactionId: "2026080123001417881433911615",
            transactionIdHash: sha256Hex("2026080123001417881433911615"),
            status: "交易成功"
        ),
        PaymentRecord(
            amount: Decimal(string: "-64.77")!,
            merchant: "双阳区晨宇总超市",
            paidAt: Date(timeIntervalSince1970: 1_784_900_000),
            platform: .alipay,
            transactionId: "2026073123001417881422899919",
            transactionIdHash: sha256Hex("2026073123001417881422899919"),
            status: "交易成功"
        )
    ]
    let billEntries = [
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_954_000),
            counterparty: "杭州深度求索",
            direction: .expense,
            amount: Decimal(string: "-9.88")!,
            transactionId: "2026080123001417881433911615"
        ),
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_900_000),
            counterparty: "双阳区晨宇总超市",
            direction: .expense,
            amount: Decimal(string: "-64.77")!,
            transactionId: "2026073123001417881422899919"
        ),
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_800_000),
            counterparty: "漏记商户",
            direction: .expense,
            amount: Decimal(string: "-12.00")!,
            transactionId: "2026073012301417881400000000"
        ),
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_700_000),
            counterparty: "金额不一致",
            direction: .expense,
            amount: Decimal(string: "-99.00")!,
            transactionId: "2026072912301417881399999999"
        ),
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_600_000),
            counterparty: "重复单号",
            direction: .expense,
            amount: Decimal(string: "-1.00")!,
            transactionId: "dup-id"
        ),
        BillEntry(
            platform: .alipay,
            paidAt: Date(timeIntervalSince1970: 1_784_600_000),
            counterparty: "重复单号2",
            direction: .expense,
            amount: Decimal(string: "-1.00")!,
            transactionId: "dup-id"
        )
    ]
    // 金额不一致：给本地补一条同单号但金额不同的记录
    let recordsWithMismatch = records + [
        PaymentRecord(
            amount: Decimal(string: "-66.66")!,
            merchant: "金额不一致",
            paidAt: Date(timeIntervalSince1970: 1_784_700_000),
            platform: .alipay,
            transactionId: "2026072912301417881399999999",
            transactionIdHash: sha256Hex("2026072912301417881399999999"),
            status: "交易成功"
        )
    ]

    let report = ReconciliationEngine().reconcile(
        billEntries: billEntries,
        records: recordsWithMismatch
    )

    expectEqual(report.matched.count, 2, "对账：匹配数量")
    expectEqual(report.missingInApp.count, 2, "对账：账单有而 App 无")
    expectEqual(report.missingInApp.first?.counterparty, "漏记商户", "对账：漏记商户")
    expectEqual(report.amountMismatched.count, 1, "对账：金额不一致")
    expectEqual(report.duplicatesInBill.count, 1, "对账：账单内重复")
    expectEqual(report.missingInBill.count, 0, "对账：App 有而账单无")
}

@MainActor
func testEncryptedZip() {
    // ZipCrypto 自洽回环
    var writer = ZipCryptoWriter(password: "123456")
    let sample = Data("hello zipcrypto".utf8)
    let encrypted = writer.encrypt(sample)
    var reader = ZipCryptoWriter(password: "123456")
    expect(reader.decrypt(encrypted) == sample, "ZipCrypto 自洽回环")

    let shared = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
    <si><t>交易时间</t></si><si><t>交易类型</t></si><si><t>交易对方</t></si><si><t>商品</t></si>
    <si><t>收/支</t></si><si><t>金额(元)</t></si><si><t>支付方式</t></si><si><t>当前状态</t></si>
    <si><t>交易单号</t></si><si><t>商户单号</t></si><si><t>备注</t></si>
    <si><t>商户消费</t></si><si><t>长春肿瘤医院</t></si><si><t>挂号支付交易378156</t></si>
    <si><t>支出</t></si><si><t>支付成功</t></si><si><t>建设银行储蓄卡(7023)</t></si>
    <si><t>4200003111202607259992563953</t></si><si><t>PT2080875367899734019</t></si>
    </sst>
    """
    let sheet = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>
    <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c><c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c><c r="F1" t="s"><v>5</v></c><c r="G1" t="s"><v>6</v></c><c r="H1" t="s"><v>7</v></c><c r="I1" t="s"><v>8</v></c><c r="J1" t="s"><v>9</v></c><c r="K1" t="s"><v>10</v></c></row>
    <row r="2"><c r="A2"><v>46228.52690972222</v></c><c r="B2" t="s"><v>11</v></c><c r="C2" t="s"><v>12</v></c><c r="D2" t="s"><v>13</v></c><c r="E2" t="s"><v>14</v></c><c r="F2"><v>5</v></c><c r="G2" t="s"><v>16</v></c><c r="H2" t="s"><v>15</v></c><c r="I2" t="s"><v>17</v></c><c r="J2" t="s"><v>18</v></c></row>
    </sheetData></worksheet>
    """
    let innerXLSX = buildZip(entries: [
        ("xl/sharedStrings.xml", Data(shared.utf8)),
        ("xl/worksheets/sheet1.xml", Data(sheet.utf8))
    ])
    let zip = buildZip(entries: [
        ("微信支付账单明细.xlsx", innerXLSX)
    ], password: "123456")

    do {
        let result = try BillZipImporter().importBill(data: zip, password: "123456")
        expectEqual(result.platform, .wechat, "加密 zip：平台")
        expect(result.fileName.contains("微信"), "加密 zip：文件名")
        expectEqual(result.entries.count, 1, "加密 zip：数量")
        expectEqual(result.entries[0].counterparty, "长春肿瘤医院", "加密 zip：商户")
        expectEqual(result.entries[0].transactionId, "4200003111202607259992563953", "加密 zip：单号")
    } catch {
        expect(false, "加密 zip 解析异常：\(error)")
    }

    do {
        _ = try BillZipImporter().importBill(data: zip, password: "000000")
        expect(false, "错误密码应失败")
    } catch BillZipError.wrongPassword {
        expect(true, "错误密码被拒绝")
    } catch {
        expect(false, "错误密码的错误类型不对：\(error)")
    }
}

@MainActor
func testBillSummaryBuilder() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 4, hour: 12))!

    let records = [
        PaymentRecord(amount: Decimal(string: "-10.50")!, paidAt: now.addingTimeInterval(-3600)),
        PaymentRecord(amount: Decimal(string: "-5.00")!, paidAt: now.addingTimeInterval(-7200)),
        PaymentRecord(amount: Decimal(string: "-100.00")!, paidAt: calendar.date(byAdding: .day, value: -3, to: now)!),
        PaymentRecord(amount: Decimal(string: "50.00")!, paidAt: now),
        PaymentRecord(amount: Decimal(string: "-999.00")!, paidAt: calendar.date(byAdding: .month, value: -1, to: now)!)
    ]
    let builder = BillSummaryBuilder()

    let daily = builder.summary(records: records, period: .daily, now: now, calendar: calendar)
    expect(daily.contains("¥15.50"), "每日总结：金额正确")
    expect(daily.contains("2 笔"), "每日总结：笔数正确")

    let dailyHidden = builder.summary(
        records: records, period: .daily, now: now, calendar: calendar, showAmounts: false
    )
    expect(dailyHidden.contains("新增 2 笔支出"), "每日总结：隐藏金额模式")
    expect(!dailyHidden.contains("¥"), "每日总结：隐藏金额不含符号")

    let yearly = builder.summary(records: records, period: .yearly, now: now, calendar: calendar)
    expect(yearly.contains("4 笔"), "年度总结：统计全部支出")

    let empty = builder.summary(
        records: [PaymentRecord(amount: Decimal(string: "-9.00")!, paidAt: calendar.date(byAdding: .day, value: -10, to: now)!)],
        period: .daily,
        now: now,
        calendar: calendar
    )
    expect(empty.contains("暂无支出"), "每日总结：无记录文案")
}

@MainActor
func validateRealBills(csvPath: String, xlsxPath: String, zipPath: String?) {
    print("\n===== 真实账单验证 =====")
    do {
        let csvData = try Data(contentsOf: URL(fileURLWithPath: csvPath))
        let alipay = try AlipayBillParser().parse(data: csvData)
        let income = alipay.filter { $0.direction == .income }.count
        let expense = alipay.filter { $0.direction == .expense }.count
        let neutral = alipay.filter { $0.direction == .neutral }.count
        print("支付宝 CSV：共 \(alipay.count) 笔（收入 \(income) / 支出 \(expense) / 不计收支 \(neutral)）")
        if let first = alipay.first {
            print("  首笔：\(first.paidAt) \(first.counterparty ?? "-") \(first.amount) \(first.transactionId ?? "-")")
        }
        if let last = alipay.last {
            print("  末笔：\(last.paidAt) \(last.counterparty ?? "-") \(last.amount) \(last.transactionId ?? "-")")
        }
    } catch {
        print("支付宝解析失败：\(error)")
    }

    do {
        let xlsxData = try Data(contentsOf: URL(fileURLWithPath: xlsxPath))
        let wechat = try WeChatBillParser().parse(data: xlsxData)
        let income = wechat.filter { $0.direction == .income }.count
        let expense = wechat.filter { $0.direction == .expense }.count
        let neutral = wechat.filter { $0.direction == .neutral }.count
        print("微信 xlsx：共 \(wechat.count) 笔（收入 \(income) / 支出 \(expense) / 中性 \(neutral)）")
        if let first = wechat.first {
            print("  首笔：\(first.paidAt) \(first.counterparty ?? "-") \(first.amount) \(first.transactionId ?? "-")")
        }
        if let last = wechat.last {
            print("  末笔：\(last.paidAt) \(last.counterparty ?? "-") \(last.amount) \(last.transactionId ?? "-")")
        }
    } catch {
        print("微信解析失败：\(error)")
    }

    if let zipPath {
        do {
            let zipData = try Data(contentsOf: URL(fileURLWithPath: zipPath))
            do {
                _ = try BillZipImporter().importBill(data: zipData, password: "000000")
                print("  用错误密码竟然成功了？")
            } catch BillZipError.wrongPassword {
                print("  错误密码被正确拒绝（ZipCrypto 校验通过路径）")
            } catch BillZipError.unsupportedEncryption {
                print("  该 zip 使用 AES 加密（暂不支持）")
            } catch {
                print("  zip 导入异常：\(error)")
            }
        } catch {
            print("zip 读取失败：\(error)")
        }
    }
}

// MARK: - 执行

testParser()
testCrypto()
testArchive()
testBillParsers()
testReconciliation()
testEncryptedZip()
testBillSummaryBuilder()

if CommandLine.arguments.count >= 3 {
    validateRealBills(
        csvPath: CommandLine.arguments[1],
        xlsxPath: CommandLine.arguments[2],
        zipPath: CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : nil
    )
}

print("")
print("结果：\(passed) 通过，\(failures) 失败")
exit(failures == 0 ? 0 : 1)
