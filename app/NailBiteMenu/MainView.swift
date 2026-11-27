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

    var shortcut: KeyEquivalent {
        switch self {
        case .today: return "1"
        case .insights: return "2"
        case .settings: return "3"
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
        HStack(spacing: 0) {
            Sidebar(section: $section, isRunning: monitor.isRunning)
            Rectangle().fill(Color.dsBorder).frame(width: 1)
            Group {
                switch section {
                case .today: TodayView(monitor: monitor, tracker: tracker)
                case .insights: InsightsView(tracker: tracker)
                case .settings: SettingsView(preferences: preferences, tracker: tracker, monitor: monitor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.dsBackground)
        .foregroundStyle(Color.dsText)
        .ignoresSafeArea()
        .navigationTitle(section.title)
        .frame(minWidth: 880, minHeight: 640)
    }
}

/// Custom sidebar: three rows, the live status, and a way back to the menu bar.
private struct Sidebar: View {
    @Binding var section: MainSection
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("NailBite")
                    .font(.system(size: 17, weight: .semibold))
                LiveStatus(isOn: isRunning)
            }
            .padding(.horizontal, DS.Space.m)
            .padding(.top, 52) // clears the window controls
            .padding(.bottom, DS.Space.xl)

            VStack(spacing: 2) {
                ForEach(MainSection.allCases) { item in
                    Button { section = item } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .frame(width: 18)
                                .foregroundStyle(section == item ? Color.dsText : Color.dsTextTertiary)
                            Text(item.title)
                            Spacer()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(section == item ? Color.dsText : Color.dsTextSecondary)
                        .padding(.horizontal, DS.Space.m)
                        .frame(height: 32)
                        .background(section == item ? Color.dsSurfaceRaised : .clear,
                                    in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(item.shortcut, modifiers: .command)
                    .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }

            Spacer()

            Button(action: collapseAppToMenuBar) {
                HStack(spacing: 10) {
                    Image(systemName: "menubar.arrow.up.rectangle").frame(width: 18)
                    Text("Hide to Menu Bar")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dsTextSecondary)
                .padding(.horizontal, DS.Space.m)
                .frame(height: 32)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Close the window. NailBite keeps watching from the menu bar.")
            .padding(.bottom, DS.Space.m)
        }
        .padding(.horizontal, DS.Space.s)
        .frame(width: 208)
    }
}

/// Page header used by Today, Insights and Settings: a quiet line of context over the title.
struct PageHeader<Trailing: View>: View {
    let context: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(context)
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
                Text(title)
                    .font(.dsPageTitle)
            }
            Spacer()
            trailing
        }
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
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                PageHeader(context: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)), title: "Today") {
                    EmptyView()
                }

                hero(lastBite: tracker.records.last?.date, lastApp: episodes.last?.app)

                HStack(spacing: DS.Space.m) {
                    StatTile(title: "Episodes today", value: "\(today.count)",
                             detail: compare(today.count, yesterday.count, "yesterday"), marked: today.count > 0)
                    StatTile(title: "Last 7 days", value: "\(week.count)",
                             detail: compare(week.count, lastWeek.count, "the 7 days before"))
                    StatTile(title: "Bite-free streak", value: "\(streak)",
                             detail: "Days in a row without an episode")
                }

                Panel(title: "Today by hour") {
                    if today.isEmpty {
                        EmptyNote(text: "No episodes today")
                    } else {
                        HourChart(episodes: today)
                            .frame(height: 160)
                    }
                }

                HStack(alignment: .top, spacing: DS.Space.m) {
                    Panel(title: "Top triggers", meta: "7 days") {
                        TriggerList(apps: Array(Insights.triggerApps(week).prefix(4)))
                    }
                    Panel(title: "Recent episodes") {
                        RecentList(episodes: Array(episodes.suffix(5).reversed()))
                    }
                }
            }
            .padding(.horizontal, DS.Space.xxl)
            .padding(.top, 44)
            .padding(.bottom, DS.Space.xxl)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
    }

    private func hero(lastBite: Date?, lastApp: String?) -> some View {
        HStack(alignment: .bottom, spacing: DS.Space.xl) {
            VStack(alignment: .leading, spacing: 0) {
                Text(lastBite == nil ? "Nothing recorded yet" : "Bite-free for")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.dsTextSecondary)
                BiteFreeClock(since: lastBite, size: 120)
                    .padding(.top, -4)
                if let lastBite {
                    Text("Last episode \(Self.when(lastBite))\(lastApp.map { ", in \($0)" } ?? "")")
                        .font(.dsBody)
                        .foregroundStyle(Color.dsTextSecondary)
                }
            }
            Spacer()
            Button {
                withAnimation(DS.Motion.snappy) { monitor.isRunning.toggle() }
            } label: {
                Label(monitor.isRunning ? "Pause" : "Start Watching",
                      systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(InkButtonStyle(large: true))
        }
        .padding(DS.Space.xl + 4)
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

/// A label, a big figure, a comparison. Numbers only.
struct StatTile: View {
    let title: String
    let value: String
    let detail: String
    var marked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.dsCaption.weight(.medium))
                .foregroundStyle(Color.dsTextSecondary)
                .lineLimit(1)
            Text(value)
                .font(.dsFigure(52))
                .foregroundStyle(marked ? Color.dsSignalText : Color.dsText)
                .contentTransition(.numericText())
                .animation(DS.Motion.counter, value: value)
            Text(detail)
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextTertiary)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.l + 4)
        .card()
        .signalEdge(marked, inset: DS.Space.l + 4)
        .accessibilityElement(children: .combine)
    }
}

