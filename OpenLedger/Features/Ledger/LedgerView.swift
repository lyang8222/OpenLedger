import OpenLedgerCore
import SwiftData
import SwiftUI

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PaymentRecordModel.createdAt, order: .reverse)
    private var records: [PaymentRecordModel]

    let highlightRecordID: UUID?

    init(highlightRecordID: UUID? = nil) {
        self.highlightRecordID = highlightRecordID
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

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
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("账单")
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.indigo.opacity(0.14),
                    Color.teal.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.12))
                .blur(radius: 80)
                .frame(width: 340, height: 340)
                .offset(x: 170, y: -300)
        }
    }

    private func row(_ record: PaymentRecordModel) -> some View {
        let isHighlighted = record.id == highlightRecordID

        return HStack(spacing: 12) {
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
        .padding(.vertical, 4)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor.opacity(0.22))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
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
