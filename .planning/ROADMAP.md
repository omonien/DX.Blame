# Roadmap: DX.Blame

## Milestones

- ✅ **v1.0 DX.Blame: Inline Git Blame for Delphi IDE** — Phases 1-5 (shipped 2026-03-23)
- **v1.1 Mercurial Support** — Phases 6-10 (in progress)

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

### v1.1 Mercurial Support (In Progress)

**Milestone Goal:** Add full Mercurial blame support with VCS abstraction, achieving feature parity with Git.

- [ ] **Phase 6: VCS Abstraction Foundation** - Shared types, process base class, IVCSProvider interface, and Git provider wrapper
- [ ] **Phase 7: Engine VCS Dispatch** - Engine and commit detail units dispatch through IVCSProvider instead of direct Git calls
- [ ] **Phase 8: VCS Discovery** - Auto-detection of .git/.hg, hg.exe discovery, dual-VCS conflict resolution with per-project persistence
- [ ] **Phase 9: Mercurial Provider** - Full Mercurial blame, commit details, diff, and revision navigation at Git feature parity
- [ ] **Phase 10: Settings and TortoiseHg Integration** - VCS preference in settings dialog, TortoiseHg context menu actions

## Phase Details

### Phase 6: VCS Abstraction Foundation
**Goal**: Existing Git blame works identically but all VCS types, process execution, and provider interface are abstracted for multi-backend support
**Depends on**: Phase 5 (v1.0 complete)
**Requirements**: VCSA-01, VCSA-02, VCSA-03, VCSA-04
**Success Criteria** (what must be TRUE):
  1. Project compiles with DX.Blame.VCS.Types replacing DX.Blame.Git.Types across all units
  2. Git blame annotations still appear identically in the editor after all refactoring
  3. TGitProcess delegates to a shared TVCSProcess base class with no behavioral change
  4. IVCSProvider interface exists and TGitProvider implements it by wrapping existing Git units
**Plans:** 2 plans
Plans:
- [ ] 06-01-PLAN.md — Create VCS.Types, VCS.Process, VCS.Provider and refactor Git units
- [ ] 06-02-PLAN.md — Create TGitProvider, update consumer uses clauses, IDE verification

### Phase 7: Engine VCS Dispatch
**Goal**: The blame engine is fully provider-agnostic, dispatching all VCS operations through IVCSProvider with zero direct Git calls remaining
**Depends on**: Phase 6
**Requirements**: VCSA-05
**Success Criteria** (what must be TRUE):
  1. DX.Blame.Engine holds an IVCSProvider reference and uses no Git-specific units directly
  2. Commit detail popup and diff dialog retrieve data through the provider interface
  3. Revision navigation dispatches through the provider interface
  4. All existing Git blame functionality works unchanged through the abstraction layer
**Plans:** 1/2 plans executed
Plans:
- [ ] 07-01-PLAN.md — Refactor Engine and CommitDetail to dispatch through IVCSProvider
- [ ] 07-02-PLAN.md — Refactor Navigation, Popup, Diff.Form and verify zero Git imports

### Phase 8: VCS Discovery
**Goal**: The plugin automatically detects which VCS backend to use for the current project, with user override for dual-VCS repositories
**Depends on**: Phase 7
**Requirements**: VCSD-01, VCSD-02, VCSD-03, VCSD-04, VCSD-05
**Success Criteria** (what must be TRUE):
  1. Opening a project in a Git-only repo activates Git blame automatically (existing behavior preserved)
  2. Opening a project in an Hg-only repo detects .hg and locates hg.exe via PATH or TortoiseHg installation
  3. Opening a project with both .git and .hg prompts the user once; choice is persisted for that project
  4. The active VCS backend is reported in the IDE Messages pane
  5. Mercurial repository is verified with hg root before the Hg backend activates
**Plans**: TBD

### Phase 9: Mercurial Provider
**Goal**: Users see full blame annotations, commit details, diffs, and revision navigation for Mercurial-tracked files at parity with Git
**Depends on**: Phase 8
**Requirements**: HGB-01, HGB-02, HGB-03, HGB-04, HGB-05
**Success Criteria** (what must be TRUE):
  1. User sees inline blame annotations (author, relative time) for files in a Mercurial repository
  2. User clicks an annotation and sees commit details (hash, author, date, full message) from hg log
  3. User opens the diff dialog and sees RTF color-coded diff for a Mercurial commit
  4. User navigates to the annotated revision via context menu (hg cat retrieves file content)
  5. Mercurial blame uses a dedicated template-based parser, not an adapted Git parser
**Plans**: TBD

### Phase 10: Settings and TortoiseHg Integration
**Goal**: Users can configure VCS preference and launch TortoiseHg directly from the IDE context menu
**Depends on**: Phase 9
**Requirements**: SETT-01, SETT-02, SETT-03
**Success Criteria** (what must be TRUE):
  1. User can select Auto / Git / Mercurial as VCS preference in the settings dialog
  2. User can right-click and choose "Open in TortoiseHg Annotate" to launch thg annotate for the current file
  3. User can right-click and choose "Open in TortoiseHg Log" to launch thg log for the current file
**Plans**: TBD

## Progress

**Execution Order:** Phases 6 through 10, sequential.

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Package Foundation | v1.0 | 2/2 | Complete | 2026-03-19 |
| 2. Blame Data Pipeline | v1.0 | 3/3 | Complete | 2026-03-19 |
| 3. Inline Rendering and UX | v1.0 | 3/3 | Complete | 2026-03-23 |
| 4. Tooltip and Commit Detail | v1.0 | 2/2 | Complete | 2026-03-23 |
| 5. Tech Debt Cleanup | v1.0 | 1/1 | Complete | 2026-03-23 |
| 6. VCS Abstraction Foundation | v1.1 | 0/2 | Planned | - |
| 7. Engine VCS Dispatch | 1/2 | In Progress|  | - |
| 8. VCS Discovery | v1.1 | 0/0 | Not started | - |
| 9. Mercurial Provider | v1.1 | 0/0 | Not started | - |
| 10. Settings and TortoiseHg Integration | v1.1 | 0/0 | Not started | - |
