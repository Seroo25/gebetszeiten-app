import SwiftUI
import WidgetKit

// MARK: - Timeline
// Der große Vorteil gegenüber Scriptable: Alle Wechsel (Mitternacht + jedes Gebet)
// werden iOS im Voraus übergeben. iOS springt dann minutengenau um – ohne Neuladen.

struct PrayerEntry: TimelineEntry {
    let date: Date
    let table: PrayerTable?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), table: PrayerStore.cached())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        Task {
            let table = await PrayerStore.load()
            completion(PrayerEntry(date: Date(), table: table))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        Task {
            let now = Date()
            guard let table = await PrayerStore.load() else {
                // keine Daten (offline, nie geladen) → in 15 Min. erneut versuchen
                let entry = PrayerEntry(date: now, table: nil)
                completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
                return
            }
            // Einträge für die nächsten 2 Tage
            let points = [now] + table.changePoints(from: now, days: 2)
            let entries = points.map { PrayerEntry(date: $0, table: table) }
            // Daten alle paar Stunden frisch holen (falls die Moschee Zeiten ändert)
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(4 * 3600))))
        }
    }
}

// MARK: - Ansichten

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        if let table = entry.table, let state = table.state(at: entry.date) {
            switch family {
            case .systemSmall: small(state)
            case .systemLarge: large(state)
            default: medium(state)
            }
        } else {
            VStack(spacing: 4) {
                Text("Gebetszeiten")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Daten gerade nicht erreichbar")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Glass.sub)
            }
            .foregroundStyle(Glass.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerBackground(for: .widget) { Color.black.opacity(0.18) }
        }
    }

    // Klein: das Widget selbst ist die Kachel "Nächstes Gebet"
    private func small(_ s: PrayerState) -> some View {
        PrayerTile(kind: .next, time: s.next,
                   nameSize: 20, timeSize: 44, labelSize: 11, footSize: 13,
                   padding: 16, showBackground: false)
            .containerBackground(for: .widget) { Glass.tile }
    }

    // Mittel: Datum + aktuelles & nächstes Gebet
    private func medium(_ s: PrayerState) -> some View {
        VStack(spacing: 8) {
            DateHeader(date: entry.date)
            HStack(spacing: 8) {
                PrayerTile(kind: .current(endsAt: s.next.date), time: s.current)
                PrayerTile(kind: .next, time: s.next)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color.black.opacity(0.18) }
    }

    // Groß: Datum + beide Kacheln + alle Zeiten des Tages
    private func large(_ s: PrayerState) -> some View {
        VStack(spacing: 10) {
            DateHeader(date: entry.date, dateSize: 18, hijriSize: 12)
            HStack(spacing: 10) {
                PrayerTile(kind: .current(endsAt: s.next.date), time: s.current,
                           nameSize: 17, timeSize: 34, labelSize: 9, footSize: 11, padding: 12, cornerRadius: 22)
                PrayerTile(kind: .next, time: s.next,
                           nameSize: 17, timeSize: 34, labelSize: 9, footSize: 11, padding: 12, cornerRadius: 22)
            }
            DayList(state: s)
        }
        .padding(16)
        .containerBackground(for: .widget) { Color.black.opacity(0.18) }
    }
}

// MARK: - Widget

@main
struct GebetszeitenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Gebetszeiten", provider: Provider()) { entry in
            WidgetView(entry: entry)
                .widgetURL(PrayerStore.websiteURL)
        }
        .configurationDisplayName("Gebetszeiten")
        .description("Aktuelles und nächstes Gebet – Ahlu-s Sunnah Zentrum Salzgitter")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
