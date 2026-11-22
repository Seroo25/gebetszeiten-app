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

    static func reschedule(table: PrayerTable?, now: Date = Date()) async {
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
                content: content(for: item, next: next),
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date),
                    repeats: false))
            try? await center.add(request)
            planned += 1
        }
    }

    // MARK: Text der Benachrichtigung

    static func content(for item: PrayerTime, next: PrayerTime?) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = "\(item.prayer.name) hat begonnen"
        c.body = body(for: item, next: next)
        c.sound = .default
        c.threadIdentifier = "gebetszeiten"
        return c
    }

    static func body(for item: PrayerTime, next: PrayerTime?) -> String {
        let nextTime = next.map { DateText.time($0.date) } ?? ""
        switch item.prayer {
        case .fajr:
            return "Es ist Zeit für das Fajr-Gebet. Sonnenaufgang um \(nextTime) Uhr."
        case .sunrise:
            return "Sonnenaufgang – die Zeit für Fajr ist vorbei."
        case .isha:
            return "Es ist Zeit für das ^Ishâ-Gebet. Fajr morgen um \(nextTime) Uhr."
        default:
            let name = next?.prayer.name ?? ""
            return "Es ist Zeit für das \(item.prayer.name)-Gebet. Nächstes Gebet: \(name) um \(nextTime) Uhr."
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
