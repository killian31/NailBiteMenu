import SwiftUI

// ponytail: native grouped Form, gets the system look (incl. Liquid Glass) on every macOS version for free.
struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tracker: HabitTracker
    @ObservedObject var monitor: MonitorViewModel
    @State private var showingResetAlert = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $preferences.appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Monitoring") {
                LabeledContent("Confidence threshold") {
                    HStack {
                        Slider(value: $preferences.confidenceThreshold, in: 1...99) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Relaxed").font(.caption2)
                        } maximumValueLabel: {
                            Text("Strict").font(.caption2)
                        }
                        Text("\(Int(preferences.confidenceThreshold))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Toggle(isOn: $preferences.startMonitoringOnLaunch) {
                    Text("Start on launch")
                    Text("Begin monitoring automatically when the app opens")
                }
            }

            Section {
                Toggle(isOn: $preferences.interruptIfContinuing) {
                    Text("Full-screen reset if biting continues")
                    Text("A banner appears first. If you keep biting for a few seconds, a 30-second hands-down exercise takes over the screen.")
                }
                Toggle(isOn: $preferences.muteAlerts) {
                    Text("Mute alert sounds")
                    Text("Banners and the reset screen still appear")
                }
                LabeledContent("Preview") {
                    HStack {
                        Button("Banner") { AlertPresenter.showBanner(app: nil) }
                        Button("Reset Screen") { AlertPresenter.showInterrupt() }
                    }
                }
            } header: {
                Text("Alerts")
            }

            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Privacy", value: "On-device only")
                LabeledContent("Model", value: "Core ML")
                Toggle("Show performance stats in the menu", isOn: $monitor.showDebug)
            } header: {
                Text("About")
            } footer: {
                Text("NailBite uses on-device machine learning to help you track and reduce nail-biting habits. No data ever leaves your Mac.")
            }

            Section {
                LabeledContent {
                    Button("Reset All Statistics…", role: .destructive) {
                        showingResetAlert = true
                    }
                } label: {
                    Text("Habit data")
                    Text("Permanently deletes every recorded detection.")
                }
            } header: {
                Text("Data")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.dsBackground)
        .foregroundStyle(Color.dsText)
        .alert("Reset all statistics?", isPresented: $showingResetAlert) {
            Button("Reset Data", role: .destructive) {
                tracker.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(tracker.detections.count) saved detections will be permanently deleted. This cannot be undone.")
        }
    }
}


#Preview {
    let prefs = AppPreferences()
    let tracker = HabitTracker()
    SettingsView(preferences: prefs, tracker: tracker,
                 monitor: MonitorViewModel(preferences: prefs, tracker: tracker))
}
