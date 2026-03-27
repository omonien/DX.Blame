# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — DX.Blame: Inline Git Blame for Delphi IDE

**Shipped:** 2026-03-23
**Phases:** 5 | **Plans:** 11 | **Timeline:** 7 days

### What Was Built
- Design-time BPL package with full OTA lifecycle (wizard, splash, about box, menu)
- Async git blame engine with porcelain parser and thread-safe per-file cache
- Inline blame annotations with configurable formatting and theme-aware coloring
- Click-triggered popup with commit details and modal RTF diff dialog
- 28 unit tests covering parser, formatter, cache, and diff coloring

### What Worked
- Coarse phase granularity (5 phases for full plugin) kept planning overhead low
- Async-first architecture avoided all IDE blocking issues from the start
- Click-based popup (instead of hover tooltip) was simpler to implement and more reliable in OTA
- Pre-compiling .rc to .res with BRCC32 solved Delphi 13 RLINK32 compatibility immediately
- Thread-safe cache with TObjectDictionary + TCriticalSection was straightforward and correct

### What Was Inefficient
- Phase 4-02 SUMMARY documented phantom GetAnnotationHashLength feature that never existed in code — documentation divergence went unnoticed until audit
- Double CleanupPopup call (Registration + Renderer finalization) — redundant safety that could have been caught during Phase 4 review
- ROADMAP.md Phase 3 success criterion stale text survived through completion — should have been caught during phase verification

### Patterns Established
- OnBlameToggled TProc callback pattern for decoupling circular unit dependencies
- Midpoint blend formula `(channel + 128) / 2` for theme-aware annotation colors
- Unit-level dictionaries (GAnnotationXByRow, GLineByRow) for annotation hit-test data
- {$LIBSUFFIX AUTO} in DPK for automatic compiler version suffix across Delphi 11-13
- STRONGLINKTYPES ON + explicit RegisterTestFixture for reliable DUnitX discovery

### Key Lessons
1. Click-based interaction is more reliable than hover in Delphi OTA — EditorMouseDown gives precise coordinates; hover detection is fragile
2. Delphi 13 introduced stricter compiler rules (initialization before finalization) — always test newest compiler version first
3. Documentation divergence accumulates silently — SUMMARY files should be verified against actual code, not just plan completion

### Cost Observations
- Model mix: quality profile (opus-heavy)
- Average plan execution: 8min across 11 plans
- Total execution time: ~0.8 hours for 11 plans
- Notable: Phase 5 (tech debt) completed in 2min — focused cleanup phases are efficient

---

## Milestone: v1.1 — Mercurial Support

**Shipped:** 2026-03-26
**Phases:** 6 | **Plans:** 11 | **Timeline:** 3 days

### What Was Built
- IVCSProvider abstraction layer with shared types, process base class, and interface-based dispatch
- Full engine refactor — all 5 consumer units dispatch through IVCSProvider with zero direct Git calls
- Auto-detection of Git/Hg repositories with dual-VCS prompt and per-project persistence
- Complete Mercurial blame at Git parity — annotations, commit details, RTF diffs, revision navigation
- VCS preference setting (Auto/Git/Mercurial) and TortoiseHg Annotate/Log context menu items
- Engine lifecycle fix — FRetryTimers dictionary and FVCSNotified reset on project switch

### What Worked
- Mirror pattern strategy: building THgProvider as an exact structural mirror of TGitProvider kept both implementations consistent and the code reviewable
- Phase-sequential architecture: each phase cleanly built on the previous (abstraction → dispatch → discovery → provider → settings → fix)
- Milestone audit → gap closure cycle: MISS-1 and MISS-2 caught by the v1.1 audit were resolved in Phase 11 within minutes
- Template-based hg annotate parser: pipe-delimited format was clean to parse and completely independent from Git's porcelain parser
- Derive thg.exe from hg.exe path: simple co-location assumption avoided registry/PATH complexity

### What Was Inefficient
- Phases 6 and 7 ROADMAP checkboxes not marked `[x]` despite complete execution — cosmetic tracking gap that persisted until Phase 11
- Some SUMMARY.md files lack `one_liner` frontmatter field — needed manual extraction at milestone completion
- Nyquist VALIDATION.md files for Phases 6-10 created but never populated during execution (feature added mid-milestone)

### Patterns Established
- IVCSProvider interface pattern for multi-backend VCS dispatch
- TVCSDiscovery with nested local functions (ScanForVCS, ResolveChoice, PromptForVCS) for minimal public API
- MD5-hashed project path key for per-project settings persistence
- FRetryTimers/FDebounceTimers parallel dictionary pattern for tracked timer lifecycle
- Conditional context menu injection via provider display name check

