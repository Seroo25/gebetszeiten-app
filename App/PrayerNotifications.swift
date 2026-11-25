import Foundation
import UserNotifications

/// Lokale Benachrichtigungen zu jedem Gebet (Standard-Ton, kein Adhan).
/// iOS erlaubt max. 64 geplante Benachrichtigungen → es werden die nächsten ~12 Tage geplant
/// und bei jedem Öffnen der App neu aufgefüllt.
enum PrayerNotifications {
    private static let center = UNUserNotificationCenter.current()
    private static let defaults = UserDefaults.standard
    private static let enabledKey = "notify.enabled"
    private static let maxPending = 60

    // MARK: Einstellungen

    static var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// Einzelne Gebete an/aus (Shurûq standardmäßig aus, es ist kein Gebet)
    static func isOn(_ prayer: Prayer) -> Bool {
        defaults.object(forKey: "notify.\(prayer.rawValue)") as? Bool ?? (prayer != .sunrise)
    }

    static func set(_ prayer: Prayer, on: Bool) {
        defaults.set(on, forKey: "notify.\(prayer.rawValue)")
    }

    // MARK: Berechtigung

    static func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    // MARK: Planen

    static func reschedule(table: PrayerTable?, lang: AppLanguage = AppLanguage.stored, now: Date = Date()) async {
        center.removeAllPendingNotificationRequests()
        guard isEnabled, let table, await isAuthorized() else { return }

        // Alle Zeiten der nächsten 14 Tage (inkl. Shurûq, wird für die Texte gebraucht)
        let all = (0..<14).flatMap { table.times(for: PrayerTable.day($0, from: now)) }

        var planned = 0
        for (i, item) in all.enumerated() where item.date > now && isOn(item.prayer) {
            guard planned < maxPending else { break }
            let next = all.dropFirst(i + 1).first
            let request = UNNotificationRequest(
                identifier: "prayer-\(Int(item.date.timeIntervalSince1970))",
                content: content(for: item, next: next, lang: lang),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date),
                    repeats: false))
            try? await center.add(request)
            planned += 1
        }
    }

    // MARK: Text der Benachrichtigung (Deutsch, Türkisch, Arabisch)

    static func content(for item: PrayerTime, next: PrayerTime?, lang: AppLanguage) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title(for: item, lang: lang)
        c.body = body(for: item, next: next, lang: lang)
        c.sound = .default
        c.threadIdentifier = "gebetszeiten"
        return c
    }

    /// "^Asr hat begonnen" · "İkindi vakti girdi" · "دخل وقت العصر"
    static func title(for item: PrayerTime, lang: AppLanguage) -> String {
        let name = item.prayer.name(lang)
        if item.prayer == .sunrise {
            return lang.t("\(name) hat begonnen", "Güneş doğdu", "أشرقت الشمس")
        }
        return lang.t("\(name) hat begonnen", "\(name) vakti girdi", "دخل وقت \(name)")
    }

    static func body(for item: PrayerTime, next: PrayerTime?, lang: AppLanguage) -> String {
        let name = item.prayer.name(lang)
        let nextName = next?.prayer.name(lang) ?? ""
        let nextTime = next.map { DateText.time($0.date, lang) } ?? ""
        switch item.prayer {
        case .fajr:
            return lang.t("Es ist Zeit für das Fajr-Gebet. Sonnenaufgang um \(nextTime) Uhr.",
                          "Sabah namazı vakti. Güneş doğuşu: \(nextTime).",
                          "حان وقت صلاة الفجر. الشروق الساعة \(nextTime).")
        case .sunrise:
            return lang.t("Sonnenaufgang – die Zeit für Fajr ist vorbei.",
                          "Sabah namazının vakti çıktı.",
                          "انتهى وقت صلاة الفجر.")
        case .isha:
            return lang.t("Es ist Zeit für das ^Ishâ-Gebet. Fajr morgen um \(nextTime) Uhr.",
                          "Yatsı namazı vakti. Yarın sabah namazı: \(nextTime).",
                          "حان وقت صلاة العشاء. الفجر غداً الساعة \(nextTime).")
        default:
            return lang.t("Es ist Zeit für das \(name)-Gebet. Nächstes Gebet: \(nextName) um \(nextTime) Uhr.",
                          "\(name) namazı vakti. Sonraki vakit: \(nextName) \(nextTime).",
                          "حان وقت صلاة \(name). الصلاة القادمة: \(nextName) الساعة \(nextTime).")
        }
    }
}

/// Zeigt Benachrichtigungen auch an, während die App geöffnet ist
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
