import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Timeline
// Alle Wechsel (Mitternacht, jedes Gebet) werden iOS im Voraus übergeben.
// iOS springt dann minutengenau um – ohne Neuladen.

struct PrayerEntry: TimelineEntry {
    let date: Date
    let table: PrayerTable?
    var dayOffset: Int = 0
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
                let entry = PrayerEntry(date: now, table: nil)
                completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
                return
            }

            var entries: [PrayerEntry] = []
            var start = now
            let offset = DayOffsetStore.current(now: now)
            if offset != 0 {
                // anderer Tag ausgewählt → kurz anzeigen, dann automatisch zurück auf heute
                entries.append(PrayerEntry(date: now, table: table, dayOffset: offset))
                start = DayOffsetStore.setAt.addingTimeInterval(DayOffsetStore.resetAfter)
            }
            let points = [start] + table.changePoints(from: start, days: 2)
            entries += points.map { PrayerEntry(date: $0, table: table) }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(4 * 3600))))
        }
    }
}

// MARK: - Ansichten

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var shownDay: Date { PrayerTable.day(entry.dayOffset, from: entry.date) }

    var body: some View {
        Group {
            if let table = entry.table, let state = table.state(at: entry.date) {
                switch family {
                case .systemSmall: small(state)
                case .systemLarge: large(table, state)
                default: medium(table, state)
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
        .environment(\.locale, Locale(identifier: "de_DE"))
    }

    /// Kopfzeile mit Pfeilen; Tippen auf das Datum springt zurück auf heute
    private func header(_ table: PrayerTable, dateSize: CGFloat, hijriSize: CGFloat, arrow: CGFloat) -> some View {
        DateHeader(
            title: DateText.header(shownDay),
            subtitle: table.hijriLine(for: shownDay, now: entry.date),
            dateSize: dateSize, hijriSize: hijriSize,
            leading: {
                Button(intent: ChangeDayIntent(delta: -1)) { ArrowLabel(forward: false, size: arrow) }
                    .buttonStyle(.plain)
            },
            trailing: {
                Button(intent: ChangeDayIntent(delta: 1)) { ArrowLabel(forward: true, size: arrow) }
                    .buttonStyle(.plain)
            }
        )
        .overlay {
            if entry.dayOffset != 0 {
                Button(intent: ChangeDayIntent(delta: 0)) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, arrow + 6)
            }
        }
    }

    // Klein: das Widget selbst ist die Kachel "Nächstes Gebet"
    private func small(_ s: PrayerState) -> some View {
        PrayerTile(kind: .next, time: s.next,
                   nameSize: 20, timeSize: 44, labelSize: 11, footSize: 13,
                   padding: 16, showBackground: false)
            .containerBackground(for: .widget) { Glass.tile }
    }

    // Mittel: Datum mit Pfeilen + aktuelles & nächstes Gebet (anderer Tag: alle 6 Zeiten)
    private func medium(_ table: PrayerTable, _ s: PrayerState) -> some View {
        VStack(spacing: 8) {
            header(table, dateSize: 14, hijriSize: 10, arrow: 24)
            if entry.dayOffset == 0 {
                HStack(spacing: 8) {
                    PrayerTile(kind: .current(endsAt: s.next.date), time: s.current)
                    PrayerTile(kind: .next, time: s.next)
                }
            } else {
                DayGrid(times: table.times(for: shownDay))
            }
        }
        .padding(12)
        .containerBackground(for: .widget) { Color.black.opacity(0.18) }
    }

    // Groß: Datum mit Pfeilen + beide Kacheln + alle Zeiten des Tages
    private func large(_ table: PrayerTable, _ s: PrayerState) -> some View {
        VStack(spacing: 10) {
            header(table, dateSize: 18, hijriSize: 12, arrow: 30)
            if entry.dayOffset == 0 {
                HStack(spacing: 10) {
                    PrayerTile(kind: .current(endsAt: s.next.date), time: s.current,
                               nameSize: 17, timeSize: 34, labelSize: 9, footSize: 11, padding: 12, cornerRadius: 22)
                    PrayerTile(kind: .next, time: s.next,
                               nameSize: 17, timeSize: 34, labelSize: 9, footSize: 11, padding: 12, cornerRadius: 22)
                }
                DayList(times: s.today, highlight: s.current)
            } else {
                Spacer(minLength: 0)
                DayList(times: table.times(for: shownDay), fontSize: 19)
                Spacer(minLength: 0)
            }
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
        }
        .configurationDisplayName("Gebetszeiten")
        .description("Aktuelles und nächstes Gebet – Ahlu-s Sunnah Zentrum Salzgitter")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
