import Foundation

// MARK: - Gebete

enum Prayer: Int, CaseIterable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var name: String {
        ["Fajr", "Shurûq", "Dhuhr", "^Asr", "Maghrib", "^Ishâ"][rawValue]
    }
}

struct PrayerTime: Hashable {
    let prayer: Prayer
    let date: Date
}

struct PrayerState {
    let current: PrayerTime
    let next: PrayerTime
    let today: [PrayerTime]
}

// MARK: - Tabelle der Moschee

/// Daten aus der Gebetszeiten-App von islamsalzgitter.de
/// base["MM-dd"] = [Fajr, Shurûq, Dhuhr, ^Asr, Maghrib, ^Ishâ] in Minuten ab 00:00
struct PrayerTable {
    var base: [String: [Int]]
    /// Sonderzeiten für einzelne Tage ("yyyy-MM-dd"), falls die Moschee welche einträgt
    var overrides: [String: [Int]]

    static func parse(_ data: Data) -> PrayerTable? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            (root["success"] as? Bool) == true,
            let payload = root["data"] as? [String: Any],
            let rawBase = payload["base"] as? [String: Any]
        else { return nil }

        let base = rawBase.compactMapValues(toTimes)
        guard base.count > 300 else { return nil }

        var overrides: [String: [Int]] = [:]
        for (key, value) in payload where key != "base" {
            guard let dict = value as? [String: Any] else { continue }
            for (day, times) in dict where day.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                if let t = toTimes(times) { overrides[day] = t }
            }
        }
        return PrayerTable(base: base, overrides: overrides)
    }

    private static func toTimes(_ value: Any) -> [Int]? {
        guard let arr = value as? [Any], arr.count >= 6 else { return nil }
        let ints = arr.prefix(6).compactMap { ($0 as? NSNumber)?.intValue }
        return ints.count == 6 ? ints : nil
    }

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private static func key(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    /// Enthält die Tabelle schon Sommerzeit? Sonst +60 Min. in der Sommerzeit.
    private func dstShift(for day: Date) -> Int {
        if let jul = base["07-01"], let jan = base["01-01"], jul[2] - jan[2] > 30 { return 0 }
        let noon = Self.calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        return TimeZone.current.isDaylightSavingTime(for: noon) ? 60 : 0
    }

    func minutes(for day: Date) -> [Int]? {
        if let o = overrides[Self.key(day, "yyyy-MM-dd")] { return o }
        guard let v = base[Self.key(day, "MM-dd")] ?? base["02-28"] else { return nil }
        let shift = dstShift(for: day)
        return v.map { $0 + shift }
    }

    func times(for day: Date) -> [PrayerTime] {
        guard let mins = minutes(for: day) else { return [] }
        let cal = Self.calendar
        return zip(Prayer.allCases, mins).compactMap { prayer, m in
            cal.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day).map { PrayerTime(prayer: prayer, date: $0) }
        }
    }

    func state(at now: Date) -> PrayerState? {
        let cal = Self.calendar
        let today = times(for: now)
        guard today.count == 6,
              let yesterday = cal.date(byAdding: .day, value: -1, to: now),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: now)
        else { return nil }

        guard let idx = today.lastIndex(where: { $0.date <= now }) else {
            // nach Mitternacht vor Fajr: ^Ishâ von gestern läuft noch
            guard let isha = times(for: yesterday).last else { return nil }
            return PrayerState(current: isha, next: today[0], today: today)
        }
        if idx == today.count - 1 {
            guard let fajr = times(for: tomorrow).first else { return nil }
            return PrayerState(current: today[idx], next: fajr, today: today)
        }
        return PrayerState(current: today[idx], next: today[idx + 1], today: today)
    }

    /// Tag `offset` Tage von `now` entfernt (12 Uhr, um Sommerzeit-Probleme zu vermeiden)
    static func day(_ offset: Int, from now: Date) -> Date {
        let cal = calendar
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now
        return cal.date(byAdding: .day, value: offset, to: noon) ?? noon
    }

    /// Zweite Kopfzeile wie auf der Website: ab Maghrib bis Fajr "Nacht von …" (islamischer Tag beginnt mit Maghrib)
    func hijriLine(for day: Date, now: Date) -> String {
        let cal = Self.calendar
        guard cal.isDate(day, inSameDayAs: now) else { return DateText.hijri(day, night: false) }
        let t = times(for: now)
        if t.count == 6 {
            if now >= t[Prayer.maghrib.rawValue].date {
                return DateText.hijri(Self.day(1, from: now), night: true)
            }
            if now < t[Prayer.fajr.rawValue].date {
                return DateText.hijri(now, night: true)
            }
        }
        return DateText.hijri(now, night: false)
    }

    /// Alle Zeitpunkte, an denen sich die Anzeige ändert (Gebete + Mitternacht)
    func changePoints(from now: Date, days: Int) -> [Date] {
        let cal = Self.calendar
        var points: [Date] = []
        for offset in 0...days {
            guard let day = cal.date(byAdding: .day, value: offset, to: now) else { continue }
            points.append(cal.startOfDay(for: day))
            points.append(contentsOf: times(for: day).map(\.date)) // inkl. Maghrib/Fajr für "Tag/Nacht von"
        }
        return points.filter { $0 > now }.sorted()
    }
}

// MARK: - Laden & Zwischenspeichern

enum PrayerStore {
    static let dataURL = URL(string: "https://www.islamsalzgitter.de/wp-admin/admin-ajax.php?action=ptcms_load")!
    static let websiteURL = URL(string: "https://www.islamsalzgitter.de/gebetszeiten/")!

    private static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ptcms_load.json")
    }

    static func cached() -> PrayerTable? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return PrayerTable.parse(data)
    }

    private static var cacheAge: TimeInterval {
        let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path)
        guard let date = attrs?[.modificationDate] as? Date else { return .infinity }
        return Date().timeIntervalSince(date)
    }

    /// Lädt die Jahrestabelle (höchstens alle `maxAge` Sekunden), sonst letzter Stand.
    static func load(maxAge: TimeInterval = 6 * 3600) async -> PrayerTable? {
        if cacheAge < maxAge, let table = cached() { return table }
        do {
            var request = URLRequest(url: dataURL, timeoutInterval: 20)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            if let table = PrayerTable.parse(data) {
                try? data.write(to: cacheURL, options: .atomic)
                return table
            }
        } catch {
            // offline → letzter Stand
        }
        return cached()
    }
}

// MARK: - Datum

enum DateText {
    static let hijriOffset = 0 // ±1, falls die Moschee abweicht

    private static let hijriMonths = [
        "Muharram", "Safar", "Rabî^ al-Awwal", "Rabî^ ath-Thânî", "Jumâdâ al-Ûlâ", "Jumâdâ al-Âkhira",
        "Rajab", "Sha^bân", "Ramadân", "Shawwâl", "Dhû l-Qa^da", "Dhû l-Hijja",
    ]

    static func german(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = .current
        f.dateFormat = format
        return f.string(from: date)
    }

    static func time(_ date: Date) -> String { german(date, "HH:mm") }

    static func header(_ date: Date) -> String { german(date, "EEEE, d. MMMM yyyy") }

    static func hijri(_ date: Date, night: Bool) -> String {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = .current
        let d = cal.date(byAdding: .day, value: hijriOffset, to: date) ?? date
        let c = cal.dateComponents([.day, .month, .year], from: d)
        let month = hijriMonths[max(0, min(11, (c.month ?? 1) - 1))]
        return "\(night ? "Nacht" : "Tag") von \(c.day ?? 0). \(month) \(c.year ?? 0)"
    }
}
