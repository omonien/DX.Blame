# Milestones

## v1.2 UX Polish & Settings (Shipped: 2026-03-27)

**Phases completed:** 3 phases, 6 plans
**Timeline:** 1 day (2026-03-26)
**Stats:** 30 files changed, +4,381/-196 lines, 6,544 LOC Delphi across 31 units

**Key accomplishments:**
- Caret-anchored annotation positioning with Max(caretX, endOfLineX) pattern and dsAllLines guard (DISP-03, DISP-04)
- Independent inline/statusbar display toggles via orthogonal ShowInline + ShowStatusbar booleans (DISP-05)
- Statusbar blame display with TDXBlameStatusbar (TComponent + FreeNotification lifecycle), GOnCaretMoved callback, and click-to-popup (DISP-01, DISP-02)
- Context menu "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark via GOnContextMenuToggle callback (NAV-01)
- Auto-scroll on historical revision navigation via NavigateToRevision ALineNumber + SetCursorPos/Center (NAV-02)
- IDE Options page via TFrameDXBlameSettings + TDXBlameAddInOptions under Third Party, replacing Tools menu (SETT-01, SETT-02, SETT-03)

**Tech debt (non-blocking):**
- TFormDXBlameSettings remains compiled into BPL but never called (orphaned after Tools menu removal)
- SyncEnableBlameCheckmark is a no-op stub (callback contracts preserved)
- Statusbar attaches only to TopEditWindow (single-window limitation, documented)

**Audit:** 10/10 requirements, 7/7 E2E flows, all passed

---

## v1.1 Mercurial Support (Shipped: 2026-03-26)

**Phases completed:** 6 phases, 11 plans, 22 tasks
**Timeline:** 3 days (2026-03-23 to 2026-03-25)
**Stats:** 27 files changed, +1847/-455 lines, 6,558 LOC Delphi total

**Key accomplishments:**
- VCS abstraction layer with IVCSProvider interface, shared types (TBlameLineInfo, TBlameData), and TVCSProcess base class
- Engine fully provider-agnostic — all 5 consumer units dispatch through IVCSProvider with zero direct Git calls
- Auto-detection of Git/Hg repositories with dual-VCS prompt, per-project persistence, and IDE Messages logging
- Complete Mercurial blame at Git parity — annotations, commit details, RTF diffs, and revision navigation via hg CLI
- VCS preference setting (Auto/Git/Mercurial) and TortoiseHg Annotate/Log context menu integration
- Engine lifecycle fix — FRetryTimers dictionary and FVCSNotified reset on project switch (gap closure)

**Tech debt (non-blocking):**
- Stale "git show" comment in Navigation.pas remarks header (info only)
- ofnProjectDesktopLoad is the only project-switch hook (pre-existing OTA limitation)

**Audit:** 18/18 requirements, 6/6 E2E flows, all passed

---

## v1.0 DX.Blame: Inline Git Blame for Delphi IDE (Shipped: 2026-03-23)

**Phases completed:** 5 phases, 11 plans
**Timeline:** 7 days (2026-03-17 to 2026-03-23)
**Stats:** 85 commits, 103 files, 4,533 LOC Delphi

**Key accomplishments:**
- Compilable DX.Blame.bpl design-time package with OTA registration (wizard, splash, about box, Tools menu)
- Complete async git blame engine with porcelain parser, thread-safe cache, and 28 unit tests
- Inline blame annotations with configurable formatting, Ctrl+Alt+B toggle, settings dialog, and revision navigation
- Click-triggered popup panel with async commit detail fetch and modal diff dialog with RTF color-coded diffs
- Theme-aware annotation coloring via IDE editor background blending, circular dependency fix, and dead code cleanup

**Tech debt (non-blocking):**
- Placeholder comments in Registration.pas (intentional no-ops)
- DoRetryBlame timer-to-key ordering warning
- ROADMAP.md Phase 3 stale text ("parent commit" vs "annotated commit")
- Phase 4-02 SUMMARY phantom GetAnnotationHashLength documentation
- Double CleanupPopup call in finalization (safe but redundant)

**Audit:** 14/14 requirements, 6/6 E2E flows, all passed

---

