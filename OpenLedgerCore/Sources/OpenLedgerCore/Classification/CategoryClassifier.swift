import Foundation

public enum ExpenseCategory: String, CaseIterable, Sendable {
    case dining
    case transport
    case shopping
    case entertainment
    case health
    case housing
    case education
    case transfer
    case income
    case other

    public var label: String {
        switch self {
        case .dining: "餐饮"
        case .transport: "交通"
        case .shopping: "购物"
        case .entertainment: "娱乐"
        case .health: "医疗"
        case .housing: "居住"
        case .education: "教育"
        case .transfer: "转账"
        case .income: "收入"
        case .other: "其他"
        }
    }
}

/// 基于商户/商品关键词的本地自动分类。
public struct CategoryClassifier: Sendable {
    public init() {}

    private static let rules: [(ExpenseCategory, [String])] = [
        (.dining, ["餐", "麻辣烫", "汉堡", "咖啡", "奶茶", "烧烤", "火锅", "外卖", "食堂", "美食", "小吃", "甜品", "茶", "饭"]),
        (.transport, ["加油", "加油站", "地铁", "公交", "滴滴", "打车", "出租车", "铁路", "航空", "停车", "高速", "网约车"]),
        (.shopping, ["超市", "便利店", "商城", "淘宝", "京东", "拼多多", "唯品会", "1688", "闪购", "生鲜", "百货", "优选"]),
        (.entertainment, ["电影", "KTV", "游戏", "视频会员", "音乐", "健身", "球", "演出", "乐园"]),
        (.health, ["医院", "药房", "医药", "诊所", "体检", "牙科"]),
        (.housing, ["房租", "水电", "燃气", "物业", "宽带", "家居"]),
        (.education, ["教育", "培训", "书店", "课程", "学费"]),
        (.transfer, ["转账", "红包", "还款", "信用卡"])
    ]

    public func classify(
        merchant: String?,
        itemDescription: String?,
        amount: Decimal
    ) -> ExpenseCategory {
        if amount > 0 {
            return .income
        }

        let text = [merchant, itemDescription]
            .compactMap { $0 }
            .joined(separator: " ")

        for (category, keywords) in Self.rules {
            if keywords.contains(where: { text.contains($0) }) {
                return category
            }
        }
        return .other
    }
}
