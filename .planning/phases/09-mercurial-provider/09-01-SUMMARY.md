---
phase: 09-mercurial-provider
plan: 01
subsystem: vcs
tags: [mercurial, hg, annotate, parser, template, blame]

# Dependency graph
requires:
  - phase: 08-vcs-discovery
    provides: THgProvider stub with discovery methods, TVCSProcess base class
provides:
  - DX.Blame.Hg.Types with cHgUncommittedHash (40-char) and cHgNotCommittedAuthor
  - DX.Blame.Hg.Process with THgProcess subclass of TVCSProcess
  - DX.Blame.Hg.Blame with ParseHgAnnotateOutput and BuildAnnotateArgs
affects: [09-02-PLAN, mercurial-provider]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pipe-delimited template parsing with positional field extraction"
    - "Mercurial hg annotate -T with {lines % ...} template iteration"

key-files:
  created:
    - src/DX.Blame.Hg.Types.pas
    - src/DX.Blame.Hg.Process.pas
    - src/DX.Blame.Hg.Blame.pas
  modified: []

key-decisions:
  - "Used full 40-char node hash for cHgUncommittedHash (not 12-char short form)"
  - "Added {desc|firstline} as 5th template field for Summary population"
  - "Positional field extraction via Pos() with StartIndex instead of Split to handle pipes in line content"

patterns-established:
  - "Hg unit structure mirrors Git unit structure (Types, Process, Blame)"
  - "Template-based parser completely independent from Git porcelain parser per HGB-05"

requirements-completed: [HGB-05]

# Metrics
duration: 4min
completed: 2026-03-24
---

# Phase 9 Plan 1: Mercurial Foundation Units Summary

**Three Hg foundation units (Types, Process, Blame) with pipe-delimited template parser for hg annotate -T output**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T13:23:03Z
- **Completed:** 2026-03-24T13:27:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created Hg.Types with full 40-char uncommitted hash constant and author display constant
- Created Hg.Process as thin TVCSProcess subclass mirroring TGitProcess pattern
- Created Hg.Blame with dedicated template-based ParseHgAnnotateOutput parser and BuildAnnotateArgs command builder
- Parser handles: normal lines, author with/without email, uncommitted detection, empty input, malformed lines, summary field

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Hg.Types and Hg.Process units** - `ccd6515` (feat)
2. **Task 2: Create Hg.Blame parser with template command builder** - `cf09a25` (feat)

## Files Created/Modified
- `src/DX.Blame.Hg.Types.pas` - Mercurial sentinel constants (cHgUncommittedHash, cHgNotCommittedAuthor)
- `src/DX.Blame.Hg.Process.pas` - Thin TVCSProcess subclass with HgPath property
- `src/DX.Blame.Hg.Blame.pas` - Template-based annotate parser and command builder

## Decisions Made
- Used full 40-char node hash for cHgUncommittedHash instead of 12-char short form, matching what {node} returns in templates
- Added {desc|firstline} as 5th template field for Summary population (UX benefit per research recommendation)
- Used Pos() with StartIndex for positional field extraction instead of Split('|') to handle pipes in source code line content

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three Hg foundation units ready for Plan 02 to wire into THgProvider
- Units need to be added to DX.Blame.dpk contains clause (Plan 02 responsibility)
- Package compiles successfully with existing units unaffected

## Self-Check: PASSED

All 3 created files verified present. Both task commits (ccd6515, cf09a25) verified in git log.

---
*Phase: 09-mercurial-provider*
*Completed: 2026-03-24*
