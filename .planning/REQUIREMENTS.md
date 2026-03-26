# Requirements: DX.Blame v1.2

**Defined:** 2026-03-26
**Core Value:** Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## v1.2 Requirements

Requirements for UX Polish & Settings milestone. Each maps to roadmap phases.

### Display

- [x] **DISP-01**: Statusbar shows current line's blame info (author, relative time, summary) updating on cursor movement
- [x] **DISP-02**: Clicking statusbar blame opens commit detail popup
- [x] **DISP-03**: Annotation X position can be caret-anchored (follows caret column) instead of end-of-line
- [x] **DISP-04**: In all-lines mode, only the caret line uses caret-anchored positioning
- [x] **DISP-05**: Inline and statusbar display modes are independently toggleable

### Navigation

- [x] **NAV-01**: Editor context menu has "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark
- [x] **NAV-02**: Navigating to historical revision scrolls to and centers the source line

### Settings

- [x] **SETT-01**: Settings are accessible via Tools > Options > Third Party > DX.Blame (INTAAddInOptions TFrame)
- [x] **SETT-02**: Options page includes all existing and new settings (anchor mode, statusbar toggle)
- [ ] **SETT-03**: Tools > DX.Blame menu items are removed after Options page migration

## Future Requirements

Deferred to v1.3+. Tracked but not in current roadmap.

### Display

- **DISP-F01**: Annotation heatmap coloring (color-code by commit age)
- **DISP-F02**: Configurable annotation format template (token-based like GitLens)

### Settings

- **SETT-F01**: Per-project settings profiles

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Hover tooltip on annotation | OTA lacks reliable hover detection on custom-painted regions. Rejected in v1.0 design. |
| Gutter-based blame column (IntelliJ style) | Different UX paradigm, conflicts with line numbers/breakpoints. Keep GitLens inline pattern. |
| Custom statusbar panel positioning | Delphi IDE statusbar panels have limited flexibility. Fixed position sufficient. |
| Per-file settings | Persistence complexity outweighs benefit. Global settings with per-project VCS override sufficient. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISP-01 | Phase 13 | Complete |
| DISP-02 | Phase 13 | Complete |
| DISP-03 | Phase 12 | Complete |
| DISP-04 | Phase 12 | Complete |
| DISP-05 | Phase 12 | Complete |
| NAV-01 | Phase 13 | Complete |
| NAV-02 | Phase 13 | Complete |
| SETT-01 | Phase 14 | Complete |
| SETT-02 | Phase 14 | Complete |
| SETT-03 | Phase 14 | Pending |

**Coverage:**
- v1.2 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-03-26*
*Last updated: 2026-03-26 after roadmap creation*
