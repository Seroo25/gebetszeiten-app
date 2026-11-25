import SwiftUI

// Liquid-Glass-Optik: nur Weiß in verschiedenen Deckkräften.
// Im Homescreen-Stil "Klar" legt iOS echtes Glas dahinter.
enum Glass {
    static let tileHi = Color.white.opacity(0.22)
    static let tile = Color.white.opacity(0.10)
    static let rowHi = Color.white.opacity(0.16)
    static let text = Color.white
    static let sub = Color.white.opacity(0.75)
    static let faint = Color.white.opacity(0.55)
}

/// Kopfzeile: Datum + islamisches Datum, links/rechts Platz für Pfeile
struct DateHeader<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    var dateSize: CGFloat = 14
    var hijriSize: CGFloat = 10
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            leading
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: dateSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Glass.text)
                Text(subtitle)
                    .font(.system(size: hijriSize, weight: .medium))
                    .foregroundStyle(Glass.sub)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
            trailing
        }
    }
}

extension DateHeader where Leading == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String, dateSize: CGFloat = 14, hijriSize: CGFloat = 10) {
        self.init(title: title, subtitle: subtitle, dateSize: dateSize, hijriSize: hijriSize,
                  leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// Runder Glas-Knopf mit Symbol (Globus, Zahnrad, Pfeile)
struct GlassIcon: View {
    let systemName: String
    var size: CGFloat = 40
    var weight: Font.Weight = .semibold
    var scale: CGFloat = 0.45

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * scale, weight: weight))
            .foregroundStyle(Glass.text)
            .frame(width: size, height: size)
            .background(Circle().fill(Glass.tile))
            .contentShape(Circle())
    }
}

/// Pfeil zum Tageswechsel (wie auf der Website).
/// "backward/forward" spiegeln sich bei Arabisch automatisch.
struct ArrowLabel: View {
    let forward: Bool
    var size: CGFloat = 26

    var body: some View {
        GlassIcon(systemName: forward ? "chevron.forward" : "chevron.backward",
                  size: size, weight: .bold, scale: 0.42)
    }
}

/// Kachel "Aktuelles Gebet" / "Nächstes Gebet"
struct PrayerTile: View {
    enum Kind { case current(endsAt: Date), next }

    let kind: Kind
    let time: PrayerTime
    var nameSize: CGFloat = 15
    var timeSize: CGFloat = 30
    var labelSize: CGFloat = 8
    var footSize: CGFloat = 10
    var padding: CGFloat = 10
    var cornerRadius: CGFloat = 14
    var showBackground = true
    @Environment(\.appLanguage) var lang

    private var isCurrent: Bool {
        if case .current = kind { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isCurrent
                 ? lang.t("AKTUELLES GEBET", "ŞİMDİKİ VAKİT", "الصلاة الحالية")
                 : lang.t("NÄCHSTES GEBET", "SONRAKİ VAKİT", "الصلاة القادمة"))
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(isCurrent ? Glass.sub : Glass.faint)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 2)
            Text(time.prayer.name(lang))
                .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Glass.text)
                .minimumScaleFactor(0.7)
            Text(DateText.time(time.date, lang))
                .font(.system(size: timeSize, weight: .bold, design: .rounded))
                .foregroundStyle(Glass.text)
                .minimumScaleFactor(0.6)
            footer
                .font(.system(size: footSize, weight: .medium))
                .foregroundStyle(Glass.sub)
                .padding(.top, 1)
        }
        .lineLimit(1)
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if showBackground {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isCurrent ? Glass.tileHi : Glass.tile)
            }
        }
    }

    @ViewBuilder private var footer: some View {
        switch kind {
        case .current(let endsAt):
            let end = DateText.time(endsAt, lang)
            Text(lang.t("Endet · \(end) Uhr", "Bitiş · \(end)", "ينتهي · \(end)"))
        case .next:
            // Live-Countdown, von iOS selbst hochgezählt: "in 1 Std., 24 Min."
            Group {
                switch lang {
                case .de: Text("in \(time.date, style: .relative)")
                case .tr: Text("\(time.date, style: .relative) sonra")
                case .ar: Text("بعد \(time.date, style: .relative)")
                }
            }
            .minimumScaleFactor(0.6)
        }
    }
}

/// Alle Gebetszeiten des Tages, aktuelles hervorgehoben
struct DayList: View {
    let times: [PrayerTime]
    var highlight: PrayerTime? = nil
    var fontSize: CGFloat = 15
    @Environment(\.appLanguage) var lang

    var body: some View {
        VStack(spacing: 0) {
            ForEach(times, id: \.self) { item in
                let active = item == highlight
                HStack {
                    Text(item.prayer.name(lang))
                    Spacer()
                    Text(DateText.time(item.date, lang))
                }
                .font(.system(size: fontSize, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? Glass.text : Glass.sub)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Glass.rowHi)
                    }
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Glass.tile))
    }
}

/// Kompakte Übersicht eines Tages (3 × 2) für das mittlere Widget
struct DayGrid: View {
    let times: [PrayerTime]
    @Environment(\.appLanguage) var lang

    var body: some View {
        let rows = stride(from: 0, to: times.count, by: 2).map { Array(times[$0..<min($0 + 2, times.count)]) }
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 14) {
                    ForEach(rows[r], id: \.self) { item in
                        HStack {
                            Text(item.prayer.name(lang)).foregroundStyle(Glass.sub)
                            Spacer(minLength: 4)
                            Text(DateText.time(item.date, lang)).foregroundStyle(Glass.text)
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxHeight: .infinity)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Glass.tile))
    }
}
