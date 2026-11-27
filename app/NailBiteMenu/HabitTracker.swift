import Foundation
import Combine

final class HabitTracker: ObservableObject {
    @Published private(set) var records: [Detection] = []
    /// Start-of-day dates on which monitoring ran (used so unmonitored days don't count as bite-free).
    @Published private(set) var activeDays: Set<Date> = []

    var detections: [Date] { records.map(\.date) }
    var episodes: [Episode] { Insights.episodes(from: records) }

    nonisolated private struct Store: Codable {
        var records: [Detection]
        var activeDays: [Date]
    }

    // v1 was a bare [Date]. v2 lives in its own file so downgrading never overwrites history.
    private let storageURL: URL
    private let legacyURL: URL
    private let ioQueue = DispatchQueue(label: "HabitTracker.io", qos: .utility) // serial: saves land in order

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NailBiteMenu", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        storageURL = base.appendingPathComponent("nailbite_data_v2.json")
        legacyURL = base.appendingPathComponent("nailbite_stats.json")
        load()
    }

    #if DEBUG
    /// Design screenshots: in-memory history that never touches the data file.
    init(mockRecords: [Detection], activeDays: Set<Date>) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("nailbite-mock.json")
        storageURL = tmp
        legacyURL = tmp
        records = mockRecords
        self.activeDays = activeDays
    }
    #endif

    func addDetection(at date: Date = Date(), app: String? = nil, bundleID: String? = nil) {
        records.append(Detection(date: date, app: app, bundleID: bundleID))
        activeDays.insert(Calendar.current.startOfDay(for: date))
        save()
    }

    func markActive(_ date: Date = .now) {
        let day = Calendar.current.startOfDay(for: date)
        guard !activeDays.contains(day) else { return }
        activeDays.insert(day)
        save()
    }

    func clearAllData() {
        records = []
        activeDays = []
        try? FileManager.default.removeItem(at: legacyURL)
        save()
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: storageURL),
           let store = try? decoder.decode(Store.self, from: data) {
            records = store.records
            activeDays = Set(store.activeDays)
        } else if let data = try? Data(contentsOf: legacyURL),
                  let dates = try? decoder.decode([Date].self, from: data) {
            records = dates.map { Detection(date: $0) }
            // Before v2 we only know days that had detections.
            activeDays = Set(dates.map { Calendar.current.startOfDay(for: $0) })
            save()
        }
    }

    private func save() {
        let store = Store(records: records, activeDays: Array(activeDays))
        let url = storageURL
        ioQueue.async {
            do {
                try JSONEncoder().encode(store).write(to: url, options: .atomic)
            } catch {
                print("Failed to save stats file: \(error)")
            }
        }
    }
}
