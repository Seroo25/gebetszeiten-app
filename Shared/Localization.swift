import SwiftUI

/// Sprachen der App. Die Übersetzungen stehen direkt im Code:
/// `lang.t("Deutsch", "Türkçe", "العربية")`
enum AppLanguage: String, CaseIterable, Identifiable {
    case de, tr, ar

    var id: String { rawValue }

    /// Name in der eigenen Sprache (für die Auswahl am Globus)
    var nativeName: String {
        switch self {
        case .de: return "Deutsch"
        case .tr: return "Türkçe"
        case .ar: return "العربية"
        }
    }

    var locale: Locale {
        switch self {
        case .de: return Locale(identifier: "de_DE")
        case .tr: return Locale(identifier: "tr_TR")
        case .ar: return Locale(identifier: "ar")
        }
    }

    /// Arabisch wird von rechts nach links gelesen
    var isRTL: Bool { self == .ar }

    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }

    /// Passende Übersetzung auswählen
    func t(_ de: String, _ tr: String, _ ar: String) -> String {
        switch self {
        case .de: return de
        case .tr: return tr
        case .ar: return ar
        }
    }

    /// Zahl in der Schrift der Sprache (Arabisch: ١٤٤٨)
    func number(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = locale
        f.usesGroupingSeparator = false
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }

    /// Sprache des iPhones, falls Türkisch oder Arabisch – sonst Deutsch
    static var device: AppLanguage {
        let first = Locale.preferredLanguages.first ?? "de"
        if first.hasPrefix("tr") { return .tr }
        if first.hasPrefix("ar") { return .ar }
        return .de
    }

    static let storageKey = "appLanguage"

    /// In der App gewählte Sprache (Standard: Sprache des iPhones)
    static var stored: AppLanguage {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppLanguage.init(rawValue:)) ?? device
    }
}

// MARK: - Sprache an alle Ansichten weitergeben

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .de
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

extension View {
    /// Setzt Sprache, Datums-/Zahlenformat und Leserichtung (Arabisch: rechts nach links)
    func appLanguage(_ lang: AppLanguage) -> some View {
        environment(\.appLanguage, lang)
            .environment(\.locale, lang.locale)
            .environment(\.layoutDirection, lang.layoutDirection)
    }
}
