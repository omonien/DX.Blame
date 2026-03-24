---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Mercurial Support
status: executing
stopped_at: Completed 09-01-PLAN.md
last_updated: "2026-03-24T13:29:29.401Z"
last_activity: 2026-03-24 — Completed 09-01 Mercurial foundation units
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 8
  completed_plans: 7
  percent: 88
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-23)

**Core value:** Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geaendert hat und wann, ohne die IDE verlassen zu muessen.
**Current focus:** v1.1 Mercurial Support — Phase 9 in progress (Mercurial Provider)

## Current Position

Phase: 9 of 10 (Mercurial Provider)
Plan: 1 of 2 complete
Status: In Progress
Last activity: 2026-03-24 — Completed 09-01 Mercurial foundation units

Progress: [█████████░] 88%

## Performance Metrics

**Velocity:**
- Total plans completed: 11 (v1.0)
- Average duration: carried from v1.0
- Total execution time: carried from v1.0

**By Phase (v1.1):**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

*Updated after each plan completion*
| Phase 06 P01 | 3min | 2 tasks | 7 files |
| Phase 06 P02 | 5min | 2 tasks | 10 files |
| Phase 07 P01 | 4min | 2 tasks | 3 files |
| Phase 07 P02 | 3min | 2 tasks | 3 files |
| Phase 08 P01 | 3min | 2 tasks | 3 files |
| Phase 08 P02 | 3min | 2 tasks | 4 files |
| Phase 09 P01 | 4min | 2 tasks | 3 files |

## Accumulated Context

### Decisions

All v1.0 decisions validated with outcomes — see PROJECT.md Key Decisions table.
v1.1 research completed with HIGH confidence across all areas.
- [Phase 06]: TVCSProcess fields made protected for subclass property access
- [Phase 06]: Single IVCSProvider interface covering all operations per research recommendation
- [Phase 06]: TGitProvider delegates to existing Git units rather than reimplementing logic
- [Phase 07]: TBlameThread holds IVCSProvider interface reference for correct ref counting
- [Phase 07]: FetchCommitDetailAsync takes IVCSProvider as first parameter (breaking change for Plan 02)
- [Phase 07]: All consumer units (Navigation, Popup, Diff.Form) access VCS exclusively through BlameEngine.Provider
- [Phase 08]: No registry lookup for TortoiseHg — PATH + default dirs cover standard installs
- [Phase 08]: No fallback when hg.exe missing — Mercurial without executable is unusable
- [Phase 08]: Uncommitted hash uses Mercurial convention ffffffffffff (12 hex f chars)
- [Phase 08]: Nested local functions in DetectProvider keep interface minimal (single public class method)
- [Phase 08]: Default to Git when user dismisses dual-VCS dialog — preserves existing behavior
- [Phase 08]: OnProjectSwitch clears both Git and Hg caches explicitly (not via provider)
- [Phase 09]: Full 40-char node hash for cHgUncommittedHash (not 12-char short form from Phase 8)
- [Phase 09]: Added {desc|firstline} as 5th template field for Summary population
- [Phase 09]: Positional field extraction via Pos() instead of Split to handle pipes in line content

### Pending Todos

None.

### Blockers/Concerns

- Phase 9: Mercurial annotate parser is the most novel element — prototype template command against a real Hg repo before writing parser
- Phase 8: Dual-VCS prompt UX (modal dialog vs notification) must be decided before coding discovery module

## Session Continuity

Last session: 2026-03-24T13:29:29.358Z
Stopped at: Completed 09-01-PLAN.md
Resume file: None
