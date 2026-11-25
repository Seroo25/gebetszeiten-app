# Gebetszeiten – Ahlu-s Sunnah Zentrum Salzgitter

iOS-App mit Homescreen-Widget (klein, mittel, groß) im Liquid-Glass-Stil.
Sprachen: Deutsch, Türkçe, العربية (Globus oben links in der App; im Widget über „Widget bearbeiten“).
Benachrichtigungen zu jedem Gebet (Zahnrad oben rechts → Benachrichtigungen).
Die Zeiten kommen direkt aus der Gebetszeiten-App von [islamsalzgitter.de](https://www.islamsalzgitter.de/gebetszeiten/).

**Vorteil gegenüber dem Scriptable-Widget:** Das Widget übergibt iOS alle Wechsel (Mitternacht und jedes Gebet) im Voraus.
Datum, aktuelles und nächstes Gebet springen deshalb minutengenau um, ohne Automation und ohne manuelles Aktualisieren.

## Installation mit AltStore (ohne Mac)

1. **AltServer** auf dem Windows-PC installieren: <https://altstore.io> → AltServer für Windows.
   iTunes und iCloud werden von der Apple-Webseite benötigt, nicht aus dem Microsoft Store.
2. iPhone per Kabel anschließen. Dann AltServer-Symbol in der Taskleiste → *Install AltStore* → iPhone wählen → mit deiner Apple-ID anmelden.
3. Auf dem iPhone: *Einstellungen → Allgemein → VPN & Geräteverwaltung* → deiner Apple-ID vertrauen.
   Außerdem *Einstellungen → Datenschutz & Sicherheit → Entwicklermodus* einschalten und neu starten.
4. Auf dem iPhone in Safari die **neueste `Gebetszeiten.ipa`** unter *Releases* dieses Repositories herunterladen.
5. In AltStore → *My Apps* → **+** → `Gebetszeiten.ipa` aus *Downloads* wählen.
6. Homescreen lang drücken → *Bearbeiten* → *Widget hinzufügen* → **Gebetszeiten**.

Mit kostenloser Apple-ID läuft die App 7 Tage. AltStore verlängert das automatisch, wenn der PC mit AltServer läuft und im selben WLAN ist.
Alternativ in AltStore auf *Refresh All* tippen.

## Bauen

GitHub Actions baut bei jedem Push automatisch eine unsignierte `.ipa` (siehe `.github/workflows/build.yml`).
Das Projekt wird mit [XcodeGen](https://github.com/yonaskolb/XcodeGen) aus `project.yml` erzeugt.

```
App/       App (Übersicht aller Zeiten)
Widget/    Widget-Erweiterung (Timeline mit allen Wechseln)
Shared/    Daten laden, Zeiten berechnen, Glas-Ansichten
```
