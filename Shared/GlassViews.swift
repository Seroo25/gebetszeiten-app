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

struct DateHeader: View {
    let date: Date
    var dateSize: CGFloat = 14
    var hijriSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 1) {
            Text(DateText.header(date))
                .font(.system(size: dateSize, weight: .bold, design: .rounded))
                .foregroundStyle(Glass.text)
            Text(DateText.hijri(date))
                .font(.system(size: hijriSize, weight: .medium))
                .foregroundStyle(Glass.sub)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
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

    private var isCurrent: Bool {
        if case .current = kind { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isCurrent ? "AKTUELLES GEBET" : "NÄCHSTES GEBET")
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(isCurrent ? Glass.sub : Glass.faint)
            Spacer(minLength: 2)
            Text(time.prayer.name)
                .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                .foregroundStyle(Glass.text)
            Text(DateText.time(time.date))
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
            Text("Endet · \(DateText.time(endsAt)) Uhr")
        case .next:
            // Live-Countdown, von iOS selbst hochgezählt: "in 1 Std., 24 Min."
            Text("in \(time.date, style: .relative)")
                .minimumScaleFactor(0.6)
        }
    }
}

/// Alle Gebetszeiten des Tages, aktuelles hervorgehoben
struct DayList: View {
    let state: PrayerState
    var fontSize: CGFloat = 15

    var body: some View {
        VStack(spacing: 0) {
            ForEach(state.today, id: \.self) { item in
                let active = item == state.current
                HStack {
                    Text(item.prayer.name)
                    Spacer()
                    Text(DateText.time(item.date))
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
