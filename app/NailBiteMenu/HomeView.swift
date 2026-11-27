import SwiftUI
import AppKit

struct HomeView: View {
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tracker: HabitTracker

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    hero
                    overviewSection
                    quickActions
                }
                .padding(32)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .glassGroup()
            }
            .legacyWindowBackground()
            .frame(minWidth: 780, minHeight: 560)
            .navigationDestination(for: String.self) { route in
                if route == "stats" {
                    StatsView(tracker: tracker)
                }
            }
        }
    }
}

private extension HomeView {
    var hero: some View {
        HStack(spacing: 18) {
            AppIconView(size: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("NailBite Monitor")
                    .font(.largeTitle.weight(.bold))
                Text("Private, on-device habit tracking")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.snappy) { monitor.isRunning.toggle() }
            } label: {
                Label(monitor.isRunning ? "Active" : "Paused",
                      systemImage: monitor.isRunning ? "circle.fill" : "pause.circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(monitor.isRunning ? .green : .orange)
            }
            .controlSize(.large)
            .glassButton()
            .help(monitor.isRunning ? "Pause monitoring" : "Start monitoring")
        }
        .padding(.bottom, 8)
    }

    var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NailBite lives in your menu bar, watching for nail-biting gestures directly on-device. Nothing is uploaded, and you stay in control.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                overviewLabel("camera.fill", "Uses your webcam only while monitoring.")
                overviewLabel("menubar.rectangle", "Keeps going even when this window is closed.")
                overviewLabel("slider.horizontal.3", "Open the controls any time to tweak sensitivity.")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Don’t see the icon?")
                    .font(.subheadline.weight(.semibold))
                Text("macOS may tuck it behind the chevron if your menu bar is crowded. Drag it out from Control Center to pin it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(cornerRadius: 24)
    }

    func overviewLabel(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    var quickActions: some View {
        VStack(spacing: 12) {
            NavigationLink(value: "stats") {
                ActionRow(title: "View Statistics",
                          subtitle: "See your habit trends over time",
                          icon: "chart.bar.xaxis",
                          color: .green)
            }
            .buttonStyle(.plain)

            Button(action: { presentSettingsScene(using: openSettings) }) {
                ActionRow(title: "Settings",
                          subtitle: "Adjust preferences & alerts",
                          icon: "gearshape.fill",
                          color: .blue)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
                collapseAppToMenuBar()
            } label: {
                ActionRow(title: "Collapse to Menu Bar",
                          subtitle: "Keep monitoring in background",
                          icon: "menubar.rectangle",
                          color: .purple)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15), in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentShape(.rect)
        .interactiveCard(cornerRadius: 20)
    }
}

#Preview {
    let prefs = AppPreferences()
    let tracker = HabitTracker()
    return HomeView(
        monitor: MonitorViewModel(preferences: prefs, tracker: tracker),
        preferences: prefs,
        tracker: tracker
    )
}
