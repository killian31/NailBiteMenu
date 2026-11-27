import Foundation

/// One positive frame-level detection (recorded at most every couple of seconds while biting).
struct Detection: Codable, Hashable {
    var date: Date
    /// Name and bundle id of the app that was in front, if known.
    var app: String?
    var bundleID: String?
}

/// A biting episode: detections with no gap longer than `Episode.gap`.
struct Episode: Identifiable, Hashable {
    var start: Date
    var end: Date
    var count: Int
    var app: String?
    var bundleID: String?

    var id: Date { start }
    /// Detections are ~2 s apart, so a single detection still counts as a short episode.
    var duration: TimeInterval { max(end.timeIntervalSince(start), 2) }

    // ponytail: fixed 30 s gap; make it a preference only if people ask.
    static let gap: TimeInterval = 30
}

enum Insights {
    /// Groups detections (any order) into episodes.
    static func episodes(from detections: [Detection]) -> [Episode] {
        var result: [Episode] = []
        for d in detections.sorted(by: { $0.date < $1.date }) {
            if var last = result.last, d.date.timeIntervalSince(last.end) <= Episode.gap {
                last.end = d.date
                last.count += 1
                result[result.count - 1] = last
            } else {
                result.append(Episode(start: d.date, end: d.date, count: 1, app: d.app, bundleID: d.bundleID))
            }
        }
        return result
    }

    /// Longest stretch without an episode inside `[from, to]`.
    static func longestBiteFree(_ episodes: [Episode], from: Date, to: Date) -> TimeInterval {
        var cursor = from
        var best: TimeInterval = 0
        for e in episodes where e.end >= from && e.start <= to {
            best = max(best, e.start.timeIntervalSince(cursor))
            cursor = max(cursor, e.end)
        }
        return max(best, to.timeIntervalSince(cursor))
    }

    /// Consecutive bite-free days, counting back from today.
    /// Days the app never monitored are skipped (they neither count nor break the streak).
    /// Today counts only once it has been monitored and is still bite-free.
    static func biteFreeStreak(episodes: [Episode], activeDays: Set<Date>,
                               today: Date = .now, calendar: Calendar = .current) -> Int {
        let bitten = Set(episodes.map { calendar.startOfDay(for: $0.start) })
        var streak = 0
        for day in activeDays.map({ calendar.startOfDay(for: $0) }).sorted(by: >)
        where day <= calendar.startOfDay(for: today) {
            if bitten.contains(day) {
                break
            }
            streak += 1
        }
        return streak
    }

    /// Apps ranked by number of episodes that started in them (episodes without a known app are skipped).
    static func triggerApps(_ episodes: [Episode]) -> [(name: String, bundleID: String?, count: Int)] {
        var counts: [String: (String?, Int)] = [:]
        for e in episodes {
            guard let name = e.app else { continue }
            counts[name, default: (e.bundleID, 0)].1 += 1
        }
        return counts.map { (name: $0.key, bundleID: $0.value.0, count: $0.value.1) }
            .sorted { $0.count > $1.count }
    }
}

extension TimeInterval {
    /// "2h 14m", "14m", "45s"
    var shortDuration: String {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        f.allowedUnits = self >= 3600 ? [.day, .hour, .minute] : self >= 60 ? [.minute] : [.second]
        return f.string(from: max(self, 0)) ?? "–"
    }
}

#if DEBUG
/// Run: echo "Insights.selfCheck()" > /tmp/main.swift && swiftc -D DEBUG Insights.swift /tmp/main.swift -o /tmp/ic && /tmp/ic
extension Insights {
    static func selfCheck() {
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let d = { (s: TimeInterval) in Detection(date: t0.addingTimeInterval(s), app: "Zoom") }
        // 0,2,4 → one episode; 100 → second; 129 → joins second (gap 29 ≤ 30); 200 → third
        let eps = episodes(from: [d(4), d(0), d(2), d(100), d(129), d(200)])
        assert(eps.count == 3, "episodes \(eps.count)")
        assert(eps[0].count == 3 && eps[0].duration == 4)
        assert(eps[1].count == 2 && eps[1].end == t0.addingTimeInterval(129))
        assert(eps[2].duration == 2, "single detection floors to 2 s")

        // bite-free: [0,4] [100,129] [200,200] within [0,1000] → longest is 200…1000 = 800
        assert(longestBiteFree(eps, from: t0, to: t0.addingTimeInterval(1000)) == 800)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let day = { (n: Double) in cal.startOfDay(for: t0).addingTimeInterval(n * 86_400) }
        // bites on day 0; monitored days 0,1,2,4 (3 skipped); today = 4 → streak 3 (4,2,1)
        let streak = biteFreeStreak(episodes: eps, activeDays: [day(0), day(1), day(2), day(4)],
                                    today: day(4).addingTimeInterval(3600), calendar: cal)
        assert(streak == 3, "streak \(streak)")
        assert(triggerApps(eps).first?.count == 3)
        print("Insights.selfCheck OK")
    }
}
#endif
