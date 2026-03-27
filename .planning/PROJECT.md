# DX.Blame

## What This Is

Ein Delphi IDE Plugin (Design-Time Package), das Git- und Mercurial-Blame-Informationen inline im Code-Editor anzeigt. Annotation am Zeilenende oder caret-verankert, mit Statusbar-Anzeige, Kontextmenü-Toggle, und IDE Options Page. Klick auf Annotation oder Statusbar zeigt Commit-Details mit farbcodiertem Diff.

## Core Value

Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## Requirements

### Validated

- ✓ Inline Blame-Anzeige am Zeilenende (Autor, relative Zeit) — v1.0
- ✓ Klick-Popup mit Commit-Hash, voller Commit-Message, Datum, Autor — v1.0
- ✓ Commit-Detail-Ansicht (voller Diff) aus dem Popup heraus — v1.0
- ✓ Git-Repo-Erkennung für das aktuelle Projekt — v1.0
- ✓ Lazy Blame beim Datei-Öffnen mit Caching — v1.0
- ✓ Cache-Invalidierung bei Dateiänderungen — v1.0
- ✓ Toggle per Menü und konfigurierbarem Hotkey (Ctrl+Alt+B) — v1.0
- ✓ Git CLI Integration (git blame --porcelain) — v1.0
- ✓ Unterstützung für Delphi 11, 12 und 13 — v1.0
- ✓ Design-Time Package (BPL) Installation — v1.0
- ✓ Konfigurierbare Anzeige (Autor, Datumsformat, Max-Länge, Farbe) — v1.0
- ✓ Theme-aware Annotation-Farbe (automatische Ableitung aus IDE-Theme) — v1.0
- ✓ Navigation zur annotierten Revision per Kontextmenü — v1.0
- ✓ RTF-farbcodierter Diff-Dialog mit Scope-Toggle und Größenpersistenz — v1.0
- ✓ VCS abstraction layer (IVCSProvider interface, Git and Hg backends) — v1.1
- ✓ Full Mercurial blame parity (annotations, commit details, diffs, revision nav) — v1.1
- ✓ TortoiseHg context menu integration (Annotate, Log) — v1.1
- ✓ Auto-detection of .git / .hg in project directory — v1.1
- ✓ VCS preference prompt when both Git and Hg are present (remember per project) — v1.1
- ✓ Settings dialog updated for VCS preference (Auto/Git/Mercurial) — v1.1
- ✓ Caret-anchored annotation X positioning (configurable, dsAllLines guard) — v1.2
- ✓ Independent inline/statusbar display toggles (ShowInline + ShowStatusbar) — v1.2
- ✓ Statusbar blame display with click-to-popup (TDXBlameStatusbar + FreeNotification) — v1.2
- ✓ Context menu "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark — v1.2
- ✓ Auto-scroll historical revision to source line (NavigateToRevision + SetCursorPos/Center) — v1.2
- ✓ IDE Options page under Third Party > DX Blame (INTAAddInOptions TFrame) — v1.2
- ✓ Tools menu removed after IDE Options migration — v1.2

### Active

(No active milestone — planning next)

### Out of Scope

- libgit2/libhg native Bindings — unnötige Komplexität, CLI ist zuverlässiger und einfacher
- Blame für nicht-gespeicherte Änderungen — nur committed/staged Code
- Git/Hg History Browser — nur Blame, kein vollständiger VCS-Client
- Andere VCS (SVN) — nur Git und Mercurial (IVCSProvider ist erweiterbar)
- Real-time Blame bei jedem Tastendruck — Performance-Killer, sinnlos für uncommitted Änderungen
- Mercurial GUI integration beyond TortoiseHg — TortoiseHg is the dominant Windows Mercurial client
- Annotation heatmap coloring (color-code by commit age) — deferred to v1.3+
- Configurable annotation format template (token-based like GitLens) — over-engineering for ~100 users
- Per-project settings profiles — persistence complexity outweighs benefit

## Context

Shipped v1.2 with 6,544 LOC Delphi across 31 units.
Tech stack: Delphi, Open Tools API, git CLI, hg CLI, TortoiseHg (thg).
Architecture: OTA plugin with async blame engine, IVCSProvider abstraction, thread-safe cache, INTACodeEditorEvents renderer, INTAAddInOptions settings page.

