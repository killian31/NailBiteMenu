import SwiftUI
import AppKit

struct MenuContentView: View {
    @ObservedObject var monitor: MonitorViewModel
    @ObservedObject var preferences: AppPreferences
    private let onOpenApp: () -> Void
    private let onOpenSettings: () -> Void

    private let presets: [SensitivityPreset] = [
        .init(title: "Relaxed", value: 45, symbol: "wind"),
        .init(title: "Balanced", value: 60, symbol: "hand.raised"),
        .init(title: "Strict", value: 75, symbol: "target")
    ]

    init(
        monitor: MonitorViewModel,
        preferences: AppPreferences,
        onOpenApp: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        _monitor = ObservedObject(wrappedValue: monitor)
        _preferences = ObservedObject(wrappedValue: preferences)
        self.onOpenApp = onOpenApp
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 14)

            actionRow
                .padding(.horizontal, 18)
                .padding(.top, 8)

            Divider()
                .padding(.top, 10)

            VStack(spacing: 14) {
                statusSection
                controlsSection
                if monitor.showDebug {
                    debugSection
                }
            }
            .padding(16)

            Divider()

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 360)
        .legacyWindowBackground()
    }
}

private extension MenuContentView {
    var header: some View {
        HStack(spacing: 12) {
            AppIconView(size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("NailBite")
                    .font(.headline)
                Text(monitor.isRunning ? "Monitoring" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: toggleMonitoring) {
                Label(monitor.isRunning ? "Pause" : "Start",
                      systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .controlSize(.large)
            .tint(monitor.isRunning ? .orange : .accentColor)
            .glassButton(prominent: true)
            .help(monitor.isRunning ? "Pause monitoring" : "Start monitoring")
        }
    }

    var actionRow: some View {
        HStack(spacing: 10) {
            ActionChip(
                title: "Open app",
                systemImage: "rectangle.and.text.magnifyingglass",
                action: onOpenApp
            )
            ActionChip(
                title: "Settings",
                systemImage: "gearshape",
                action: onOpenSettings
            )
        }
    }

    var statusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(confidenceLabel)
                        .font(.system(size: 32, design: .rounded).weight(.bold))
                        .foregroundStyle(confidenceColor)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: monitor.smoothedConfidence)
                        .stroke(confidenceColor.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: monitor.smoothedConfidence)
                }
            }

            if let date = monitor.lastDetectionDate {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(lastAlertLabel(for: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No detections yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .panelCard(cornerRadius: 16)
    }

    var controlsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Sensitivity", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(monitor.thresholdPercent))%")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $monitor.thresholdPercent, in: 1...99)
                    .tint(.blue)
                HStack(spacing: 8) {
                    ForEach(presets) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: abs(monitor.thresholdPercent - preset.value) < 1,
                            action: { monitor.thresholdPercent = preset.value }
                        )
                    }
                }
            }
            .padding(14)
            .panelCard(cornerRadius: 14)

            VStack(alignment: .leading, spacing: 10) {
                Label("Model size", systemImage: "dial.medium")
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: $monitor.selectedVariant) {
                    ForEach(ModelVariant.allCases) { variant in
                        Text(variant.displayName).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(monitor.selectedVariant.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .panelCard(cornerRadius: 14)

            HStack(spacing: 10) {
                CompactToggle(
                    icon: preferences.muteAlerts ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    label: "Sound",
                    isOn: Binding(get: { !preferences.muteAlerts },
                                  set: { preferences.muteAlerts = !$0 })
                )
                CompactToggle(
                    icon: "wrench.and.screwdriver",
                    label: "Debug",
                    isOn: $monitor.showDebug
                )
            }
        }
    }

    var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Performance", systemImage: "gauge")
                .font(.subheadline.weight(.semibold))
            statRow(label: "CPU", value: String(format: "%.0f%%", monitor.cpuPercent))
            statRow(label: "RAM", value: String(format: "%.1f MB", monitor.memoryMB))
            statRow(label: "FPS", value: String(format: "%.1f", monitor.fps))
        }
        .padding(14)
        .panelCard(cornerRadius: 14)
    }

    var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "menubar.rectangle")
                .foregroundStyle(.secondary)
            Text("Closing keeps NailBite in the menu bar.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
        }
    }

    func toggleMonitoring() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            monitor.isRunning.toggle()
        }
    }

    func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    var confidenceLabel: String {
        let percent = Int((monitor.smoothedConfidence * 100).rounded())
        return "\(percent)%"
    }

    var confidenceColor: Color {
        let threshold = max(monitor.thresholdPercent / 100, 0.01)
        let normalized = min(max(monitor.smoothedConfidence / threshold, 0), 1)
        let start = SIMD3<Double>(0.20, 0.75, 0.30) // green
        let end = SIMD3<Double>(0.90, 0.25, 0.25)   // red
        let mix = start + normalized * (end - start)
        return Color(red: mix.x, green: mix.y, blue: mix.z)
    }

    func lastAlertLabel(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct ActionChip: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .glassButton()
    }
}

private struct CompactToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)
                Text(label)
                    .font(.subheadline)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(.rect)
            .panelCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct PresetButton: View {
    let preset: SensitivityPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.title)
                    .font(.caption.weight(.semibold))
                Text("\(Int(preset.value))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            )
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct SensitivityPreset: Identifiable {
    let title: String
    let value: Double
    let symbol: String

    var id: String { title }
}

private extension ModelVariant {
    var description: String {
        switch self {
        case .m224: return "Featherweight • fastest response"
        case .m384: return "Balanced • everyday choice"
        case .m512: return "Detail focus • most precise"
        }
    }
}

#Preview {
    let prefs = AppPreferences()
    let tracker = HabitTracker()
    
    let monitor = MonitorViewModel(preferences: prefs, tracker: tracker)
    
    MenuContentView(
        monitor: monitor,
        preferences: prefs,
        onOpenApp: {},
        onOpenSettings: {}
    )
}
