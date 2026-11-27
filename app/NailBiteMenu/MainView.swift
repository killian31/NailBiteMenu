import SwiftUI
import Charts
import AppKit

enum MainSection: String, CaseIterable, Identifiable {
    case today, insights, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .insights: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }

    /// Shared with the menu panel so its buttons can open a specific section.
    static let storageKey = "mainSection"
}

struct MainView: View {
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tracker: HabitTracker
    @AppStorage(MainSection.storageKey) private var section: MainSection = .today

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: Binding(get: { section }, set: { if let s = $0 { section = s } })) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            Group {
                switch section {
                case .today: TodayView(monitor: monitor, tracker: tracker)
                case .insights: InsightsView(tracker: tracker)
                case .settings: SettingsView(preferences: preferences, tracker: tracker, monitor: monitor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.dsBackground)
            .foregroundStyle(Color.dsText)
            .transition(.opacity)
            .animation(DS.Motion.snappy, value: section)
        }
        .navigationTitle(section.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    collapseAppToMenuBar()
                } label: {
                    Label("Hide to Menu Bar", systemImage: "menubar.arrow.up.rectangle")
                }
                .help("Close the window. Monitoring keeps running from the menu bar.")
            }
        }
        .frame(minWidth: 820, minHeight: 600)
    }
}

// MARK: - Today

struct TodayView: View {
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var tracker: HabitTracker

    var body: some View {
        let episodes = tracker.episodes
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let today = episodes.filter { $0.start >= todayStart }
        let yesterday = episodes.filter { $0.start >= todayStart.addingTimeInterval(-86_400) && $0.start < todayStart }
        let weekStart = todayStart.addingTimeInterval(-6 * 86_400)
        let week = episodes.filter { $0.start >= weekStart }
        let lastWeek = episodes.filter { $0.start >= weekStart.addingTimeInterval(-7 * 86_400) && $0.start < weekStart }
        let streak = Insights.biteFreeStreak(episodes: episodes, activeDays: tracker.activeDays)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero(lastBite: tracker.records.last?.date, lastApp: episodes.last?.app)

                HStack(spacing: 14) {
                    StatTile(title: "Today", value: "\(today.count)",
                             detail: compare(today.count, yesterday.count, "yesterday"),
                             symbol: "hand.raised", tint: .dsBiteText)
                    StatTile(title: "Last 7 days", value: "\(week.count)",
                             detail: compare(week.count, lastWeek.count, "the week before"),
                             symbol: "calendar", tint: .dsTextSecondary)
                    StatTile(title: "Bite-free streak", value: streak == 1 ? "1 day" : "\(streak) days",
                             detail: "Days you used your Mac", symbol: "flame", tint: .dsWin)
                }

                Panel(title: "Today by hour") {
                    if today.isEmpty {
                        EmptyNote(symbol: "sparkles", text: "No episodes today. Keep it going.")
                    } else {
                        HourChart(episodes: today)
                            .frame(height: 140)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    Panel(title: "Top triggers this week") {
                        TriggerList(apps: Array(Insights.triggerApps(week).prefix(4)))
                    }
                    Panel(title: "Recent episodes") {
                        RecentList(episodes: Array(episodes.suffix(5).reversed()))
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
    }

    private func hero(lastBite: Date?, lastApp: String?) -> some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(lastBite == nil ? "No bites recorded yet" : "Bite-free for")
                    .font(.title3)
                    .foregroundStyle(Color.dsTextSecondary)
                if let lastBite {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let text = ctx.date.timeIntervalSince(lastBite).shortDuration
                        Text(text)
                            .font(.dsNumber(56, weight: .bold))
                            .foregroundStyle(Color.dsWin)
                            .contentTransition(.numericText())
                            .animation(DS.Motion.counter, value: text)
                    }
                    Text("Last episode \(Self.when(lastBite))\(lastApp.map { " in \($0)" } ?? "")")
                        .font(.callout)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                Label(monitor.isRunning ? "Monitoring" : "Paused",
                      systemImage: monitor.isRunning ? "circle.fill" : "pause.circle")
                    .symbolEffect(.pulse, options: .repeating, isActive: monitor.isRunning)
                    .imageScale(.small)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(monitor.isRunning ? Color.dsWin : Color.dsTextSecondary)
                Button {
                    withAnimation(.snappy) { monitor.isRunning.toggle() }
                } label: {
                    Label(monitor.isRunning ? "Pause" : "Start Monitoring",
                          systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
                }
                .controlSize(.large)
                    .glassButton(prominent: true)
            }
        }
        .padding(24)
        .card(cornerRadius: DS.Radius.sheet)
    }

    /// "today at 14:05", "yesterday at 21:38", "24 Nov at 09:12"
    private static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today at \(time)" }
        if cal.isDateInYesterday(date) { return "yesterday at \(time)" }
        return "\(date.formatted(.dateTime.day().month())) at \(time)"
    }

    private func compare(_ a: Int, _ b: Int, _ label: String) -> String {
        if a == b { return "Same as \(label)" }
        return a < b ? "\(b - a) fewer than \(label)" : "\(a - b) more than \(label)"
    }
}

// MARK: - Shared pieces (also used by Insights)

struct StatTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.medium))
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.dsNumber(28, weight: .bold))
                .foregroundStyle(Color.dsText)
                .contentTransition(.numericText())
                .animation(DS.Motion.counter, value: value)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct Panel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .card()
    }
}

struct EmptyNote: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(Color.dsTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}

struct HourChart: View {
    let episodes: [Episode]

    var body: some View {
        let counts = Dictionary(grouping: episodes) { Calendar.current.component(.hour, from: $0.start) }
            .mapValues(\.count)
        Chart(0..<24, id: \.self) { hour in
            BarMark(x: .value("Hour", hour), y: .value("Episodes", counts[hour] ?? 0))
                .foregroundStyle(Color.dsBite)
                .cornerRadius(4)
        }
        .chartXScale(domain: 0...23)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) { Text(hourLabel(h)) }
                }
            }
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
    }

    private func hourLabel(_ h: Int) -> String {
        Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)?
            .formatted(.dateTime.hour()) ?? "\(h)"
    }
}

struct TriggerList: View {
    let apps: [(name: String, bundleID: String?, count: Int)]

    var body: some View {
        if apps.isEmpty {
            EmptyNote(symbol: "app.dashed", text: "No trigger apps recorded yet")
        } else {
            let top = apps.first?.count ?? 1
            VStack(spacing: 10) {
                ForEach(apps, id: \.name) { app in
                    HStack(spacing: 10) {
                        AppIcon(bundleID: app.bundleID)
                        Text(app.name)
                            .lineLimit(1)
                        Spacer()
                        Text("\(app.count)")
                            .monospacedDigit()
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(Color.dsBite.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(app.count) / CGFloat(top), height: 3)
                                .offset(y: 6)
                        }
                        .frame(height: 3)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }
}

struct RecentList: View {
    let episodes: [Episode]

    var body: some View {
        if episodes.isEmpty {
            EmptyNote(symbol: "checkmark.circle", text: "No episodes recorded")
        } else {
            VStack(spacing: 10) {
                ForEach(episodes) { e in
                    HStack(spacing: 10) {
                        AppIcon(bundleID: e.bundleID)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.app ?? "Episode")
                                .lineLimit(1)
                            Text(e.start.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        Spacer()
                        Text(e.duration.shortDuration)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
            }
        }
    }
}

struct AppIcon: View {
    let bundleID: String?

    var body: some View {
        Group {
            if let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                Image(systemName: "hand.raised.circle")
                    .resizable()
                    .foregroundStyle(Color.dsTextSecondary)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}
