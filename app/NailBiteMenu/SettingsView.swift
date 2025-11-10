import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tracker: HabitTracker
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 24) {
                header
                monitoringSection
                alertsSection
                aboutSection
                dataSection
            }
            .padding(28)
        }
        .frame(width: 520, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(size: 22, weight: .bold))
                Text("Configure your monitoring preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    var monitoringSection: some View {
        SettingsSection(title: "Monitoring", icon: "waveform.path.ecg", color: .blue) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Detection Model")
                        .font(.subheadline.weight(.semibold))
                    
                    Picker("", selection: $preferences.modelVariant) {
                        ForEach(ModelVariant.allCases) { variant in
                            Text(variant.displayName).tag(variant)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    
                    ModelDescriptionView(variant: preferences.modelVariant)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Confidence Threshold")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(preferences.confidenceThreshold))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(value: $preferences.confidenceThreshold, in: 1...99, step: 1)
                        .tint(.blue)
                    
                    HStack {
                        Text("Relaxed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Strict")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                Toggle(isOn: $preferences.startMonitoringOnLaunch) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start on Launch")
                            .font(.subheadline.weight(.semibold))
                        Text("Begin monitoring automatically when app opens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
    }
    
    var alertsSection: some View {
        SettingsSection(title: "Alerts & Notifications", icon: "bell.badge.fill", color: .orange) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $preferences.muteAlerts) {
                    HStack(spacing: 12) {
                        Image(systemName: preferences.muteAlerts ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundColor(preferences.muteAlerts ? .secondary : .orange)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mute Alert Sounds")
                                .font(.subheadline.weight(.semibold))
                            Text("Disable chime and notification audio")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
                
                InfoBox(
                    icon: "info.circle.fill",
                    text: "Visual notifications will still appear even when muted",
                    color: .blue
                )
            }
        }
    }
    
    var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle.fill", color: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                AboutRow(label: "Version", value: "1.8.0")
                AboutRow(label: "Privacy", value: "On-device only")
                AboutRow(label: "Model", value: "CoreML")
                
                Divider()
                
                Text("NailBite uses on-device machine learning to help you track and reduce nail-biting habits. No data ever leaves your Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    var dataSection: some View {
        SettingsSection(title: "Data Management", icon: "trash.fill", color: .red) {
            VStack(alignment: .leading, spacing: 10) {
                Text("This will permanently delete all of your recorded habit data. This action cannot be undone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider().padding(.vertical, 4)
                
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Text("Reset All Statistics...")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .alert("Are you sure you want to reset?", isPresented: $showingResetAlert) {
                    Button("Reset Data", role: .destructive) {
                        tracker.clearAllData()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("All \(tracker.detections.count) saved detections will be permanently deleted. This cannot be undone.")
                }
            }
        }
    }
}


private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
            
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct ModelDescriptionView: View {
    let variant: ModelVariant
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.12))
                )
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconColor.opacity(0.08))
        )
    }
    
    var iconName: String {
        switch variant {
        case .m224: return "hare.fill"
        case .m384: return "tortoise.fill"
        case .m512: return "crown.fill"
        }
    }
    
    var iconColor: Color {
        switch variant {
        case .m224: return .green
        case .m384: return .blue
        case .m512: return .purple
        }
    }
    
    var description: String {
        switch variant {
        case .m224: return "Fastest inference, lower accuracy"
        case .m384: return "Balanced speed and accuracy"
        case .m512: return "Highest accuracy, slower inference"
        }
    }
}

private struct InfoBox: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

private struct AboutRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }
}

#Preview {
    SettingsView(preferences: AppPreferences(), tracker: HabitTracker())
}
