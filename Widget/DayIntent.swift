import AppIntents
import WidgetKit

/// Merkt sich, welcher Tag im Widget gerade angezeigt wird.
/// Nach kurzer Zeit springt das Widget automatisch zurück auf heute.
enum DayOffsetStore {
    static let resetAfter: TimeInterval = 120
    private static let offsetKey = "dayOffset"
    private static let setAtKey = "dayOffsetSetAt"
    private static var defaults: UserDefaults { .standard }

    static var setAt: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: setAtKey))
    }

    /// Aktueller Versatz (0 = heute), verfällt nach `resetAfter` Sekunden
    static func current(now: Date = Date()) -> Int {
        guard now.timeIntervalSince(setAt) < resetAfter else { return 0 }
        return defaults.integer(forKey: offsetKey)
    }

    static func change(by delta: Int) {
        let value = delta == 0 ? 0 : max(-60, min(60, current() + delta))
        defaults.set(value, forKey: offsetKey)
        defaults.set(Date().timeIntervalSince1970, forKey: setAtKey)
    }
}

/// Pfeile im Widget: einen Tag vor/zurück (delta 0 = zurück auf heute)
struct ChangeDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Tag wechseln"
    static var isDiscoverable = false

    @Parameter(title: "Tage")
    var delta: Int

    init() { delta = 0 }
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        DayOffsetStore.change(by: delta)
        return .result()
    }
}
