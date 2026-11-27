import SwiftUI
import AppKit

/// Compact status panel. Anything deeper lives in the main window (`onOpen`).
struct MenuContentView: View {
    @ObservedObject var monitor: MonitorViewModel
    let live: LiveStats
    @ObservedObject var tracker: HabitTracker
    let onOpen: (MainSection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NailBite")
                    .font(.dsHeadline)
                Spacer()
                LiveStatus(isOn: monitor.isRunning)
            }
            .padding(.horizontal, DS.Space.l)
            .frame(height: 44)

            Divider().overlay(Color.dsBorder)

            VStack(alignment: .leading, spacing: DS.Space.l) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tracker.records.isEmpty ? "Nothing recorded yet" : "Bite-free for")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                    BiteFreeClock(since: tracker.records.last?.date, size: 64)
                }

                LiveMeter(live: live, threshold: monitor.thresholdPercent / 100, isRunning: monitor.isRunning)

                Divider().overlay(Color.dsBorder)

                GlanceStats(tracker: tracker)

                if monitor.showDebug {
                    DebugStats(live: live)
                }

                HStack(spacing: DS.Space.s) {
                    Button {
                        withAnimation(DS.Motion.snappy) { monitor.isRunning.toggle() }
                    } label: {
                        Label(monitor.isRunning ? "Pause" : "Start", systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InkButtonStyle())
                    .help(monitor.isRunning ? "Pause watching" : "Start watching")

                    Button { onOpen(.today) } label: { Text("Today") }
                        .buttonStyle(QuietButtonStyle())
                    Button { onOpen(.insights) } label: { Text("Insights") }
                        .buttonStyle(QuietButtonStyle())
                    Button { onOpen(.settings) } label: { Image(systemName: "gearshape") }
                        .buttonStyle(QuietButtonStyle())
                        .help("Settings")
                        .accessibilityLabel("Settings")
                }
            }
            .padding(DS.Space.l)

            Divider().overlay(Color.dsBorder)

            HStack {
                Text("Keeps watching from the menu bar")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.dsCaption.weight(.medium))
                    .foregroundStyle(Color.dsTextSecondary)
                    .keyboardShortcut("q")
            }
            .padding(.horizontal, DS.Space.l)
            .frame(height: 40)
        }
        .frame(width: 340)
        .foregroundStyle(Color.dsText)
        .background(Color.dsBackground)
    }
}

/// Time since the last bite, ticking every second. Shared by the menu panel and Today.
struct BiteFreeClock: View {
    let since: Date?
    let size: CGFloat

    var body: some View {
        if let since {
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let text = ctx.date.timeIntervalSince(since).shortDuration
                Text(text)
                    .font(.dsFigure(size))
                    .contentTransition(.numericText())
                    .animation(DS.Motion.counter, value: text)
                    .accessibilityLabel("Bite-free for \(text)")
            }
        } else {
            Text("Day one")
                .font(.dsFigure(size))
        }
    }
}

/// Live detection level against the threshold. The only view that re-renders on every camera frame.
private struct LiveMeter: View {
    @ObservedObject var live: LiveStats
    let threshold: Double
    let isRunning: Bool

    var body: some View {
        let value = isRunning ? live.confidence : 0
        let over = value >= threshold
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Live signal")
                Spacer()
                Text(isRunning ? "\(Int((value * 100).rounded())) / \(Int((threshold * 100).rounded()))" : "–")
            }
            .font(.dsMeta)
            .foregroundStyle(Color.dsTextTertiary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dsSurfaceRaised)
                    Capsule()
                        .fill(over ? Color.dsSignal : Color.dsTextTertiary)
                        .frame(width: max(4, geo.size.width * value))
                        .opacity(isRunning ? 1 : 0)
                        .animation(.easeOut(duration: 0.15), value: value)
                    // Threshold notch
                    Rectangle()
                        .fill(Color.dsText)
                        .frame(width: 2, height: 10)
                        .offset(x: geo.size.width * threshold - 1)
                }
            }
            .frame(height: 4)
        }
        .help("How sure the model is, frame by frame. Past the notch counts as biting.")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live signal \(Int((value * 100).rounded())) percent, alert at \(Int((threshold * 100).rounded()))")
    }
}

/// Stats at a glance, so the window is only needed for the deep dive: a count, how it moved,
/// a small chart where the current hour or day carries the signal, and three supporting figures.
private struct GlanceStats: View {
    @ObservedObject var tracker: HabitTracker
    @AppStorage("menuRange") private var range: Range = .today

    enum Range: String, CaseIterable, Identifiable {
        case today = "Today", week = "Week", month = "Month"
        var id: String { rawValue }
    }

    private struct Bar: Identifiable { let x: Int; let count: Int; let current: Bool; var id: Int { x } }
    private struct Figure: Identifiable { let label: String; let value: String; var id: String { label } }

    private struct Summary {
        var count = 0
        var noun = ""
        var change = ""
        var better = true
        var bars: [Bar] = []
        var figures: [Figure] = []
    }

