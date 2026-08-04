import OpenLedgerCore
import SwiftData
import SwiftUI

struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PaymentRecordModel.createdAt, order: .reverse)
    private var records: [PaymentRecordModel]

    let highlightRecordID: UUID?
    var onGoCapture: (() -> Void)?
    @AppStorage("chart.type") private var chartTypeRaw = LedgerChartType.bar.rawValue
    @State private var shareRecord: PaymentRecordModel?

    init(
        highlightRecordID: UUID? = nil,
        onGoCapture: (() -> Void)? = nil
    ) {
        self.highlightRecordID = highlightRecordID
        self.onGoCapture = onGoCapture
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                Group {
                    if records.isEmpty {
                        GlassEmptyState(
                            title: "还没有收支记录",
                            message: "导入第一张支付截图，快速统计你的收支",
                            systemImage: "tray",
                            actionTitle: "去记账",
                            action: onGoCapture
                        )
                    } else {
                        List {
                            if !records.isEmpty {
                                let chartType = LedgerChartType(rawValue: chartTypeRaw) ?? .bar
                                let coreRecords = records.map { $0.toCoreRecord() }
                                Section {
                                    LedgerChartView(
                                        summaries: ChartDataBuilder().monthlySummaries(
                                            records: coreRecords,
                                            months: 6
                                        ),
                                        categorySummaries: ChartDataBuilder().categorySummaries(
                                            records: coreRecords,
                                            userRules: CategoryRuleStore.load()
                                        ),
                                        chartType: chartType
                                    )
                                    .listRowBackground(Color.clear)
                                } header: {
                                    Text(
                                        chartType == .bar || chartType == .line || chartType == .area
                                            ? "收支概况（近 6 个月）"
                                            : "本月收支概况"
                                    )
                                }
                            }

                            ForEach(records) { record in
                                row(record)
                                    .contextMenu {
                                        Button {
                                            shareRecord = record
                                        } label: {
                                            Label("生成脱敏分享卡", systemImage: "square.and.arrow.up")
                                        }
                                    }
                            }
                            .onDelete(perform: delete)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("收支")
            .sheet(item: $shareRecord) { record in
                RedactedShareSheet(record: record)
            }
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
        let category = record.category ?? CategoryClassifier().classify(
            merchant: record.merchant,
            itemDescription: nil,
            amount: record.amount,
            userRules: CategoryRuleStore.load()
        ).label

        return HStack(spacing: 12) {
            Image(systemName: platformIcon(record.platform))
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.merchant ?? "未知商户")
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                    Text(record.paidAt?.formatted(date: .abbreviated, time: .shortened) ?? "时间未知")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
