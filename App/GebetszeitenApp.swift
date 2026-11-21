import SwiftUI
import WidgetKit

@main
struct GebetszeitenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var table: PrayerTable? = PrayerStore.cached()
    @State private var loading = false
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
                        DateHeader(date: context.date, dateSize: 22, hijriSize: 14)
                            .padding(.top, 24)

                        if let table, let state = table.state(at: context.date) {
                            HStack(spacing: 12) {
                                PrayerTile(kind: .current(endsAt: state.next.date), time: state.current,
                                           nameSize: 18, timeSize: 38, labelSize: 10, footSize: 12,
                                           padding: 14, cornerRadius: 22)
                                PrayerTile(kind: .next, time: state.next,
                                           nameSize: 18, timeSize: 38, labelSize: 10, footSize: 12,
                                           padding: 14, cornerRadius: 22)
                            }
                            .frame(height: 150)
                            DayList(state: state, fontSize: 17)
                        } else {
                            Text(loading ? "Lade Gebetszeiten …" : "Keine Daten – bitte Internet prüfen")
                                .foregroundStyle(Glass.sub)
                                .padding(.top, 40)
                        }

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
                }
            }
        }
        .task { await refresh(force: false) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh(force: false) } }
        }
    }

    private func refresh(force: Bool) async {
        loading = true
        if let t = await PrayerStore.load(maxAge: force ? 0 : 6 * 3600) { table = t }
        loading = false
        WidgetCenter.shared.reloadAllTimelines()
    }
}
