# Requirements: DX.Blame

**Defined:** 2026-03-23
**Core Value:** Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## v1.1 Requirements

Requirements for Mercurial support milestone. Each maps to roadmap phases.

### VCS Abstraction

- [x] **VCSA-01**: IVCSProvider interface defines blame, commit detail, diff, file-at-revision, and discovery operations
- [x] **VCSA-02**: Shared VCS-neutral types (TBlameLineInfo, TBlameData, TCommitDetail) in DX.Blame.VCS.Types
- [x] **VCSA-03**: Shared TVCSProcess base class extracted from TGitProcess for DRY CLI execution
- [x] **VCSA-04**: TGitProvider wraps existing Git units behind IVCSProvider interface
- [x] **VCSA-05**: Engine dispatches all VCS operations through IVCSProvider (no direct Git calls)

### Mercurial Blame

- [ ] **HGB-01**: User sees inline blame annotations for Mercurial-tracked files via hg annotate -T
- [ ] **HGB-02**: User can click annotation to see commit details (hash, author, date, message) via hg log
- [ ] **HGB-03**: User can view RTF color-coded diff for Mercurial commits via hg diff -c
- [ ] **HGB-04**: User can navigate to annotated revision via hg cat -r
- [x] **HGB-05**: Mercurial blame uses dedicated template-based parser (not adapted Git parser)

### VCS Detection

- [x] **VCSD-01**: Plugin auto-detects .git or .hg directory in project tree
- [x] **VCSD-02**: Plugin discovers hg.exe via PATH and TortoiseHg installation paths
- [x] **VCSD-03**: Plugin verifies repository with hg root before activating Mercurial backend
- [x] **VCSD-04**: User is prompted once per project when both .git and .hg are present, choice is persisted
- [x] **VCSD-05**: Active VCS backend is indicated in IDE Messages

### Settings & UI

- [ ] **SETT-01**: User can select VCS preference (Auto/Git/Mercurial) in settings dialog
- [ ] **SETT-02**: User can open current file in TortoiseHg Annotate via context menu
- [ ] **SETT-03**: User can open current file in TortoiseHg Log via context menu

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### UX Improvements

- **UX-01**: Annotation X positioning anchored to caret column instead of end-of-line
- **UX-02**: Statusbar display mode as alternative to inline annotations
- **UX-03**: Context menu toggle for blame enable/disable with shortcut hint
- **UX-04**: Auto-scroll temp file to same line area when opening historical revision

## Out of Scope

| Feature | Reason |
|---------|--------|
| SVN or other VCS backends | Interface is extensible but only Git and Mercurial for v1.1 |
| libhg native bindings | Same rationale as libgit2 — CLI is simpler and more reliable |
| Mercurial blame for uncommitted lines | hg annotate only reflects committed state; accept as behavioral difference |
| Mercurial GUI integration beyond TortoiseHg | TortoiseHg is the dominant Windows Mercurial client |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| VCSA-01 | Phase 6 | Complete |
| VCSA-02 | Phase 6 | Complete |
| VCSA-03 | Phase 6 | Complete |
| VCSA-04 | Phase 6 | Complete |
| VCSA-05 | Phase 7 | Complete |
| HGB-01 | Phase 9 | Pending |
| HGB-02 | Phase 9 | Pending |
| HGB-03 | Phase 9 | Pending |
| HGB-04 | Phase 9 | Pending |
| HGB-05 | Phase 9 | Complete |
| VCSD-01 | Phase 8 | Complete |
| VCSD-02 | Phase 8 | Complete |
| VCSD-03 | Phase 8 | Complete |
| VCSD-04 | Phase 8 | Complete |
| VCSD-05 | Phase 8 | Complete |
| SETT-01 | Phase 10 | Pending |
| SETT-02 | Phase 10 | Pending |
| SETT-03 | Phase 10 | Pending |

**Coverage:**
- v1.1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-23*
*Last updated: 2026-03-23 after roadmap creation*
