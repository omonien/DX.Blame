# Roadmap: DX.Blame

## Milestones

- ✅ **v1.0 DX.Blame: Inline Git Blame for Delphi IDE** — Phases 1-5 (shipped 2026-03-23)
- ✅ **v1.1 Mercurial Support** — Phases 6-11 (shipped 2026-03-26)
- **v1.2 UX Polish & Settings** — Phases 12-14 (in progress)

## Phases

<details>
<summary>v1.0 DX.Blame (Phases 1-5) — SHIPPED 2026-03-23</summary>

- [x] Phase 1: Package Foundation (2/2 plans) — completed 2026-03-19
- [x] Phase 2: Blame Data Pipeline (3/3 plans) — completed 2026-03-19
- [x] Phase 3: Inline Rendering and UX (3/3 plans) — completed 2026-03-23
- [x] Phase 4: Tooltip and Commit Detail (2/2 plans) — completed 2026-03-23
- [x] Phase 5: Tech Debt Cleanup (1/1 plan) — completed 2026-03-23

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>v1.1 Mercurial Support (Phases 6-11) — SHIPPED 2026-03-26</summary>

- [x] Phase 6: VCS Abstraction Foundation (2/2 plans) — completed 2026-03-24
- [x] Phase 7: Engine VCS Dispatch (2/2 plans) — completed 2026-03-24
- [x] Phase 8: VCS Discovery (2/2 plans) — completed 2026-03-24
- [x] Phase 9: Mercurial Provider (2/2 plans) — completed 2026-03-24
- [x] Phase 10: Settings and TortoiseHg Integration (2/2 plans) — completed 2026-03-24
- [x] Phase 11: Engine Project-Switch Lifecycle Fix (1/1 plan) — completed 2026-03-25

Full details: [milestones/v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md)

</details>

### v1.2 UX Polish & Settings

**Milestone Goal:** Improve annotation display flexibility, add statusbar mode, streamline settings into IDE Options, and add context menu toggle.

- [x] **Phase 12: Settings Foundation & Annotation Positioning** - New settings properties and caret-anchored annotation rendering (completed 2026-03-26)
- [ ] **Phase 13: Statusbar Display & Navigation** - Statusbar blame panel, context menu toggle, and auto-scroll on revision navigation
- [ ] **Phase 14: IDE Options Migration** - Extract settings into TFrame, register as IDE Options page, remove Tools menu

## Phase Details

### Phase 12: Settings Foundation & Annotation Positioning
**Goal**: Annotations can be positioned relative to the caret instead of end-of-line, with inline and statusbar modes independently controllable
**Depends on**: Phase 11 (v1.1 complete)
**Requirements**: DISP-03, DISP-04, DISP-05
**Success Criteria** (what must be TRUE):
  1. User can switch annotation positioning from end-of-line to caret-anchored in settings
  2. In all-lines mode with caret-anchored positioning, only the caret line's annotation follows the caret column while other lines remain end-of-line
  3. User can independently enable/disable inline annotations and statusbar display (four combinations possible)
**Plans**: 2 plans

Plans:
- [x] 12-01-PLAN.md — AnnotationPosition setting, caret-anchored X in PaintLine, settings UI
- [ ] 12-02-PLAN.md — ShowInline toggle with renderer guard and settings UI

### Phase 13: Statusbar Display & Navigation
**Goal**: Users can see blame info in the statusbar and toggle blame from the context menu, with historical revision navigation scrolling to the source line
**Depends on**: Phase 12
**Requirements**: DISP-01, DISP-02, NAV-01, NAV-02
**Success Criteria** (what must be TRUE):
  1. Statusbar shows current line's blame info (author, relative time, summary) and updates when the cursor moves to a different line
  2. Clicking the statusbar blame panel opens the commit detail popup
  3. Editor context menu shows "Enable/Disable Blame (Ctrl+Alt+B)" with a checkmark reflecting current state
  4. Navigating to a historical revision scrolls the editor to and centers the originating source line
**Plans**: TBD

Plans:
- [ ] 13-01: Statusbar blame display and click handler
- [ ] 13-02: Context menu toggle and auto-scroll

### Phase 14: IDE Options Migration
**Goal**: All DX.Blame settings are accessible through the standard IDE Options dialog, and the legacy Tools menu entries are removed
**Depends on**: Phase 13
**Requirements**: SETT-01, SETT-02, SETT-03
**Success Criteria** (what must be TRUE):
  1. User can navigate to Tools > Options > Third Party > DX.Blame and see a settings page
  2. The Options page includes all settings: anchor mode, statusbar toggle, inline toggle, VCS preference, and all existing display settings
  3. Tools > DX.Blame menu items (Settings dialog, Toggle) are removed from the IDE menu
**Plans**: TBD

Plans:
- [ ] 14-01: Settings frame extraction and IDE Options registration
- [ ] 14-02: Tools menu removal and integration wiring

## Progress

**Execution Order:** Phase 12 > 13 > 14

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Package Foundation | v1.0 | 2/2 | Complete | 2026-03-19 |
| 2. Blame Data Pipeline | v1.0 | 3/3 | Complete | 2026-03-19 |
| 3. Inline Rendering and UX | v1.0 | 3/3 | Complete | 2026-03-23 |
| 4. Tooltip and Commit Detail | v1.0 | 2/2 | Complete | 2026-03-23 |
| 5. Tech Debt Cleanup | v1.0 | 1/1 | Complete | 2026-03-23 |
| 6. VCS Abstraction Foundation | v1.1 | 2/2 | Complete | 2026-03-24 |
| 7. Engine VCS Dispatch | v1.1 | 2/2 | Complete | 2026-03-24 |
| 8. VCS Discovery | v1.1 | 2/2 | Complete | 2026-03-24 |
| 9. Mercurial Provider | v1.1 | 2/2 | Complete | 2026-03-24 |
| 10. Settings and TortoiseHg Integration | v1.1 | 2/2 | Complete | 2026-03-24 |
| 11. Engine Project-Switch Lifecycle Fix | v1.1 | 1/1 | Complete | 2026-03-25 |
| 12. Settings Foundation & Annotation Positioning | 2/2 | Complete    | 2026-03-26 | - |
| 13. Statusbar Display & Navigation | v1.2 | 0/2 | Not started | - |
| 14. IDE Options Migration | v1.2 | 0/2 | Not started | - |
