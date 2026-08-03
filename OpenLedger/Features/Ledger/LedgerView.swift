import OpenLedgerCore
import SwiftData
import SwiftUI

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PaymentRecordModel.createdAt, order: .reverse)
    private var records: [PaymentRecordModel]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "还没有账单",
                        systemImage: "tray",
                        description: Text("点击「记账」导入第一张支付截图")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            row(record)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("账单")
        }
    }

    private func row(_ record: PaymentRecordModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: platformIcon(record.platform))
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.merchant ?? "未知商户")
                    .font(.body.weight(.medium))
                Text(record.paidAt?.formatted(date: .abbreviated, time: .shortened) ?? "时间未知")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(LedgerFormatters.string(from: record.amount))
                .font(.body.weight(.semibold))
                .foregroundStyle(record.amount < 0 ? Color.primary : Color.green)
        }
    }

    private func platformIcon(_ platform: PaymentRecord.Platform) -> String {
        switch platform {
        case .wechat: "message.fill"
        case .alipay: "a.circle.fill"
        case .unionpay: "creditcard.fill"
        case .douyin: "play.rectangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
        try? modelContext.save()
    }
}