    var body: some View {
        let s = summary(range)
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Picker("Range", selection: $range) {
                ForEach(Range.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            HStack(alignment: .lastTextBaseline, spacing: DS.Space.s) {
                Text("\(s.count)")
                    .font(.dsFigure(44))
                    .foregroundStyle(s.count > 0 ? Color.dsSignalText : Color.dsText)
                    .contentTransition(.numericText())
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.noun)
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                    Text(s.change)
                        .font(.dsCaption.weight(.medium))
                        .foregroundStyle(s.better ? Color.dsText : Color.dsSignalText)
                }
                .padding(.bottom, 6)
            }
            .accessibilityElement(children: .combine)

            MiniBars(bars: s.bars)
                .frame(height: 44)

            HStack(spacing: 0) {
                ForEach(s.figures) { f in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.label)
                            .font(.dsMeta)
                            .foregroundStyle(Color.dsTextTertiary)
                            .lineLimit(1)
                        Text(f.value)
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func summary(_ range: Range) -> Summary {
        let cal = Calendar.current
        let now = Date.now
        let today = cal.startOfDay(for: now)
        let episodes = tracker.episodes
        var s = Summary()

        func pct(_ now: Int, _ before: Int, _ label: String) -> (String, Bool) {
            if before == 0 { return (now == 0 ? "Same as \(label)" : "None \(label)", now == 0) }
            if now == before { return ("Same as \(label)", true) }
            let p = Int((Double(abs(now - before)) / Double(before) * 100).rounded())
            return now < before ? ("\(p)% fewer than \(label)", true) : ("\(p)% more than \(label)", false)
        }

        switch range {
        case .today:
            let todays = episodes.filter { $0.start >= today }
            let yesterday = episodes.filter { $0.start >= today.addingTimeInterval(-86_400) && $0.start < today }.count
            let byHour = Dictionary(grouping: todays) { cal.component(.hour, from: $0.start) }.mapValues(\.count)
            let hour = cal.component(.hour, from: now)
            s.count = todays.count
            s.noun = todays.count == 1 ? "episode today" : "episodes today"
            if todays.count == yesterday { s.change = "Same as yesterday" }
            else { s.change = todays.count < yesterday ? "\(yesterday - todays.count) fewer than yesterday"
                                                       : "\(todays.count - yesterday) more than yesterday" }
            s.better = todays.count <= yesterday
            s.bars = (0..<24).map { Bar(x: $0, count: byHour[$0] ?? 0, current: $0 == hour) }
            let streak = Insights.biteFreeStreak(episodes: episodes, activeDays: tracker.activeDays)
            s.figures = [
                Figure(label: "Longest gap", value: Insights.longestBiteFree(episodes, from: today, to: now).shortDuration),
                Figure(label: "Yesterday", value: "\(yesterday)"),
                Figure(label: "Streak", value: streak == 1 ? "1 day" : "\(streak) days"),
            ]
        case .week, .month:
            let n = range == .week ? 7 : 30
            let start = cal.date(byAdding: .day, value: -(n - 1), to: today)!
            let prevStart = cal.date(byAdding: .day, value: -n, to: start)!
            let inRange = episodes.filter { $0.start >= start }
            let before = episodes.filter { $0.start >= prevStart && $0.start < start }.count
            let byDay = Dictionary(grouping: inRange) { cal.startOfDay(for: $0.start) }.mapValues(\.count)
            let days = (0..<n).map { cal.date(byAdding: .day, value: $0, to: start)! }
            s.count = inRange.count
            s.noun = range == .week ? "episodes in 7 days" : "episodes in 30 days"
            (s.change, s.better) = pct(inRange.count, before, range == .week ? "the week before" : "the 30 days before")
            s.bars = days.enumerated().map { Bar(x: $0.offset, count: byDay[$0.element] ?? 0, current: $0.element == today) }

            let watched = days.filter { tracker.activeDays.contains($0) }
            let style: Date.FormatStyle = range == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day().month(.abbreviated)
            let best = watched.min { (byDay[$0] ?? 0, $1) < (byDay[$1] ?? 0, $0) } // fewest, most recent first
            let worst = watched.max { (byDay[$0] ?? 0) < (byDay[$1] ?? 0) }
            s.figures = [
                Figure(label: "Per day", value: watched.isEmpty ? "–"
                       : (Double(inRange.count) / Double(watched.count)).formatted(.number.precision(.fractionLength(1)))),
                Figure(label: "Best day", value: best.map { "\(byDay[$0] ?? 0) · \($0.formatted(style))" } ?? "–"),
                Figure(label: "Worst day", value: worst.map { "\(byDay[$0] ?? 0) · \($0.formatted(style))" } ?? "–"),
            ]
        }
        return s
    }

    /// Neutral bars; the current hour or day carries the signal.
    private struct MiniBars: View {
        let bars: [Bar]

        var body: some View {
            let top = CGFloat(max(1, bars.map(\.count).max() ?? 1))
            GeometryReader { geo in
                let gap: CGFloat = bars.count > 20 ? 2 : 4
                let w = (geo.size.width - gap * CGFloat(bars.count - 1)) / CGFloat(bars.count)
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(bars) { bar in
                        RoundedRectangle(cornerRadius: min(2, w / 2), style: .continuous)
                            .fill(bar.current ? Color.dsSignal
                                  : bar.count > 0 ? Color.dsTextTertiary.opacity(0.55) : Color.dsSurfaceRaised)
                            .frame(width: w, height: bar.count > 0 ? max(4, geo.size.height * CGFloat(bar.count) / top) : 2)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct DebugStats: View {
    @ObservedObject var live: LiveStats

    var body: some View {
        HStack {
            stat("CPU", String(format: "%.0f%%", live.cpuPercent))
            stat("RAM", String(format: "%.0f MB", live.memoryMB))
            stat("FPS", String(format: "%.1f", live.fps))
        }
        .font(.dsMeta)
        .padding(DS.Space.s)
        .panelCard(cornerRadius: DS.Radius.control)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(Color.dsTextTertiary)
            Text(value)
        }
        .frame(maxWidth: .infinity)
    }
}
