import SwiftUI
import UserNotifications
import WidgetKit

@main
struct GebetszeitenApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Hält die gewählte Sprache und gibt sie an alle Ansichten weiter
struct RootView: View {
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.device.rawValue

    private var lang: AppLanguage { AppLanguage(rawValue: languageCode) ?? .de }

    var body: some View {
        ContentView()
            .appLanguage(lang)
            .preferredColorScheme(.dark)
            .onChange(of: languageCode) { _, _ in
                // geplante Benachrichtigungen in der neuen Sprache neu anlegen
                Task { await PrayerNotifications.reschedule(table: PrayerStore.cached(), lang: lang) }
            }
    }
}

struct ContentView: View {
    @State private var table: PrayerTable? = PrayerStore.cached()
    @State private var loading = false
    @State private var dayOffset = 0
    @State private var showSettings = false
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.device.rawValue
    @Environment(\.appLanguage) private var lang
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.14, blue: 0.12), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Jede Minute neu zeichnen, damit aktuelles/nächstes Gebet stimmt
                TimelineView(.everyMinute) { context in
                    ScrollView {
                        content(now: context.date)
                            .padding(.horizontal, 16)
                            .animation(.snappy, value: dayOffset)
                    }
                    // Wischen nach links/rechts wechselt ebenfalls den Tag
                    .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { v in
                        guard abs(v.translation.width) > abs(v.translation.height) else { return }
                        // bei Arabisch (rechts nach links) ist die Richtung umgekehrt
                        let forward = (v.translation.width < 0) != lang.isRTL
                        changeDay(forward ? 1 : -1)
                    })
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(table: table)
                .appLanguage(lang)
                .preferredColorScheme(.dark)
        }
        .task { await refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                dayOffset = 0
                Task { await refresh(force: false) }
            }
        }
    }

    // MARK: Globus (Sprache) oben links, Zahnrad (Einstellungen) oben rechts

    private var topBar: some View {
        HStack {
            Menu {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languageCode = language.rawValue
                    } label: {
                        if language == lang {
                            Label(language.nativeName, systemImage: "checkmark")
                        } else {
                            Text(language.nativeName)
                        }
                    }
                }
            } label: {
                GlassIcon(systemName: "globe")
            }
            .accessibilityLabel(lang.t("Sprache", "Dil", "اللغة"))

            Spacer()

            Button {
                showSettings = true
            } label: {
                GlassIcon(systemName: "gearshape.fill")
            }
            .accessibilityLabel(lang.t("Einstellungen", "Ayarlar", "الإعدادات"))
        }
    }

    // MARK: Inhalt

    @ViewBuilder private func content(now: Date) -> some View {
        let day = PrayerTable.day(dayOffset, from: now)
        VStack(spacing: 16) {
            DateHeader(
                title: DateText.header(day, lang),
                subtitle: table?.hijriLine(for: day, now: now, lang: lang) ?? DateText.hijri(day, night: false, lang),
                dateSize: 22, hijriSize: 14,
                leading: {
                    Button { changeDay(-1) } label: { ArrowLabel(forward: false, size: 44) }
                },
                trailing: {
                    Button { changeDay(1) } label: { ArrowLabel(forward: true, size: 44) }
                }
            )
            .padding(.top, 8)

            if dayOffset != 0 {
                Button(lang.t("Zurück zu heute", "Bugüne dön", "العودة إلى اليوم")) { changeDay(0) }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Glass.sub)
            }

            if let table, let state = table.state(at: now) {
                if dayOffset == 0 {
                    HStack(spacing: 12) {
                        PrayerTile(kind: .current(endsAt: state.next.date), time: state.current,
                                   nameSize: 18, timeSize: 38, labelSize: 10, footSize: 12,
                                   padding: 14, cornerRadius: 22)
                        PrayerTile(kind: .next, time: state.next,
                                   nameSize: 18, timeSize: 38, labelSize: 10, footSize: 12,
                                   padding: 14, cornerRadius: 22)
                    }
                    .frame(height: 150)
                    DayList(times: state.today, highlight: state.current, fontSize: 17)
                } else {
                    DayList(times: table.times(for: day), fontSize: 19)
                }
            } else {
                Text(loading
                     ? lang.t("Lade Gebetszeiten …", "Namaz vakitleri yükleniyor …", "جارٍ تحميل أوقات الصلاة …")
                     : lang.t("Keine Daten – bitte Internet prüfen",
                              "Veri yok – lütfen internet bağlantınızı kontrol edin",
                              "لا توجد بيانات – يرجى التحقق من الاتصال بالإنترنت"))
                    .foregroundStyle(Glass.sub)
                    .padding(.top, 40)
            }

            Button {
                Task { await refresh(force: true) }
            } label: {
                Label(lang.t("Aktualisieren", "Yenile", "تحديث"), systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Glass.tile))
            }
            .foregroundStyle(Glass.text)

            Link("islamsalzgitter.de/gebetszeiten", destination: PrayerStore.websiteURL)
                .font(.footnote)
                .foregroundStyle(Glass.faint)

            Text(lang.t(
                "Widget hinzufügen: Homescreen lang drücken → „Bearbeiten“ → „Widget hinzufügen“ → „Gebetszeiten“. Sprache des Widgets: Widget lang drücken → „Widget bearbeiten“.",
                "Widget eklemek için: Ana ekrana uzun basın → “Düzenle” → “Widget Ekle” → “Gebetszeiten”. Widget dili: Widget’a uzun basın → “Widget’ı Düzenle”.",
                "لإضافة الأداة: اضغط مطولاً على الشاشة الرئيسية ← «تعديل» ← «إضافة أداة» ← «Gebetszeiten». لغة الأداة: اضغط مطولاً على الأداة ← «تعديل الأداة»."))
                .font(.footnote)
                .foregroundStyle(Glass.faint)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    private func changeDay(_ delta: Int) {
        dayOffset = delta == 0 ? 0 : max(-60, min(60, dayOffset + delta))
    }

    private func refresh(force: Bool) async {
        loading = true
        if let t = await PrayerStore.load(maxAge: force ? 0 : 6 * 3600) { table = t }
        loading = false
        WidgetCenter.shared.reloadAllTimelines()
        await PrayerNotifications.reschedule(table: table, lang: lang) // Benachrichtigungen auffüllen
    }
}
