# Roadmap: DX.Blame

## Overview

DX.Blame delivers inline Git blame annotations in the Delphi IDE, progressing from a stable OTA plugin foundation through the async blame data pipeline, into visual rendering with full UX controls, and finally enhanced tooltip/commit detail views. Each phase builds on the previous and delivers an independently verifiable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Package Foundation** - Installable BPL with stable OTA lifecycle and clean unload (completed 2026-03-19)
- [ ] **Phase 2: Blame Data Pipeline** - Async git blame execution, parsing, and thread-safe caching
- [ ] **Phase 3: Inline Rendering and UX** - Visible blame annotations with toggle, navigation, and configuration
- [ ] **Phase 4: Tooltip and Commit Detail** - Hover tooltip with full commit info and diff detail view

## Phase Details

### Phase 1: Package Foundation
**Goal**: The plugin installs as a design-time BPL in Delphi 11.3+, 12, and 13, registers with the IDE, and unloads cleanly without crashes
**Depends on**: Nothing (first phase)
**Requirements**: UX-04
**Success Criteria** (what must be TRUE):
  1. User can install the BPL via Component > Install Packages in Delphi 11.3+, 12, and 13
  2. Plugin appears in the IDE splash screen and Help > About dialog
  3. User can uninstall and reinstall the BPL without IDE crashes or access violations
  4. OTA notifier registration and removal lifecycle is centralized and leak-free
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md — Project scaffold, build infrastructure, and OTA registration implementation
- [ ] 01-02-PLAN.md — DUnitX tests and IDE integration verification

### Phase 2: Blame Data Pipeline
**Goal**: The plugin detects git repos, executes git blame asynchronously, parses porcelain output, and stores results in a thread-safe per-file cache
**Depends on**: Phase 1
**Requirements**: BLAME-02, BLAME-03, BLAME-04, BLAME-05, BLAME-06
**Success Criteria** (what must be TRUE):
  1. Plugin detects whether the current project resides in a git repository (by walking parent directories for .git)
  2. Opening a file triggers an async git blame that completes without blocking the IDE
  3. Blame results (author, date, commit hash, message) are correctly parsed from git blame --porcelain output and stored per line
  4. Cached blame data is invalidated on file save and blame re-executes automatically
  5. Multiple files can be opened concurrently without race conditions or data corruption
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Inline Rendering and UX
**Goal**: Users see blame annotations inline at the end of the current code line and can toggle, configure, and navigate blame
**Depends on**: Phase 2
**Requirements**: BLAME-01, CONF-01, CONF-02, UX-01, UX-02, UX-03
**Success Criteria** (what must be TRUE):
  1. User sees author and relative time (e.g. "John Doe, 3 months ago") rendered after the last character of the current line
  2. User can toggle blame display on/off via IDE menu entry and via a configurable hotkey
  3. User can configure display format (author on/off, date format relative/absolute, max length) and blame text color, or color adapts to the current IDE theme automatically
  4. User can navigate to the previous revision (blame on parent commit) for the current line
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Tooltip and Commit Detail
**Goal**: Users get full commit context on hover and can drill into the complete diff without leaving the IDE
**Depends on**: Phase 3
**Requirements**: TTIP-01, TTIP-02
**Success Criteria** (what must be TRUE):
  1. Hovering over the blame annotation shows a tooltip with commit hash, author, full date, and complete commit message
  2. User can open a commit detail view from the tooltip that displays the full diff (git show output) in a modal dialog
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Package Foundation | 2/2 | Complete   | 2026-03-19 |
| 2. Blame Data Pipeline | 0/? | Not started | - |
| 3. Inline Rendering and UX | 0/? | Not started | - |
| 4. Tooltip and Commit Detail | 0/? | Not started | - |
