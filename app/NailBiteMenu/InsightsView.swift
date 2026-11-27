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
    var context: String {
        switch self {
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .quarter: return "Last 90 days"
        case .all: return "Since you started"
        }
    }
}

/// Everything the page shows, computed once per render.
private struct InsightsData {
    struct Bucket: Identifiable {
        let date: Date
        let count: Int
        /// Rolling average ending on this bucket (7 days, or 4 weeks in weekly mode).
        let trend: Double
        /// Monitored, and no episode.
        let clean: Bool
        var id: Date { date }
    }
    struct Cell: Identifiable { let row: Int; let hour: Int; let count: Int; var id: Int { row * 24 + hour } }

    let episodes: [Episode]
    let buckets: [Bucket]
    let weekly: Bool
    let perActiveDay: Double
    let averageLength: TimeInterval
    let biteFreeDays: Int
    let activeDayCount: Int
    /// Rows in display order: first weekday of the locale on top.
    let cells: [Cell]
    let weekdayOrder: [String]
    let peak: Cell?
    let previousCount: Int?

    init(all: [Episode], activeDays: Set<Date>, range: InsightsRange, calendar cal: Calendar = .current) {
        let today = cal.startOfDay(for: .now)
        let earliest = (all.map(\.start) + activeDays).min().map { cal.startOfDay(for: $0) } ?? today
        let start = range.days.map { cal.date(byAdding: .day, value: -($0 - 1), to: today)! } ?? earliest

        episodes = all.filter { $0.start >= start }
        let byDay = Dictionary(grouping: episodes) { cal.startOfDay(for: $0.start) }.mapValues(\.count)
        let active = activeDays.filter { $0 >= start && $0 <= today }

        var days: [(Date, Int, Bool)] = []
        var d = start
        while d <= today {
            days.append((d, byDay[d] ?? 0, active.contains(d) && byDay[d] == nil))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        // Long ranges read better as weeks.
        weekly = days.count > 120
        var raw: [(Date, Int, Bool)] = days
        if weekly {
            let grouped = Dictionary(grouping: days) { cal.dateInterval(of: .weekOfYear, for: $0.0)!.start }
            raw = grouped.keys.sorted().map { key in
                let group = grouped[key]!
                return (key, group.map(\.1).reduce(0, +), group.allSatisfy(\.2))
            }
        }
        let window = weekly ? 4 : 7
        buckets = raw.indices.map { i in
            let slice = raw[max(0, i - window + 1)...i]
            let avg = Double(slice.map(\.1).reduce(0, +)) / Double(slice.count)
            return Bucket(date: raw[i].0, count: raw[i].1, trend: avg, clean: raw[i].2)
        }

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
        let weekdays = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 } // calendar weekday numbers, display order
        weekdayOrder = weekdays.map { symbols[$0 - 1] }
        let grid = Dictionary(grouping: episodes) {
            "\(cal.component(.weekday, from: $0.start))-\(cal.component(.hour, from: $0.start))"
        }.mapValues(\.count)
        cells = weekdays.enumerated().flatMap { row, wd in
            (0..<24).map { h in Cell(row: row, hour: h, count: grid["\(wd)-\(h)"] ?? 0) }
        }
        peak = cells.max { $0.count < $1.count }.flatMap { $0.count > 0 ? $0 : nil }
    }
}

struct InsightsView: View {
    @ObservedObject var tracker: HabitTracker
    @State private var range: InsightsRange = .month

