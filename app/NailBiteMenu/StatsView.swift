import SwiftUI
import Charts

private enum DateRangeOption: String, CaseIterable, Identifiable {
    case last7Days = "7D"
    case last30Days = "30D"
    case last90Days = "90D"
    case allTime = "All"
    
    var id: String { self.rawValue }
    
    var fullName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .last90Days: return "Last 90 Days"
        case .allTime: return "All Time"
        }
    }
}

struct StatsView: View {
    @ObservedObject var tracker: HabitTracker
    
    @State private var selectedRange: DateRangeOption = .last30Days
    @State private var selectedDailyDate: Date?
    @State private var selectedDailyCount: Int?
    @State private var selectedWeekday: String?
    @State private var selectedWeekdayCount: Int?
    @State private var selectedHour: String?
    @State private var selectedHourCount: Int?

    private var stats: StatisticsViewModel {
        StatisticsViewModel(detections: tracker.detections, range: selectedRange)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                headerSection
                
                VStack(spacing: 24) {
                    heroMetricsSection
                    
                    dailyTrendSection
                    
                    analysisGrid
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("")
        .onChange(of: selectedRange) {
            clearChartSelections()
        }
    }
    
    private func clearChartSelections() {
        selectedDailyDate = nil
        selectedDailyCount = nil
        selectedWeekday = nil
        selectedWeekdayCount = nil
        selectedHour = nil
        selectedHourCount = nil
    }

    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Track your progress and identify patterns")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(DateRangeOption.allCases) { option in
                        Button(action: { selectedRange = option }) {
                            Text(option.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedRange == option ? .white : .primary)
                                .frame(width: 44, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selectedRange == option ? Color.blue : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.05),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var heroMetricsSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.orange)
                    
                    Spacer()
                    
                    trendBadge
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(stats.totalDetections)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Total Detections")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    compactMetricCard(
                        icon: "calendar",
                        value: "\(stats.numberOfDays)",
                        label: "Days Tracked",
                        color: .blue
                    )
                    
