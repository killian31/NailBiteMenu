import SwiftUI

// ponytail: native grouped Form, so every control behaves like macOS. Only the page around it is ours.
struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var tracker: HabitTracker
    @ObservedObject var monitor: MonitorViewModel
    @State private var showingResetAlert = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeader(context: "NailBite \(version)", title: "Settings") { EmptyView() }
                .padding(.horizontal, 46) // lines up with the Form's section headers
                .padding(.top, 44)

            Form {
                Section {
                    HStack(spacing: DS.Space.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Try the alert")
                            Text("Shows the alert the way a real detection does, with sound")
                                .font(.dsCaption)
                                .foregroundStyle(Color.dsTextSecondary)
                        }
                        Spacer()
                        Button("Preview Alert") { Alerts.gentle(app: nil) }
                            .buttonStyle(InkButtonStyle())
                        Button("Preview Reset") { Alerts.interrupt() }
                            .buttonStyle(QuietButtonStyle())
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $preferences.alertEdges) {
                        Text("Edge glow")
                        Text("The edges of every screen light up red")
                    }
                    Toggle(isOn: $preferences.alertLabel) {
                        Text("“Hands down” label")
                        Text("A small tag under the menu bar naming the app you were in")
                    }
                    Toggle(isOn: Binding(get: { !preferences.muteAlerts }, set: { preferences.muteAlerts = !$0 })) {
                        Text("Sound")
                        Text("A short ping with the glow")
                    }
                    Toggle(isOn: $preferences.interruptIfContinuing) {
                        Text("Reset if biting continues")
                        Text("If you keep going for a few seconds after the glow, a 30-second hands-down reset takes over the screen")
                    }
                } header: {
                    Text("Alert")
                }

                Section("Detection") {
                    LabeledContent {
                        HStack(spacing: DS.Space.s) {
                            Slider(value: $preferences.confidenceThreshold, in: 1...99) {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("Relaxed").font(.dsCaption)
                            } maximumValueLabel: {
                                Text("Strict").font(.dsCaption)
                            }
                            Text("\(Int(preferences.confidenceThreshold))")
                                .font(.dsMeta)
                                .frame(width: 24, alignment: .trailing)
                        }
                        .frame(width: 280)
                    } label: {
                        Text("Sensitivity")
                        Text("Strict waits until the model is surer. Fewer false alarms, a few missed bites.")
                    }

                    Toggle(isOn: $preferences.startMonitoringOnLaunch) {
                        Text("Start watching on launch")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $preferences.appearance) {
                        ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Privacy", value: "Frames never leave this Mac")
                    LabeledContent("Model", value: "Core ML, on device")
                    Toggle("Show performance stats in the menu", isOn: $monitor.showDebug)
                } header: {
                    Text("About")
                }

                Section {
                    LabeledContent {
                        Button("Delete History…", role: .destructive) {
                            showingResetAlert = true
                        }
                    } label: {
                        Text("History")
                        Text("\(tracker.episodes.count) episodes from \(tracker.activeDays.count) days")
                    }
                } header: {
                    Text("Data")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, DS.Space.l)
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(Color.dsBackground)
        .foregroundStyle(Color.dsText)
        .alert("Delete your whole history?", isPresented: $showingResetAlert) {
            Button("Delete History", role: .destructive) {
                tracker.clearAllData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(tracker.episodes.count) episodes from \(tracker.activeDays.count) days will be deleted. This can’t be undone.")
        }
    }
}
