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

    var body: some View {
        Group {
            switch chartType {
            case .bar: barChart
            case .pie: pieChart
            case .line: lineChart
            case .area: areaChart
            }
        }
        .frame(height: 190)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    private var barChart: some View {
        Chart {
            ForEach(summaries) { summary in
                BarMark(
                    x: .value("月份", summary.month, unit: .month),
                    y: .value("金额", summary.expense)
                )
                .foregroundStyle(by: .value("类别", "支出"))

                BarMark(
                    x: .value("月份", summary.month, unit: .month),
                    y: .value("金额", summary.income)
                )
                .foregroundStyle(by: .value("类别", "收入"))
            }
        }
        .chartForegroundStyleScale(["支出": Color.orange, "收入": Color.green])
        .chartLegend(position: .bottom)
    }

    private var pieChart: some View {
        let current = summaries.last
        let expense = current?.expense ?? 0
        let income = current?.income ?? 0

        return Chart {
            SectorMark(
                angle: .value("金额", expense),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .foregroundStyle(by: .value("类别", "支出"))

            SectorMark(
                angle: .value("金额", income),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .foregroundStyle(by: .value("类别", "收入"))
        }
        .chartForegroundStyleScale(["支出": Color.orange, "收入": Color.green])
        .chartLegend(position: .bottom)
    }

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
    }
}
