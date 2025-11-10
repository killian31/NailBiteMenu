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
            ZStack {
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .windowBackgroundColor).opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        hero
                        overviewSection
                        quickActions
                    }
                    .padding(32)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
            }
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
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .blur(radius: 12)
                    .opacity(monitor.isRunning ? 0.6 : 0.3)
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "hand.raised.fingers.spread.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("NailBite Monitor")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Private, on-device habit tracking")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: monitor.isRunning ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
                
                Text(monitor.isRunning ? "Active" : "Paused")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .padding(.bottom, 8)
    }
    
    var overviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NailBite lives in your menu bar, watching for nail-biting gestures directly on-device. Nothing is uploaded, and you stay in control.")
                .font(.body)
                .foregroundStyle(.secondary)

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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    func overviewLabel(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    var statusSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monitoring Status")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text(monitor.isRunning ? "Actively scanning for patterns" : "Monitoring paused")
                            .font(.title3.weight(.semibold))
                    }
                    
                    Spacer()
                    
                    Button(action: toggleMonitoring) {
                        HStack(spacing: 6) {
                            Image(systemName: monitor.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(monitor.isRunning ? "Pause" : "Start")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            monitor.isRunning ?
                                AnyShapeStyle(Color.orange.gradient) :
                                AnyShapeStyle(Color.blue.gradient)
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: (monitor.isRunning ? Color.orange : Color.blue).opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Live Confidence")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(confidenceLabel)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(confidenceColor)
                    }
                    
                    ModernConfidenceBar(value: monitor.smoothedConfidence)
                        .frame(height: 10)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(lastDetectionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
            )
        }
    }
    
    var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            CompactMetricCard(
                icon: "dial.medium.fill",
                title: "Model",
                value: monitor.selectedVariant.displayName,
                subtitle: modelDescription,
                color: .blue
            )
            
            CompactMetricCard(
                icon: "slider.horizontal.3",
                title: "Threshold",
                value: "\(Int(monitor.thresholdPercent))%",
                subtitle: thresholdDescription,
                color: .purple
            )
            
            CompactMetricCard(
                icon: "cpu",
                title: "CPU",
                value: String(format: "%.0f%%", monitor.cpuPercent),
                subtitle: "Processor usage",
                color: .green
            )
            
            CompactMetricCard(
                icon: "memorychip",
                title: "Memory",
                value: String(format: "%.1f MB", monitor.memoryMB),
                subtitle: "RAM footprint",
                color: .orange
            )
        }
    }
    
    var quickActions: some View {
            VStack(spacing: 12) {
                NavigationLink(value: "stats") {
                    ModernActionContent(
                        title: "View Statistics",
                        subtitle: "See your habit trends over time",
                        icon: "chart.bar.xaxis",
                        color: .green
                    )
                }
                .buttonStyle(.plain)

                ModernActionButton(
                    title: "Settings",
                    subtitle: "Adjust preferences & alerts",
                    icon: "gearshape.fill",
                    color: .blue,
                    action: openSettingsScene
                )
                
                ModernActionButton(
                    title: "Collapse to Menu Bar",
                    subtitle: "Keep monitoring in background",
                    icon: "menubar.rectangle",
                    color: .purple
                ) {
                    dismiss()
                    collapseAppToMenuBar()
                }
            }
        }
    
    var thresholdDescription: String {
        switch Int(monitor.thresholdPercent) {
        case 0..<50: return "Relaxed"
        case 50..<70: return "Balanced"
        default: return "Strict"
        }
    }
    
    var confidenceColor: Color {
        let value = monitor.smoothedConfidence
        if value < 0.3 { return .green }
        if value < 0.6 { return .orange }
        return .red
    }
    
    var lastDetectionLabel: String {
        if let date = monitor.lastDetectionDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last detected \(formatter.localizedString(for: date, relativeTo: .now))"
        }
        return "No detections yet"
    }

    var confidenceLabel: String {
        "\(Int((monitor.smoothedConfidence * 100).rounded()))%"
    }

    var modelDescription: String {
        switch monitor.selectedVariant {
        case .m224: return "Fastest"
        case .m384: return "Balanced"
        case .m512: return "Precise"
        }
    }

    func openSettingsScene() {
        presentSettingsScene(using: openSettings)
    }

    func toggleMonitoring() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            monitor.isRunning.toggle()
        }
    }
}


private struct ModernConfidenceBar: View {
    let value: Double
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, geo.size.width * value))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)
    }
    
    var gradientColors: [Color] {
        if value < 0.3 {
            return [Color.green, Color.mint]
        } else if value < 0.6 {
            return [Color.orange, Color.yellow]
        } else {
            return [Color.red, Color.pink]
        }
    }
}

private struct CompactMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )
                
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct ModernActionContent: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.12))
                )
            
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct ModernActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernActionContent(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color
            )
        }
        .buttonStyle(.plain)
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
