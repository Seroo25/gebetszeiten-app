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
            ContentView()
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }
}

struct ContentView: View {
    @State private var table: PrayerTable? = PrayerStore.cached()
    @State private var loading = false
    @State private var dayOffset = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.14, blue: 0.12), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            // Jede Minute neu zeichnen, damit aktuelles/nächstes Gebet stimmt
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(spacing: 16) {
                        let day = PrayerTable.day(dayOffset, from: context.date)
                        DateHeader(
                            title: DateText.header(day),
                            subtitle: table?.hijriLine(for: day, now: context.date) ?? DateText.hijri(day, night: false),
                            dateSize: 22, hijriSize: 14,
                            leading: {
                                Button { changeDay(-1) } label: { ArrowLabel(forward: false, size: 44) }
                            },
                            trailing: {
                                Button { changeDay(1) } label: { ArrowLabel(forward: true, size: 44) }
                            }
                        )
                        .padding(.top, 24)

                        if dayOffset != 0 {
                            Button("Zurück zu heute") { changeDay(0) }
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Glass.sub)
                        }

                        if let table, let state = table.state(at: context.date) {
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
                            Text(loading ? "Lade Gebetszeiten …" : "Keine Daten – bitte Internet prüfen")
                                .foregroundStyle(Glass.sub)
                                .padding(.top, 40)
                        }

                        NotificationSettingsView(table: table)

                        Button {
                            Task { await refresh(force: true) }
                        } label: {
                            Label("Aktualisieren", systemImage: "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Glass.tile))
                        }
                        .foregroundStyle(Glass.text)

                        Link("islamsalzgitter.de/gebetszeiten", destination: PrayerStore.websiteURL)
                            .font(.footnote)
                            .foregroundStyle(Glass.faint)

                        Text("Widget hinzufügen: Homescreen lang drücken → „Bearbeiten“ → „Widget hinzufügen“ → „Gebetszeiten“.")
                            .font(.footnote)
                            .foregroundStyle(Glass.faint)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 16)
                    .animation(.snappy, value: dayOffset)
                }
                // Wischen nach links/rechts wechselt ebenfalls den Tag
                .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { v in
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    changeDay(v.translation.width < 0 ? 1 : -1)
                })
            }
        }
        .task { await refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                dayOffset = 0
                Task { await refresh(force: false) }
            }
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
        await PrayerNotifications.reschedule(table: table) // Benachrichtigungen auffüllen
    }
}

// MARK: - Einstellungen Benachrichtigungen

struct NotificationSettingsView: View {
    let table: PrayerTable?
    @State private var enabled = PrayerNotifications.isEnabled
    @State private var perPrayer: [Prayer: Bool] = Dictionary(
        uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerNotifications.isOn($0)) })
    @State private var denied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $enabled) {
                Label("Benachrichtigungen", systemImage: "bell.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .padding(.vertical, 10)

            if enabled {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    Toggle(prayer.name, isOn: Binding(
                        get: { perPrayer[prayer] ?? true },
                        set: { perPrayer[prayer] = $0; PrayerNotifications.set(prayer, on: $0); update() }))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Glass.sub)
                        .padding(.vertical, 5)
                }
            }

            if denied {
                Text("Benachrichtigungen sind in den iOS-Einstellungen deaktiviert. Einstellungen → Gebetszeiten → Mitteilungen.")
                    .font(.footnote)
                    .foregroundStyle(Glass.faint)
                    .padding(.vertical, 6)
            }
        }
        .tint(Color.white.opacity(0.55))
        .foregroundStyle(Glass.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Glass.tile))
        .animation(.snappy, value: enabled)
        .onChange(of: enabled) { _, on in
            Task {
                if on, !(await PrayerNotifications.requestPermission()) {
                    denied = true
                    enabled = false
                    return
                }
                denied = false
                PrayerNotifications.isEnabled = on
                await PrayerNotifications.reschedule(table: table)
            }
        }
    }

    private func update() {
        Task { await PrayerNotifications.reschedule(table: table) }
    }
}
