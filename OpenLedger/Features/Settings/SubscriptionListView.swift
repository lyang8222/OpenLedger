import OpenLedgerCore
import SwiftData
import SwiftUI

struct SubscriptionListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var records: [PaymentRecordModel]

    private var subscriptions: [DetectedSubscription] {
        SubscriptionService.detected(records: records)
    }

    var body: some View {
        NavigationStack {
            Group {
                if subscriptions.isEmpty {
                    GlassEmptyState(
                        title: "未检测到订阅",
                        message: "当同一商户出现至少两笔金额一致的周期性扣款时，会自动识别",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                } else {
                    List {
                        ForEach(subscriptions) { subscription in
                            row(subscription)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("检测到的订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func row(_ subscription: DetectedSubscription) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.merchant)
                    .font(.body.weight(.medium))
                Text("\(subscription.cadence.label)扣款 · 已出现 \(subscription.occurrences) 次")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("下次预计：\(subscription.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("¥\(LedgerFormatters.string(from: subscription.amount))")
                .font(.body.weight(.semibold))
        }
    }
}
