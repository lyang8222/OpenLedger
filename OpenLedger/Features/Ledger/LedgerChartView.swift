import Charts
import OpenLedgerCore
import SwiftUI

enum LedgerChartType: String, CaseIterable, Identifiable {
    case bar
    case pie
    case line
    case area

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bar: "条形图"
        case .pie: "饼图"
        case .line: "折线图"
        case .area: "曲线图"
        }
    }
}

struct LedgerChartView: View {
    let summaries: [MonthlySummary]
    let chartType: LedgerChartType

    @State private var selectedMonth: Date?
    @State private var selectedAngle: Double?

    var body: some View {
        VStack(spacing: 8) {
            if let info = selectionInfo {
                Text(info)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Group {
                switch chartType {
                case .bar: barChart
                case .pie: pieChart
                case .line: lineChart
                case .area: areaChart
                }
            }
            .frame(height: 165)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - 选中信息

    private var selectionInfo: String? {
        switch chartType {
        case .pie:
            return pieSelectionInfo
        default:
            guard let selectedMonth,
                  let summary = summaries.first(where: { $0.month == selectedMonth }) else {
                return nil
            }
            let month = selectedMonth.formatted(.dateTime.month())
            return "\(month) · 支出 ¥\(Self.amountText(summary.expense)) · 收入 ¥\(Self.amountText(summary.income))"
        }
    }

    private var pieSelectionInfo: String? {
        guard let angle = selectedAngle, let current = summaries.last else { return nil }
        let total = current.expense + current.income
        guard total > 0 else { return nil }
        let expenseFraction = NSDecimalNumber(decimal: current.expense).doubleValue
            / NSDecimalNumber(decimal: total).doubleValue
        return angle < expenseFraction * 360
            ? "本月支出 ¥\(Self.amountText(current.expense))"
            : "本月收入 ¥\(Self.amountText(current.income))"
    }

    // MARK: - 条形图

    private struct BarItem: Identifiable {
        let id = UUID()
        let month: Date
        let amount: Decimal
        let category: String
    }

    private var barItems: [BarItem] {
        summaries.flatMap { summary in
            [
                BarItem(month: summary.month, amount: summary.expense, category: "支出"),
                BarItem(month: summary.month, amount: summary.income, category: "收入")
            ]
        }
    }

    private var barChart: some View {
        Chart(barItems) { item in
            BarMark(
                x: .value("月份", item.month, unit: .month),
                y: .value("金额", item.amount)
            )
            .position(by: .value("类别", item.category))
            .foregroundStyle(by: .value("类别", item.category))
        }
        .chartXSelection(value: $selectedMonth)
        .chartForegroundStyleScale(["支出": Color.orange, "收入": Color.green])
        .chartLegend(position: .bottom)
    }

    // MARK: - 饼图

    @ViewBuilder
    private var pieChart: some View {
        let current = summaries.last
        let expense = current?.expense ?? 0
        let income = current?.income ?? 0

        if expense == 0 && income == 0 {
            Text("本月暂无收支记录")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                SectorMark(
                    angle: .value("金额", expense),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("类别", "支出"))
                .cornerRadius(4)

                SectorMark(
                    angle: .value("金额", income),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("类别", "收入"))
                .cornerRadius(4)
            }
            .chartAngleSelection(value: $selectedAngle)
            .chartForegroundStyleScale(["支出": Color.orange, "收入": Color.green])
            .chartLegend(position: .bottom)
        }
    }

    // MARK: - 折线图 / 曲线图

    private var lineChart: some View {
        Chart(summaries) { summary in
            LineMark(
                x: .value("月份", summary.month, unit: .month),
                y: .value("支出", summary.expense)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(.blue)
            .symbol(.circle)
        }
        .chartXSelection(value: $selectedMonth)
    }

    private var areaChart: some View {
        Chart(summaries) { summary in
            AreaMark(
                x: .value("月份", summary.month, unit: .month),
                y: .value("支出", summary.expense),
                series: .value("系列", "支出")
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.blue.opacity(0.45), Color.blue.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("月份", summary.month, unit: .month),
                y: .value("支出", summary.expense),
                series: .value("系列", "支出")
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.blue)
            .symbol(.circle)
        }
        .chartXSelection(value: $selectedMonth)
    }

    private static func amountText(_ amount: Decimal) -> String {
        LedgerFormatters.string(from: amount)
    }
}
