# Requirements: DX.Blame

**Defined:** 2026-03-17
**Core Value:** Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Blame Core

- [ ] **BLAME-01**: User sieht inline am Zeilenende den Autor und die relative Zeit der letzten Änderung
- [x] **BLAME-02**: Plugin erkennt automatisch ob das aktuelle Projekt in einem Git-Repository liegt
- [x] **BLAME-03**: Blame wird beim Öffnen einer Datei automatisch asynchron ausgeführt
- [x] **BLAME-04**: Git blame wird per CLI (`git blame --porcelain`) in einem Hintergrund-Thread ausgeführt
- [x] **BLAME-05**: Blame-Ergebnisse werden pro Datei im Speicher gecacht
- [x] **BLAME-06**: Cache wird bei Datei-Save invalidiert und Blame automatisch neu ausgeführt

### Tooltip & Detail

- [ ] **TTIP-01**: User sieht bei Hover über die Blame-Annotation einen Tooltip mit Commit-Hash, Autor, Datum und voller Commit-Message
- [ ] **TTIP-02**: User kann aus dem Tooltip heraus eine Commit-Detail-Ansicht mit vollem Diff öffnen

### Konfiguration

- [x] **CONF-01**: User kann das Anzeige-Format konfigurieren (Autor ein/aus, Datumsformat relativ/absolut, Max-Länge)
- [x] **CONF-02**: User kann die Blame-Textfarbe konfigurieren oder sie wird automatisch aus dem IDE-Theme abgeleitet

### UX & Integration

- [ ] **UX-01**: User kann Blame per Menü-Eintrag ein- und ausschalten
- [ ] **UX-02**: User kann Blame per konfigurierbarem Hotkey ein- und ausschalten
- [ ] **UX-03**: User kann zur vorherigen Revision navigieren (Blame auf Parent-Commit)
- [x] **UX-04**: Plugin wird als Design-Time Package (BPL) installiert und unterstützt Delphi 11.3+, 12 und 13

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Extended Features

- **EXT-01**: Blame für markierte Zeilen (Selektion) statt nur aktuelle Zeile
- **EXT-02**: Gutter-Spalte als alternative Darstellung
- **EXT-03**: Blame-Heatmap (ältere Zeilen dunkler, neuere heller)

## Out of Scope

| Feature | Reason |
|---------|--------|
| libgit2 native Bindings | Unnötige Komplexität, DLL-Distribution, git CLI ist einfacher und zuverlässiger |
| Full Git History Browser | Scope creep — viele Tools tun das bereits gut |
| Blame für ungespeicherte Änderungen | Technisch unmöglich (git kennt nur committed State) |
| SVN/Mercurial Support | Fragmentiert den Aufwand, winzige Nutzerbasis |
| Real-time Blame (bei jedem Tastendruck) | Performance-Killer, sinnlos für uncommitted Änderungen |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BLAME-01 | Phase 3 | Pending |
| BLAME-02 | Phase 2 | Complete |
| BLAME-03 | Phase 2 | Complete |
| BLAME-04 | Phase 2 | Complete |
| BLAME-05 | Phase 2 | Complete |
| BLAME-06 | Phase 2 | Complete |
| TTIP-01 | Phase 4 | Pending |
| TTIP-02 | Phase 4 | Pending |
| CONF-01 | Phase 3 | Complete |
| CONF-02 | Phase 3 | Complete |
| UX-01 | Phase 3 | Pending |
| UX-02 | Phase 3 | Pending |
| UX-03 | Phase 3 | Pending |
| UX-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-03-17*
*Last updated: 2026-03-17 after roadmap creation*
