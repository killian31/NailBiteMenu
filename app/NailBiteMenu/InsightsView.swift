import SwiftUI
import Charts

private enum InsightsRange: String, CaseIterable, Identifiable {
    case week = "7 Days", month = "30 Days", quarter = "90 Days", all = "All Time"
    var id: String { rawValue }
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return nil
        }
    }
}

/// Everything the page shows, computed once per render.
private struct InsightsData {
    struct Day: Identifiable { let date: Date; let count: Int; var id: Date { date } }
    struct Cell: Identifiable { let weekday: String; let hour: Int; let count: Int; var id: String { "\(weekday)-\(hour)" } }

    let episodes: [Episode]
    let days: [Day]
    let perActiveDay: Double
    let averageLength: TimeInterval
    let biteFreeDays: Int
    let activeDayCount: Int
    let cells: [Cell]
    let weekdayOrder: [String]
    let previousCount: Int?

    init(all: [Episode], activeDays: Set<Date>, range: InsightsRange, calendar cal: Calendar = .current) {
        let today = cal.startOfDay(for: .now)
        let earliest = (all.map(\.start) + activeDays).min().map { cal.startOfDay(for: $0) } ?? today
        let start = range.days.map { cal.date(byAdding: .day, value: -($0 - 1), to: today)! } ?? earliest

        episodes = all.filter { $0.start >= start }
        let byDay = Dictionary(grouping: episodes) { cal.startOfDay(for: $0.start) }.mapValues(\.count)

        var list: [Day] = []
        var d = start
        while d <= today {
            list.append(Day(date: d, count: byDay[d] ?? 0))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        days = list

        let active = activeDays.filter { $0 >= start && $0 <= today }
        activeDayCount = active.count
        biteFreeDays = active.filter { byDay[$0] == nil }.count
        perActiveDay = active.isEmpty ? 0 : Double(episodes.count) / Double(active.count)
        averageLength = episodes.isEmpty ? 0 : episodes.map(\.duration).reduce(0, +) / Double(episodes.count)

        if let n = range.days {
            let prevStart = cal.date(byAdding: .day, value: -n, to: start)!
            previousCount = all.filter { $0.start >= prevStart && $0.start < start }.count
        } else {
            previousCount = nil
        }

        let symbols = cal.shortWeekdaySymbols
        weekdayOrder = (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
        let grid = Dictionary(grouping: episodes) {
            "\(cal.component(.weekday, from: $0.start))-\(cal.component(.hour, from: $0.start))"
        }.mapValues(\.count)
        cells = (1...7).flatMap { wd in
            (0..<24).map { h in Cell(weekday: symbols[wd - 1], hour: h, count: grid["\(wd)-\(h)"] ?? 0) }
        }
    }
}

struct InsightsView: View {
    @ObservedObject var tracker: HabitTracker
    @State private var range: InsightsRange = .month

    var body: some View {
        let data = InsightsData(all: tracker.episodes, activeDays: tracker.activeDays, range: range)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Range", selection: $range) {
                    ForEach(InsightsRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                HStack(spacing: 14) {
                    StatTile(title: "Episodes", value: "\(data.episodes.count)",
                             detail: trend(data), symbol: "hand.raised", tint: .dsBiteText)
                    StatTile(title: "Per day", value: data.perActiveDay.formatted(.number.precision(.fractionLength(1))),
                             detail: "On days you used your Mac", symbol: "chart.line.uptrend.xyaxis", tint: .dsTextSecondary)
                    StatTile(title: "Length", value: data.averageLength.shortDuration,
                             detail: "Average episode", symbol: "timer", tint: .dsTextSecondary)
                    StatTile(title: "Bite-free days", value: "\(data.biteFreeDays)",
                             detail: "of \(data.activeDayCount) monitored", symbol: "checkmark.seal", tint: .dsWin)
                }

                if data.episodes.isEmpty {
                    Panel(title: "No episodes in this range") {
                        EmptyNote(symbol: "sparkles", text: "Nothing to chart yet. That's a good thing.")
                    }
                } else {
                    Panel(title: data.days.count > 120 ? "Episodes per week" : "Episodes per day") { dailyChart(data) }
                    Panel(title: "When it happens") { heatmap(data) }
                    Panel(title: "Trigger apps") {
                        TriggerList(apps: Array(Insights.triggerApps(data.episodes).prefix(6)))
                    }
                }
            }
            .animation(DS.Motion.smooth, value: range)
            .padding(28)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
    }

    private func trend(_ data: InsightsData) -> String {
        guard let prev = data.previousCount else { return "Since you started" }
        let now = data.episodes.count
        if prev == 0 { return now == 0 ? "Same as before" : "None in the previous period" }
        let change = Double(now - prev) / Double(prev)
        return change <= 0
            ? "\(Int((-change * 100).rounded()))% fewer than before"
            : "\(Int((change * 100).rounded()))% more than before"
    }

    private func dailyChart(_ data: InsightsData) -> some View {
        let average = data.perActiveDay // same number as the "Per day" tile
        // Long ranges: one bar per week (Charts stacks the days that share a week).
        let weekly = data.days.count > 120
        return Chart {
            ForEach(data.days) { day in
                BarMark(x: .value("Day", day.date, unit: weekly ? .weekOfYear : .day), y: .value("Episodes", day.count))
                    .foregroundStyle(Color.dsBite)
            }
            if !weekly {
            RuleMark(y: .value("Average", average))
                .foregroundStyle(Color.dsTextSecondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("avg \(average.formatted(.number.precision(.fractionLength(1))))")
                        .font(.caption2)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 200)
    }

    private func heatmap(_ data: InsightsData) -> some View {
        Chart(data.cells) { cell in
            let row = Double(6 - (data.weekdayOrder.firstIndex(of: cell.weekday) ?? 0)) // first weekday on top
            RectangleMark(xStart: .value("Hour", Double(cell.hour) + 0.05), xEnd: .value("Hour", Double(cell.hour) + 0.95),
                          yStart: .value("Day", row + 0.08), yEnd: .value("Day", row + 0.92))
                .foregroundStyle(by: .value("Episodes", cell.count))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale(range: Gradient(colors: [Color.dsSurfaceMuted, Color.dsBite]))
        // Numeric rows so the labels sit centered on them.
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(position: .leading, values: (0..<7).map { Double($0) + 0.5 }) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(data.weekdayOrder[6 - Int(v)]) }
                }
            }
        }
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self),
                       let date = Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now) {
                        Text(date.formatted(.dateTime.hour()))
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
    }
}
