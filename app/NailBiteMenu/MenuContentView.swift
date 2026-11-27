import SwiftUI
import AppKit

/// Compact status panel. Anything deeper lives in the main window (`onOpen`).
struct MenuContentView: View {
    @ObservedObject var monitor: MonitorViewModel
    let live: LiveStats
    @ObservedObject var tracker: HabitTracker
    let onOpen: (MainSection) -> Void

    var body: some View {
        let episodes = tracker.episodes
        let todayCount = episodes.filter { Calendar.current.isDateInToday($0.start) }.count
        let streak = Insights.biteFreeStreak(episodes: episodes, activeDays: tracker.activeDays)

        VStack(spacing: 14) {
            header

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bite-free for")
                        .font(.caption)
                        .foregroundStyle(Color.dsTextSecondary)
                    if let last = tracker.records.last?.date {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let text = ctx.date.timeIntervalSince(last).shortDuration
                            Text(text)
                                .font(.dsNumber(30, weight: .bold))
                                .foregroundStyle(Color.dsWin)
                                .contentTransition(.numericText())
                                .animation(DS.Motion.counter, value: text)
                        }
                    } else {
                        Text("Since day one")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                    }
                }
                Spacer()
                ConfidenceRing(live: live, threshold: monitor.thresholdPercent / 100, isRunning: monitor.isRunning)
            }
            .padding(16)
            .panelCard()

            HStack(spacing: 10) {
                MiniStat(value: "\(todayCount)", label: todayCount == 1 ? "episode today" : "episodes today")
                MiniStat(value: "\(streak)", label: streak == 1 ? "bite-free day" : "bite-free days")
            }

            if monitor.showDebug {
                DebugStats(live: live)
            }

            HStack(spacing: 8) {
                Button { onOpen(.today) } label: {
                    Label("Open NailBite", systemImage: "macwindow").frame(maxWidth: .infinity)
                }
                Button { onOpen(.insights) } label: {
                    Label("Insights", systemImage: "chart.bar.xaxis").frame(maxWidth: .infinity)
                }
                Button { onOpen(.settings) } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .accessibilityLabel("Settings")
            }
            .controlSize(.large)
            .glassButton()

            Divider()

            HStack {
                Text("Closing the window keeps NailBite running.")
                    .font(.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                Spacer()
                Button("Quit", role: .destructive) { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 340)
        .foregroundStyle(Color.dsText)
        .background(Color.dsBackground)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconView(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("NailBite")
                    .font(.headline)
                Label(monitor.isRunning ? "Monitoring" : "Paused",
                      systemImage: monitor.isRunning ? "circle.fill" : "pause.circle")
                    .symbolEffect(.pulse, options: .repeating, isActive: monitor.isRunning)
                    .font(.caption)
                    .foregroundStyle(monitor.isRunning ? Color.dsWin : Color.dsTextSecondary)
                    .imageScale(.small)
            }
            Spacer()
            Button {
                withAnimation(.snappy) { monitor.isRunning.toggle() }
            } label: {
                Label(monitor.isRunning ? "Pause" : "Start",
                      systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .controlSize(.large)
            .glassButton(prominent: true)
            .help(monitor.isRunning ? "Pause monitoring" : "Start monitoring")
        }
    }
}

/// The only view that re-renders on every camera frame.
private struct ConfidenceRing: View {
    @ObservedObject var live: LiveStats
    let threshold: Double
    let isRunning: Bool

    var body: some View {
        let value = isRunning ? live.confidence : 0
        let over = value >= threshold
        ZStack {
            Circle().stroke(Color.dsSurfaceMuted, lineWidth: 6)
            Circle()
                .trim(from: 0, to: value)
                .stroke(over ? Color.dsBite : Color.dsWin, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: value)
            Text("\(Int((value * 100).rounded()))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.dsTextSecondary)
        }
        .frame(width: 46, height: 46)
        .help("Live detection confidence")
        .accessibilityLabel("Detection confidence \(Int((value * 100).rounded())) percent")
    }
}

private struct MiniStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.dsNumber(20, weight: .bold))
                .contentTransition(.numericText())
                .animation(DS.Motion.counter, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .padding(12)
        .panelCard(cornerRadius: 14)
        .accessibilityElement(children: .combine)
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
        .font(.caption.monospacedDigit())
        .padding(10)
        .panelCard(cornerRadius: 12)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(Color.dsTextSecondary)
            Text(value)
        }
        .frame(maxWidth: .infinity)
    }
}