struct Panel<Content: View>: View {
    let title: String
    var meta: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.l) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.dsHeadline)
                Spacer()
                if let meta {
                    Text(meta)
                        .font(.dsMeta)
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.l + 4)
        .card()
    }
}

struct EmptyNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.dsBody)
            .foregroundStyle(Color.dsTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 64)
    }
}

/// Shared chart axis styling: mono labels, hairline grid.
extension View {
    func dsAxisLabels() -> some View {
        font(.dsMeta).foregroundStyle(Color.dsTextTertiary)
    }
}

struct HourChart: View {
    let episodes: [Episode]

    var body: some View {
        let counts = Dictionary(grouping: episodes) { Calendar.current.component(.hour, from: $0.start) }
            .mapValues(\.count)
        let now = Calendar.current.component(.hour, from: .now)
        Chart {
            ForEach(counts.sorted { $0.key < $1.key }, id: \.key) { (hour: Int, count: Int) in
                let x = Double(hour)
                RectangleMark(xStart: .value("Hour", x - 0.36), xEnd: .value("Hour", x + 0.36),
                        yStart: .value("Episodes", 0), yEnd: .value("Episodes", count))
                    .foregroundStyle(Color.dsSignal)
                    .cornerRadius(3)
            }
            RuleMark(x: .value("Now", Double(now) + 0.5))
                .foregroundStyle(Color.dsTextTertiary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .annotation(position: .top, alignment: .center, spacing: 2) {
                    Text("now").dsAxisLabels()
                }
        }
        .chartXScale(domain: -0.5...23.5)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                AxisValueLabel {
                    if let h = value.as(Int.self) { Text(hourLabel(h)).dsAxisLabels() }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.dsBorder)
                AxisValueLabel().font(.dsMeta).foregroundStyle(Color.dsTextTertiary)
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)?
            .formatted(.dateTime.hour()) ?? "\(h)"
    }
}

/// Ranked apps with a thin share bar. The top one carries the signal, the rest stay neutral.
struct TriggerList: View {
    let apps: [(name: String, bundleID: String?, count: Int)]

    var body: some View {
        if apps.isEmpty {
            EmptyNote(text: "No trigger apps recorded yet")
        } else {
            let top = apps.first?.count ?? 1
            let total = max(1, apps.map(\.count).reduce(0, +))
            VStack(spacing: DS.Space.m) {
                ForEach(Array(apps.enumerated()), id: \.element.name) { index, app in
                    VStack(spacing: 6) {
                        HStack(spacing: 10) {
                            AppIcon(bundleID: app.bundleID)
                            Text(app.name)
                                .font(.dsBody)
                                .lineLimit(1)
                            Spacer()
                            Text("\(app.count)")
                                .font(.dsMeta)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.dsSurfaceRaised)
                                Capsule()
                                    .fill(index == 0 ? Color.dsSignal : Color.dsTextTertiary.opacity(0.6))
                                    .frame(width: geo.size.width * CGFloat(app.count) / CGFloat(top))
                            }
                        }
                        .frame(height: 3)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(app.name), \(app.count) episodes, \(app.count * 100 / total) percent")
                }
            }
        }
    }
}

struct RecentList: View {
    let episodes: [Episode]

    var body: some View {
        if episodes.isEmpty {
            EmptyNote(text: "No episodes recorded")
        } else {
            VStack(spacing: 0) {
                ForEach(episodes) { e in
                    HStack(spacing: 10) {
                        Text(Self.stamp(e.start))
                            .font(.dsMeta)
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(width: 64, alignment: .leading)
                        AppIcon(bundleID: e.bundleID)
                        Text(e.app ?? "Unknown app")
                            .font(.dsBody)
                            .lineLimit(1)
                        Spacer()
                        Text(e.duration.shortDuration)
                            .font(.dsMeta)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                    .frame(height: 32)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// "14:05" today, "Tue 21:38" this week, "24 Nov" before.
    private static func stamp(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if date > Date.now.addingTimeInterval(-6 * 86_400) {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
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
                Image(systemName: "app.dashed")
                    .resizable()
                    .fontWeight(.light)
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(2)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}