                    compactMetricCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: String(format: "%.1f", stats.dailyAverage),
                        label: "Daily Average",
                        color: .purple
                    )
                }
                
                compactMetricCard(
                    icon: "flame.fill",
                    value: stats.mostActiveWeekday?.key ?? "N/A",
                    label: "Most Active Day",
                    color: .orange,
                    wide: true
                )
            }
        }
    }
    
    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: stats.trend.icon)
                .font(.system(size: 12, weight: .bold))
            Text(stats.trend.formattedValue)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(stats.trend.color == .green ? .green : stats.trend.color == .red ? .red : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(stats.trend.color.opacity(0.15))
        )
    }
    
    private func compactMetricCard(icon: String, value: String, label: String, color: Color, wide: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: wide ? 64 : 72)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    
    private var dailyTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Activity")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(selectedRange.fullName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let selectedDailyDate, let selectedDailyCount {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(selectedDailyCount)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                        
                        Text(selectedDailyDate.formatted(.dateTime.month().day()))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if stats.dailyCounts.isEmpty {
                noDataView(height: 240)
            } else {
                Chart {
                    ForEach(stats.dailyCounts) { data in
                        BarMark(
                            x: .value("Date", data.date, unit: .day),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                        .opacity(selectedDailyDate == nil || selectedDailyDate == data.date ? 1.0 : 0.3)
                    }
                    
                    if !stats.dailyCounts.isEmpty {
                        RuleMark(y: .value("Average", stats.dailyAverage))
                            .foregroundStyle(.orange.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Avg")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(.orange.opacity(0.15))
                                    )
                            }
                    }
                }
                .frame(height: 240)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day(), centered: true)
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.1))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.1))
                    }
                }
                .chartXSelection(value: $selectedDailyDate)
                .onChange(of: selectedDailyDate) { oldValue, newDate in
                    if let newDate = newDate,
                       let dataPoint = stats.dailyCounts.first(where: {
                           Calendar.current.isDate($0.date, inSameDayAs: newDate)
                       }) {
                        selectedDailyCount = dataPoint.count
                    } else {
                        selectedDailyCount = nil
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    
    private var analysisGrid: some View {
        HStack(spacing: 16) {
            chartCard(
                title: "By Weekday",
                subtitle: "Pattern analysis",
                color: .purple
            ) {
                if stats.weekdayCounts.isEmpty || stats.weekdayCounts.allSatisfy({ $0.count == 0 }) {
                    noDataView(height: 220)
                } else {
                    Chart(stats.weekdayCounts) { data in
                        BarMark(
                            x: .value("Count", data.count),
                            y: .value("Day", data.key)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(6)
                        .opacity(selectedWeekday == nil || selectedWeekday == data.key ? 1.0 : 0.3)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisValueLabel()
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.1))
                        }
                    }
                    .frame(height: 220)
                    .chartYSelection(value: $selectedWeekday)
                    .onChange(of: selectedWeekday) { oldValue, newDay in
                        if let newDay = newDay,
                           let dataPoint = stats.weekdayCounts.first(where: { $0.key == newDay }) {
                            selectedWeekdayCount = dataPoint.count
                        } else {
                            selectedWeekdayCount = nil
                        }
                    }
                    
                    if let selectedWeekday, let selectedWeekdayCount {
                        HStack {
                            Text(selectedWeekday)
                                .font(.system(size: 13, weight: .semibold))
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text("\(selectedWeekdayCount) detections")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            
            chartCard(
                title: "By Hour",
                subtitle: "Time patterns",
                color: .orange
            ) {
                if stats.hourlyCounts.isEmpty || stats.hourlyCounts.allSatisfy({ $0.count == 0 }) {
                    noDataView(height: 220)
                } else {
                    Chart(stats.hourlyCounts) { data in
                        BarMark(
                            x: .value("Hour", data.key),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                        .opacity(selectedHour == nil || selectedHour == data.key ? 1.0 : 0.3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 3)) { _ in
                            AxisValueLabel()
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.1))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.primary.opacity(0.1))
                        }
                    }
                    .frame(height: 220)
                    .chartXSelection(value: $selectedHour)
                    .onChange(of: selectedHour) { oldValue, newHour in
                        if let newHour = newHour,
                           let dataPoint = stats.hourlyCounts.first(where: { $0.key == newHour }) {
                            selectedHourCount = dataPoint.count
                        } else {
                            selectedHourCount = nil
                        }
                    }
                    
                    if let selectedHour, let selectedHourCount {
                        HStack {
                            Text(selectedHour)
                                .font(.system(size: 13, weight: .semibold))
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text("\(selectedHourCount) detections")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    private func chartCard<Content: View>(
        title: String,
        subtitle: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    
    private func noDataView(height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No data available")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

private struct StatisticsViewModel {
    
    let filteredDetections: [Date]
    let dailyCounts: [DailyCount]
    let hourlyCounts: [GroupedCount]
    let weekdayCounts: [GroupedCount]
    
    let totalDetections: Int
    let dailyAverage: Double
    let mostActiveWeekday: GroupedCount?
    let trend: Trend
    let numberOfDays: Int

    init(detections: [Date], range: DateRangeOption) {
        
        let (start, end) = StatisticsViewModel.dateRange(from: range, detections: detections)
        
        self.filteredDetections = detections.filter { $0 >= start && $0 < end }
        self.totalDetections = filteredDetections.count
        
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1
        self.numberOfDays = max(days, 1)
        self.dailyAverage = Double(totalDetections) / Double(self.numberOfDays)

        var dailyData = [Date: Int]()
        var currentDate = start
        while currentDate < end {
            dailyData[currentDate] = 0
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        let groupedByDay = Dictionary(grouping: filteredDetections, by: { $0.startOfDay })
        for (date, detections) in groupedByDay {
            dailyData[date] = detections.count
        }
        
        self.dailyCounts = dailyData
            .map { DailyCount(date: $0.key, count: $0.value) }
            .sorted(by: { $0.date < $1.date })
        
        let groupedByWeekday = Dictionary(grouping: filteredDetections, by: { $0.weekdaySymbol })
        let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        self.weekdayCounts = weekdaySymbols.map { day in
            GroupedCount(key: day, count: groupedByWeekday[day]?.count ?? 0)
        }
        self.mostActiveWeekday = self.weekdayCounts
            .filter { $0.count > 0 }
            .max(by: { $0.count < $1.count })
        
        let groupedByHour = Dictionary(grouping: filteredDetections, by: { $0.hourOfDay })
        self.hourlyCounts = (0...23).map { hour in
            let key: String
            switch hour {
            case 0: key = "12 AM"
            case 1...11: key = "\(hour) AM"
            case 12: key = "12 PM"
            default: key = "\(hour % 12) PM"
            }
            return GroupedCount(key: key, count: groupedByHour[hour]?.count ?? 0)
        }
        
        self.trend = Trend(allDetections: detections)
    }
    
    static func dateRange(from range: DateRangeOption, detections: [Date]) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: Date().startOfDay) ?? Date()
        var start: Date
        
        switch range {
        case .last7Days:
            start = calendar.date(byAdding: .day, value: -7, to: end)!
        case .last30Days:
            start = calendar.date(byAdding: .day, value: -30, to: end)!
        case .last90Days:
            start = calendar.date(byAdding: .day, value: -90, to: end)!
        case .allTime:
            start = detections.min()?.startOfDay ?? Date().startOfDay
        }
        
        return (start.startOfDay, end)
    }
}

private struct DailyCount: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct GroupedCount: Identifiable, Hashable {
    let id = UUID()
    let key: String
    let count: Int
}

private struct Trend {
    let changePercent: Double?
    
    init(allDetections: [Date]) {
        let now = Date()
        let todayStart = now.startOfDay
        let lastWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: todayStart)!
        let twoWeeksStart = Calendar.current.date(byAdding: .day, value: -14, to: todayStart)!

        let recentDetections = allDetections.filter { $0 >= lastWeekStart && $0 < todayStart }.count
        let previousDetections = allDetections.filter { $0 >= twoWeeksStart && $0 < lastWeekStart }.count

        if previousDetections > 0 {
            self.changePercent = (Double(recentDetections) - Double(previousDetections)) / Double(previousDetections)
        } else if recentDetections > 0 {
            self.changePercent = 1.0
        } else {
            self.changePercent = 0.0
        }
    }
    
    var formattedValue: String {
        guard let change = changePercent else { return "N/A" }
        return String(format: "%+.0f%%", change * 100)
    }
    
    var color: Color {
        guard let change = changePercent else { return .secondary }
        if change < -0.01 { return .green }
        if change > 0.01 { return .red }
        return .secondary
    }
    
    var icon: String {
        guard let change = changePercent else { return "minus" }
        if change < -0.01 { return "arrow.down.right" }
        if change > 0.01 { return "arrow.up.right" }
        return "minus"
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var weekdaySymbol: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: self)
    }
    
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: self)
    }
}

#Preview {
    let previewTracker: HabitTracker = {
        let tracker = HabitTracker()
        var dates: [Date] = []
        for _ in 0..<500 {
            let day = Int.random(in: -90...0)
            let hour = Int.random(in: 8...23)
            if let date = Calendar.current.date(byAdding: .day, value: day, to: Date()),
               let finalDate = Calendar.current.date(bySetting: .hour, value: hour, of: date) {
                dates.append(finalDate)
            }
        }
        tracker.detections = dates
        return tracker
    }()
    
    return NavigationStack {
        StatsView(tracker: previewTracker)
    }
}