### Key Lessons
1. Gap closure phases are highly efficient — Phase 11 (2 tasks, 1 file) took 2 minutes because the research was precise and the fix pattern was established
2. Milestone audits surface bugs that phase-level verification misses — MISS-1 and MISS-2 were cross-phase lifecycle issues invisible at single-phase granularity
3. Template-based CLI output (hg annotate -T) produces cleaner parse targets than format-dependent output — consider this pattern for future CLI integrations

### Cost Observations
- Model mix: quality profile (opus-heavy), sonnet for checkers/verifiers
- Average plan execution: ~3.5min across 11 plans
- Total execution time: ~0.6 hours for 11 plans
- Notable: Entire milestone (6 phases, 11 plans) completed in 3 calendar days

---

## Milestone: v1.2 — UX Polish & Settings

**Shipped:** 2026-03-27
**Phases:** 3 | **Plans:** 6 | **Timeline:** 1 day

### What Was Built
- Caret-anchored annotation positioning with Max(caretX, endOfLineX) and dsAllLines caret-line guard
- Independent inline/statusbar display toggles via orthogonal ShowInline + ShowStatusbar booleans
- TDXBlameStatusbar with TComponent FreeNotification lifecycle, GOnCaretMoved callback, click-to-popup
- Context menu "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark via GOnContextMenuToggle callback
- Auto-scroll on historical revision navigation (NavigateToRevision + SetCursorPos/Center)
- IDE Options page via TFrameDXBlameSettings + TDXBlameAddInOptions, replacing Tools menu entirely

### What Worked
- Auto-advance pipeline (plan → execute chaining) completed all 3 phases in a single session without manual intervention
- Callback-variable pattern (GOnCaretMoved, GOnContextMenuToggle) reused from v1.0's OnBlameToggled — zero learning curve for avoiding circular dependencies
- Balanced model profile (opus planning, sonnet execution) reduced cost while maintaining quality
- Research agents caught the DetachContextMenu bug (nil handler restoration) before it reached execution

### What Was Inefficient
- SUMMARY.md files still lack `one_liner` frontmatter — same issue as v1.1, not fixed
- Some ROADMAP.md plan checkboxes not marked `[x]` during execution — tracking artifact persists
- TFormDXBlameSettings left compiled in BPL after Tools menu removal — dead code, should have been removed in Phase 14-02

### Patterns Established
- TComponent + FreeNotification for safe VCL panel lifecycle in OTA context
- INTAAddInOptions thin adapter with FFrame nil'd in DialogClosed
- Procedure variable callbacks for inter-unit decoupling (third instance of pattern)
- Max(X, fallback) pattern for stable visual positioning

### Key Lessons
1. Auto-advance works well for low-risk milestones with clear phase dependencies — saves significant context-switch overhead
2. FreeNotification is the correct VCL mechanism for guarding against parent destruction — simpler than custom event hooks
3. INTAAddInOptions frame lifetime is IDE-managed — never store references beyond DialogClosed
4. Removing menu items is simpler than expected when callback contracts are preserved as no-op stubs

### Cost Observations
- Model mix: balanced profile (opus planning, sonnet execution/verification)
- 6 plans across 3 phases completed in ~1 hour
- Auto-advance eliminated 5 manual /clear + paste cycles
- Notable: Phase 14-02 (Tools menu removal) took 2 minutes — deletion-only plans are fast

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 7 days | 5 | Initial milestone — established all patterns |
| v1.1 | 3 days | 6 | Mirror pattern strategy, milestone audit → gap closure cycle |
| v1.2 | 1 day | 3 | Auto-advance pipeline, balanced model profile |

### Cumulative Quality

| Milestone | Tests | Audit Score | Tech Debt Items |
|-----------|-------|-------------|-----------------|
| v1.0 | 28 | 14/14 requirements | 6 non-blocking |
| v1.1 | 28 (unchanged) | 18/18 requirements | 2 non-blocking |
| v1.2 | 28 (unchanged) | 10/10 requirements | 3 non-blocking |

### Top Lessons (Verified Across Milestones)

1. Async-first architecture prevents IDE responsiveness issues
2. Click-based UX is more reliable than hover in OTA context
3. Documentation should be verified against code, not just plan status
4. Milestone audits catch cross-phase lifecycle bugs that phase-level verification misses
5. Mirror pattern strategy (building new backend as structural clone of existing) keeps implementations consistent
6. Callback-variable pattern scales well — used 5 times now for circular dependency avoidance
7. Auto-advance pipeline is effective for low-risk milestones with clear dependencies
