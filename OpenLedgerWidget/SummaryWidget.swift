import SwiftUI
import WidgetKit

struct SummaryEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
    let todayAmount: Decimal
    let monthCount: Int
    let monthAmount: Decimal
    let updatedAt: Date?
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(
            date: Date(),
            todayCount: 0,
            todayAmount: 0,
            monthCount: 0,
            monthAmount: 0,
            updatedAt: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry()], policy: .after(refresh)))
    }

    private func entry() -> SummaryEntry {
        let snapshot = WidgetSummarySnapshot.load()
        return SummaryEntry(
            date: Date(),
            todayCount: snapshot.todayCount,
            todayAmount: snapshot.todayAmount,
            monthCount: snapshot.monthCount,
            monthAmount: snapshot.monthAmount,
            updatedAt: snapshot.updatedAt
        )
    }
}

struct SummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SummaryWidget", provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("账单总结")
        .description("查看今日与本月支出")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                HStack(spacing: 12) {
                    statColumn(
                        title: "今日支出",
                        amount: entry.todayAmount,
                        count: entry.todayCount
                    )

                    Divider()

                    statColumn(
                        title: "本月支出",
                        amount: entry.monthAmount,
                        count: entry.monthCount
                    )
                }
            default:
                statColumn(
                    title: "今日支出",
                    amount: entry.todayAmount,
                    count: entry.todayCount
                )
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.35),
                    Color.purple.opacity(0.20),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func statColumn(title: String, amount: Decimal, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: "creditcard")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(amountText(amount))
                .font(.title2.weight(.bold).monospacedDigit())
                .minimumScaleFactor(0.7)

            Text("\(count) 笔")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let updatedAt = entry.updatedAt {
                Text("更新于 \(updatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func amountText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "zh_CN")
        return "¥" + (formatter.string(from: amount as NSDecimalNumber) ?? "0.00")
    }
}
