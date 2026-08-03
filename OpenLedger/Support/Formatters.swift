import Foundation

enum LedgerFormatters {
    static let amount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    static func string(from decimal: Decimal) -> String {
        amount.string(from: decimal as NSDecimalNumber) ?? "\(decimal)"
    }
}