- IVCSProvider interface with TGitProvider and THgProvider backends
- TVCSDiscovery orchestrator for auto-detection of Git/Hg with dual-VCS prompt
- Mercurial blame via `hg annotate -T` with dedicated template-based parser
- TortoiseHg context menu integration (Annotate, Log) via ShellExecute
- VCS preference setting (Auto/Git/Mercurial) with per-project persistence
- Editor-Notifier (IOTAEditorNotifier) für Tab-Wechsel und Änderungen
- INTAEditServicesNotifier für Cursor-Tracking im Editor
- Click-based popup (not hover) for commit details — EditorMouseDown detection
- Modal diff dialog with RTF coloring and DPI-aware scaling
- TDXBlameStatusbar with FreeNotification panel lifecycle and GOnCaretMoved callback
- TFrameDXBlameSettings + TDXBlameAddInOptions for IDE Options integration
- Caret-anchored annotation positioning with Max(caretX, endOfLineX) pattern

## Constraints

- **Tech Stack**: Delphi, Open Tools API — kein externes Framework
- **Git**: Muss im PATH verfügbar sein, keine eingebettete Git-Installation
- **Kompatibilität**: Delphi 11 Alexandria, 12 Athens, 13 — bedingte Kompilierung wo nötig
- **Performance**: Blame darf den IDE-Workflow nicht blockieren — asynchrone Ausführung erforderlich

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Inline am Zeilenende statt Gutter | Wie GitLens — vertrautes UX-Pattern, weniger invasiv | ✓ Good — works well, users see annotation naturally |
| Git CLI statt libgit2 | Einfacher, zuverlässiger, weniger Abhängigkeiten | ✓ Good — reliable, no DLL distribution needed |
| Design-Time Package statt DLL Expert | Standard für IDE-Plugins, einfachere Installation | ✓ Good — standard install via Component > Install Packages |
| Lazy + Cache Strategie | Ganze Datei beim Öffnen blamen, dann aus Cache — guter Kompromiss | ✓ Good — no perceptible delay, cache invalidation on save works |
| Delphi 11+ Support | Breite Nutzerbasis, OTA-Interfaces stabil seit 11 | ✓ Good — {$LIBSUFFIX AUTO} handles version suffixes |
| Click-Popup statt Hover-Tooltip | Hover-Detection in OTA nicht zuverlässig machbar | ✓ Good — click on author name triggers popup, feels natural |
| Pre-compile .rc to .res with BRCC32 | Avoids RLINK32 16-bit resource error in Delphi 13 | ✓ Good — solved cross-version resource compilation |
| Midpoint blend for annotation color | (channel + 128) / 2 for theme-aware color | ✓ Good — works with light and dark themes |
| OnBlameToggled callback pattern | Break circular dependency KeyBinding ↔ Registration | ✓ Good — clean decoupling via TProc |
| IVCSProvider single interface | One interface covering all VCS operations (blame, commit, diff, nav, discovery) | ✓ Good — clean dispatch, both backends implement identically |
| TVCSProcess base class | Extract shared CreateProcess/pipe logic from TGitProcess | ✓ Good — DRY, THgProcess is 30-line thin subclass |
| hg annotate -T with template | Dedicated template-based parser instead of adapting Git parser | ✓ Good — independent, clean separation, pipe-delimited format |
| Derive thg.exe from hg.exe path | Same directory lookup instead of separate registry/PATH search | ✓ Good — simple, TortoiseHg always co-locates binaries |
| MD5-hashed project path for VCS choice | Persist dual-VCS choice without exposing file paths in INI | ✓ Good — deterministic, no path collisions |
| FRetryTimers parallel to FDebounceTimers | Separate dictionary for retry timers following identical lifecycle pattern | ✓ Good — consistent, easy to maintain |
| Max(caretX, endOfLineX) for caret-anchor | Prevents annotation from jumping left of end-of-line on short lines | ✓ Good — stable visual behavior |
| GOnCaretMoved procedure variable | Piggybacking on EditorSetCaretPos avoids duplicate INTAEditServicesNotifier | ✓ Good — consistent with OnBlameToggled pattern |
| GOnContextMenuToggle callback | Avoids circular dependency Navigation ↔ Registration | ✓ Good — identical pattern to OnBlameToggled |
| TDXBlameStatusbar as TComponent | FreeNotification guards against edit window destruction AV | ✓ Good — safe panel lifecycle |
| INTAAddInOptions thin adapter | TFrame with LoadFromSettings/SaveToSettings, adapter delegates | ✓ Good — clean separation, IDE manages frame lifetime |
| SyncEnableBlameCheckmark as no-op stub | Keep procedure to satisfy callback contracts after Tools menu removal | ✓ Good — no compilation breaks |

---
*Last updated: 2026-03-27 after v1.2 milestone*
