import OpenLedgerCore
import SwiftUI

struct RecognitionReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let draft: PaymentDraft
    let onSave: (PaymentDraft) -> Void

    @State private var amountText: String
    @State private var merchant: String
    @State private var paidAt: Date
    @State private var transactionId: String
    @State private var status: String

    init(draft: PaymentDraft, onSave: @escaping (PaymentDraft) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _amountText = State(initialValue: draft.amount.map(LedgerFormatters.string(from:)) ?? "")
        _merchant = State(initialValue: draft.merchant ?? "")
        _paidAt = State(initialValue: draft.paidAt ?? Date())
        _transactionId = State(initialValue: draft.transactionId ?? "")
        _status = State(initialValue: draft.status ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("识别结果（可修改）") {
                    TextField("金额", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("商户", text: $merchant)
                    DatePicker("支付时间", selection: $paidAt, displayedComponents: [.date, .hourAndMinute])
                    TextField("交易单号", text: $transactionId)
                    TextField("状态", text: $status)
                }

                if !draft.missingFields.isEmpty {
                    Section("待补充") {
                        ForEach(Array(draft.missingFields).sorted(), id: \.self) { field in
                            Label("未识别到\(field)", systemImage: "exclamationmark.triangle.fill")
                        }
                    }
                }
            }
            .navigationTitle("确认账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func save() {
        var updated = draft
        let cleanAmount = amountText
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: ",", with: "")
        updated.amount = Decimal(
            string: cleanAmount,
            locale: Locale(identifier: "en_US_POSIX")
        )
        updated.merchant = trimmedOrNil(merchant)
        updated.paidAt = paidAt
        updated.transactionId = trimmedOrNil(transactionId)
        updated.status = trimmedOrNil(status)
        onSave(updated)
    }

    private func trimmedOrNil(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
