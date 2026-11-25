import SwiftUI
import UIKit

// MARK: - Einstellungen (Zahnrad oben rechts)

struct SettingsView: View {
    let table: PrayerTable?
    @Environment(\.appLanguage) var lang
    @Environment(\.dismiss) var dismiss

    init(table: PrayerTable?) {
        self.table = table
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        NotificationSettingsView(table: table)
                    } label: {
                        Label(lang.t("Benachrichtigungen", "Bildirimler", "الإشعارات"), systemImage: "bell.badge.fill")
                    }
                } footer: {
                    Text(version)
                }
            }
            .navigationTitle(lang.t("Einstellungen", "Ayarlar", "الإعدادات"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("Fertig", "Tamam", "تم")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Reiter „Benachrichtigungen“

struct NotificationSettingsView: View {
    let table: PrayerTable?
    @Environment(\.appLanguage) private var lang
    @Environment(\.openURL) private var openURL
    @State private var enabled = PrayerNotifications.isEnabled
    @State private var perPrayer: [Prayer: Bool] = Dictionary(
        uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerNotifications.isOn($0)) })
    @State private var denied = false

    private var title: String { lang.t("Benachrichtigungen", "Bildirimler", "الإشعارات") }

    var body: some View {
        List {
            Section {
                Toggle(title, isOn: $enabled)
            } footer: {
                Text(lang.t("Zu Beginn jeder ausgewählten Gebetszeit kommt eine Mitteilung mit dem normalen iOS-Ton.",
                            "Seçtiğiniz her vaktin başında standart iOS sesiyle bir bildirim gelir.",
                            "يصلك إشعار بصوت iOS العادي عند دخول وقت كل صلاة تختارها."))
            }

            if denied {
                Section {
                    Text(lang.t("Mitteilungen sind für diese App in den iOS-Einstellungen ausgeschaltet.",
                                "Bu uygulamanın bildirimleri iOS ayarlarında kapalı.",
                                "الإشعارات معطلة لهذا التطبيق في إعدادات iOS."))
                        .foregroundStyle(.secondary)
                    Button(lang.t("iOS-Einstellungen öffnen", "iOS Ayarlarını Aç", "فتح إعدادات iOS")) {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                    }
                }
            }

            if enabled {
                Section(lang.t("Gebete", "Vakitler", "الصلوات")) {
                    ForEach(Prayer.allCases, id: \.self) { prayer in
                        Toggle(prayer.name(lang), isOn: Binding(
                            get: { perPrayer[prayer] ?? true },
                            set: { on in
                                perPrayer[prayer] = on
                                PrayerNotifications.set(prayer, on: on)
                                reschedule()
                            }))
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: enabled)
        .task {
            // Mitteilungen wurden evtl. später in den iOS-Einstellungen abgeschaltet
            if enabled, !(await PrayerNotifications.isAuthorized()) { denied = true }
        }
        .onChange(of: enabled) { _, on in
            Task {
                if on {
                    guard await PrayerNotifications.requestPermission() else {
                        denied = true
                        enabled = false
                        return
                    }
                    denied = false
                }
                PrayerNotifications.isEnabled = on
                await PrayerNotifications.reschedule(table: table ?? PrayerStore.cached(), lang: lang)
            }
        }
    }

    private func reschedule() {
        Task { await PrayerNotifications.reschedule(table: table ?? PrayerStore.cached(), lang: lang) }
    }
}