    var body: some View {
        let data = InsightsData(all: tracker.episodes, activeDays: tracker.activeDays, range: range)

        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                PageHeader(context: range.context, title: "Insights") {
                    Picker("Range", selection: $range) {
                        ForEach(InsightsRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                hero(data)

                if data.episodes.isEmpty {
                    Panel(title: "No episodes in this range") {
                        EmptyNote(text: "Nothing to chart yet. That’s the goal.")
                    }
                } else {
                    HStack(alignment: .top, spacing: DS.Space.m) {
                        Panel(title: "When it happens", meta: peakText(data)) { heatmap(data) }
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                        Panel(title: "Trigger apps", meta: "\(data.episodes.count) episodes") {
                            TriggerList(apps: Array(Insights.triggerApps(data.episodes).prefix(5)))
                        }
                        .frame(width: 300)
                    }
                }
            }
            .padding(.horizontal, DS.Space.xxl)
            .padding(.top, 44)
            .padding(.bottom, DS.Space.xxl)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Hero: the count, how it moved, and the chart that shows it

    private func hero(_ data: InsightsData) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {
            HStack(alignment: .bottom, spacing: DS.Space.xxl) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Episodes")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.dsTextSecondary)
                    Text("\(data.episodes.count)")
                        .font(.dsFigure(132))
                        .foregroundStyle(data.episodes.isEmpty ? Color.dsText : Color.dsSignalText)
                        .contentTransition(.numericText())
                        .padding(.top, -6)
                    trendLine(data)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: DS.Space.xl) {
                    figure("Per day", data.perActiveDay.formatted(.number.precision(.fractionLength(1))),
                           "per watched day")
                    figure("Typical length", data.averageLength.shortDuration, "per episode")
                    figure("Bite-free days", "\(data.biteFreeDays)", "of \(data.activeDayCount) watched")
                }
                .padding(.bottom, 2)
            }

            if !data.episodes.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    legend(weekly: data.weekly)
                    dailyChart(data)
                }
            }
        }
        .padding(DS.Space.xl + 4)
        .card(cornerRadius: DS.Radius.sheet)
    }

    private func figure(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.dsCaption.weight(.medium))
                .foregroundStyle(Color.dsTextSecondary)
            Text(value)
                .font(.dsFigure(44))
                .contentTransition(.numericText())
            Text(detail)
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextTertiary)
                .lineLimit(1)
        }
        .frame(minWidth: 112, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func trendLine(_ data: InsightsData) -> some View {
        if let prev = data.previousCount {
            let now = data.episodes.count
            let (text, better): (String, Bool) = {
                if prev == 0 { return (now == 0 ? "Same as the period before" : "None in the period before", now == 0) }
                if now == prev { return ("Same as the period before", true) }
                let pct = Int((abs(Double(now - prev)) / Double(prev) * 100).rounded())
                return now < prev ? ("\(pct)% fewer than the period before", true)
                                  : ("\(pct)% more than the period before", false)
            }()
            Label(text, systemImage: better ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(better ? Color.dsText : Color.dsSignalText)
        } else {
            Text("Since you started")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.dsTextSecondary)
        }
    }

    private func legend(weekly: Bool) -> some View {
        HStack(spacing: DS.Space.l) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1).fill(Color.dsTextTertiary.opacity(0.45)).frame(width: 8, height: 10)
                Text(weekly ? "Per week" : "Per day")
            }
            HStack(spacing: 6) {
                Capsule().fill(Color.dsSignal).frame(width: 14, height: 3)
                Text(weekly ? "4-week average" : "7-day average")
            }
            HStack(spacing: 6) {
                Circle().fill(Color.dsText).frame(width: 5, height: 5)
                Text(weekly ? "Bite-free week" : "Bite-free day")
            }
        }
        .dsAxisLabels()
        .accessibilityHidden(true)
    }

    /// Neutral bars for the raw counts, one vermilion line for the trend that matters.
    private func dailyChart(_ data: InsightsData) -> some View {
        let unit: Calendar.Component = data.weekly ? .weekOfYear : .day
        let last = data.buckets.last
        return Chart {
            ForEach(data.buckets) { b in
                BarMark(x: .value("Date", b.date, unit: unit), y: .value("Episodes", b.count), width: .ratio(0.62))
                    .foregroundStyle(Color.dsTextTertiary.opacity(0.32))
                    .cornerRadius(2)
                if b.clean {
                    PointMark(x: .value("Date", b.date, unit: unit), y: .value("Episodes", 0))
                        .symbolSize(18)
                        .foregroundStyle(Color.dsText)
                }
            }
            ForEach(data.buckets) { b in
                LineMark(x: .value("Date", b.date, unit: unit), y: .value("Average", b.trend))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.dsSignal)
            }
            if let last {
                PointMark(x: .value("Date", last.date, unit: unit), y: .value("Average", last.trend))
                    .symbolSize(60)
                    .foregroundStyle(Color.dsSignal)
                    .annotation(position: .top, alignment: .trailing, spacing: 6) {
                        Text(last.trend.formatted(.number.precision(.fractionLength(1))))
                            .font(.dsFigure(22))
                            .foregroundStyle(Color.dsSignalText)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.dsMeta).foregroundStyle(Color.dsTextTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.dsBorder)
                AxisValueLabel().font(.dsMeta).foregroundStyle(Color.dsTextTertiary)
            }
        }
        .frame(height: 260)
        .accessibilityLabel("Episodes per \(data.weekly ? "week" : "day"), with the rolling average")
    }

    // MARK: Heatmap

    private func peakText(_ data: InsightsData) -> String? {
        guard let peak = data.peak,
              let date = Calendar.current.date(bySettingHour: peak.hour, minute: 0, second: 0, of: .now) else { return nil }
        return "Most often \(data.weekdayOrder[peak.row]) around \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func heatmap(_ data: InsightsData) -> some View {
        let top = Double(max(1, data.peak?.count ?? 1))
        return Chart(data.cells) { cell in
            let y = Double(6 - cell.row) // first weekday on top
            RectangleMark(xStart: .value("Hour", Double(cell.hour) + 0.06), xEnd: .value("Hour", Double(cell.hour) + 0.94),
                          yStart: .value("Day", y + 0.08), yEnd: .value("Day", y + 0.92))
                .foregroundStyle(cell.count == 0 ? Color.dsSurfaceRaised
                                                 : Color.dsSignal.opacity(0.18 + 0.82 * Double(cell.count) / top))
                .cornerRadius(3)
        }
        .chartYScale(domain: 0...7)
        .chartYAxis {
            AxisMarks(position: .leading, values: (0..<7).map { Double($0) + 0.5 }) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text(data.weekdayOrder[6 - Int(v)]).dsAxisLabels() }
                }
            }
        }
        .chartXScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self),
                       let date = Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now) {
                        Text(date.formatted(.dateTime.hour())).dsAxisLabels()
                    }
                }
            }
        }
        .frame(height: 210)
        .accessibilityLabel("Episodes by weekday and hour")
    }
}
