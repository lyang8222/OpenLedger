import OpenLedgerCore
import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (PaymentDraft) -> Void

    @State private var amountText = ""
    @State private var isExpense = true
    @State private var merchant = ""
    @State private var paidAt = Date()
    @State private var platform: PaymentRecord.Platform = .unknown
    @State private var transactionId = ""

    private var parsedAmount: Decimal? {
        let cleaned = amountText
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              value > 0 else {
            return nil
        }
        return value
    }

    private var isValid: Bool {
        parsedAmount != nil
            && !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金额") {
                    Picker("类型", selection: $isExpense) {
                        Text("支出").tag(true)
                        Text("收入").tag(false)
                    }
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("信息") {
                    TextField("商户 / 说明", text: $merchant)
                    DatePicker("时间", selection: $paidAt, displayedComponents: [.date, .hourAndMinute])
                    Picker("平台", selection: $platform) {
                        ForEach(
                            [PaymentRecord.Platform.unknown, .wechat, .alipay, .unionpay, .douyin],
                            id: \.self
                        ) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    TextField("交易单号（可选）", text: $transactionId)
                }
            }
            .navigationTitle("手动记账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let magnitude = parsedAmount else { return }
        let amount = isExpense ? -magnitude : magnitude
        let cleaned = { (text: String) -> String? in
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let draft = PaymentDraft(
            platform: platform,
            amount: amount,
            merchant: cleaned(merchant),
            paidAt: paidAt,
            status: isExpense ? "支出" : "收入",
            transactionId: cleaned(transactionId),
            rawText: "手动录入",
            missingFields: []
        )
        onSave(draft)
        dismiss()
    }
}
