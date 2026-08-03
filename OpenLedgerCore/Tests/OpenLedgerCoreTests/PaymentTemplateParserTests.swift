import Foundation
import XCTest
@testable import OpenLedgerCore

final class PaymentTemplateParserTests: XCTestCase {
    private let parser = PaymentTemplateParser()

    func testWechatPaymentDetail() {
        let lines = [
            "21:17", "：！今B0", "大红川天椒", "•留言", "主页", "• 交易详情",
            "-35.00", "大红川天椒", "当前状态", "收单机构", "支付时间", "支付方式",
            "交易单号", "经营单号", "支付成功", "财付通支付科技有限公司",
            "2026年08月03日 12:39:43", "建设银行储蓄卡（7023）",
            "4500000272202608037277512581", "103608149539178573197701731868",
            "01", "交易服务", "③ 对订单有疑惑", "园 发起群收款", "本服务由财付通提供"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .wechat)
        XCTAssertEqual(draft.amount, Decimal(string: "-35.00"))
        XCTAssertEqual(draft.merchant, "大红川天椒")
        XCTAssertNotNil(draft.paidAt)
        XCTAssertEqual(draft.status, "支付成功")
        XCTAssertEqual(draft.transactionId, "4500000272202608037277512581")
        XCTAssertTrue(draft.missingFields.isEmpty)
    }

    func testWechatTransfer() {
        let lines = [
            "21:18", "账单", "80", "全部账单", "扫二维码付款-给心想事成", "-3.00",
            "当前状态", "收款方备注", "支付方式", "转账时间", "转账单号", "支付成功",
            "二维码收款", "建设银行储蓄卡（7023）", "2026年4月29日 08:39:49",
            "10001073012026042900290072534", "112", "账单服务",
            "③ 对订单有疑惑", "四 申请电子凭证", "收款方服务", "四 收款方名片",
            "本服务由财付通提供"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .wechat)
        XCTAssertEqual(draft.merchant, "心想事成")
        XCTAssertEqual(draft.amount, Decimal(string: "-3.00"))
        XCTAssertNotNil(draft.paidAt)
        XCTAssertEqual(draft.transactionId, "10001073012026042900290072534")
    }

    func testAlipayBillDetail() {
        let lines = [
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

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .alipay)
        XCTAssertEqual(draft.amount, Decimal(string: "-24.10"))
        XCTAssertEqual(draft.merchant, "1688平台商家")
        XCTAssertNotNil(draft.paidAt)
        XCTAssertEqual(draft.status, "支付成功")
        XCTAssertEqual(draft.transactionId, "2026062523001817881415708158")
    }

    func testAlipayMaskedTransactionId() {
        let lines = [
            "账单详情", "全部账单", "双阳区晨宇总超市", "-64.77", "交易成功",
            "订单金额", "碰友日立减", "支付时间", "付款方式", "商品说明", "支付奖励",
            "收单机构", "清算机构", "订单号", "商家订单号", "账单管理", "账单分类",
            "65.77", "-1.00", "2026-07-31 14:50:57", "花呗＞", "二维码支付",
            "中国建设银行股份有限公司吉林省分行", "中国银联股份有限公司",
            "M221****** 点击查看订单号"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .alipay)
        XCTAssertNil(draft.transactionId)
        XCTAssertTrue(draft.missingFields.contains("交易单号"))
    }

    func testAlipayHuabeiRepayment() {
        let lines = [
            "21:20", "账单详情", "：！！今四", "全部账单", "花呗", "780.96",
            "还款成功", "2026-07-10 16:56:41", "建设银行储蓄卡（7023）＞", "花呗",
            "创建时间", "付款方式", "还款到", "服务详情", "鬥",
            "花呗主动还款-2026年07月账单", "查看详情＞", "推荐服务",
            "领银行卡立减金，支付就可用", "去查看＞", "订单号",
            "2026071029020999880132064051", "账单管理", "账单分类", "标签",
            "为您推荐", "信用借还＞", "请选择＞", "还款+", "计入收支"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .alipay)
        XCTAssertEqual(draft.amount, Decimal(string: "780.96"))
        XCTAssertEqual(draft.merchant, "花呗")
        XCTAssertEqual(draft.status, "还款成功")
        XCTAssertEqual(draft.transactionId, "2026071029020999880132064051")
    }

    func testUnionpayDetail() {
        let lines = [
            "22:16", "64", "银联交易详情", "信用卡还款", "-￥100.00", "卡号",
            "交易时间", "订单金额", "交易渠道", "对方姓名", "对方卡号", "交易类别",
            "分类", "发卡机构", "收单机构", "商户编号", "终端编号", "批次号",
            "凭证号", "参考号", "建设银行银联储蓄卡［7023］", "2026-07-24 09:55:43",
            "¥100.00", "云闪付APP", "鲁阳", "交通银行银联信用卡［4543］", "消费",
            "资金往来-转账", "建设银行", "银联商务股份有限公司", "001980099990002",
            "01080209", "095543", "811465", "095543138907", "在此商户交易", "￥Q", "余额查询"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .unionpay)
        XCTAssertEqual(draft.amount, Decimal(string: "-100.00"))
        XCTAssertEqual(draft.merchant, "信用卡还款")
        XCTAssertNotNil(draft.paidAt)
        XCTAssertEqual(draft.status, "消费")
        XCTAssertEqual(draft.transactionId, "095543138907")
    }

    func testDouyinBillDetail() {
        let lines = [
            "22:19", "63", "账单详情", "全部账单", "49", "上海华莱士贸易有限公司",
            "-9.89", "支付成功", "抖音支付优惠", "付款方式", "免单奖励", "抽免单资格已过期",
            "¥0.01", "小抖音月付＞", "免下单后抽免单へ", "规则",
            "恭喜你，有机会获得20元支付红包＞", "月付账单信息", "支付时间", "交易单号",
            "商户单号", "已还清", "2026-05-24 15:29:56", "2001022605240105005401321141",
            "1095184204395227346", "商品订单", "W生莱士国", "味滋脆鸡肉堡两个（",
            "【经典双堡】咔滋脆鸡肉堡两个-可配送C1 >", "21"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.platform, .douyin)
        XCTAssertEqual(draft.amount, Decimal(string: "-9.89"))
        XCTAssertEqual(draft.merchant, "上海华莱士贸易有限公司")
        XCTAssertNotNil(draft.paidAt)
        XCTAssertEqual(draft.status, "支付成功")
        XCTAssertEqual(draft.transactionId, "2001022605240105005401321141")
    }

    func testDouyinWithDeleteButton() {
        let lines = [
            "22:19", "账单详情", "删除", "49", "福州塔斯汀䬸饮管理有限公司",
            "-68.90", "支付成功", "付款方式", "月付账单信息", "支付时间", "交易单号",
            "商户单号", "2026-05-24 15:29:18", "2001022605240105002198931488",
            "1095142965546587346", "商品订单"
        ]

        let draft = parser.parse(lines: lines)
        XCTAssertEqual(draft.merchant, "福州塔斯汀䬸饮管理有限公司")
    }
}
