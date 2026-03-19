---
phase: 02
slug: blame-data-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (via git submodule in libs/DUnitX) |
| **Config file** | tests/DX.Blame.Tests.dproj |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Platform Win64 -Config Debug && build\Win64\Debug\DX.Blame.Tests.exe` |
| **Full suite command** | Same as quick run (single test project) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | BLAME-02 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | BLAME-02 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | BLAME-04 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | BLAME-04 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | BLAME-05 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 1 | BLAME-05 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-07 | 01 | 1 | BLAME-06 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 02-01-08 | 01 | 1 | BLAME-03 | integration | Manual (IDE) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/DX.Blame.Tests.Git.Discovery.pas` — stubs for BLAME-02 (git finder, repo detection)
- [ ] `tests/DX.Blame.Tests.Git.Blame.pas` — stubs for BLAME-04 (porcelain parser with sample output)
- [ ] `tests/DX.Blame.Tests.Cache.pas` — stubs for BLAME-05, BLAME-06 (cache store/get/invalidate/clear)
- [ ] Update `tests/DX.Blame.Tests.dpr` uses clause to include new test units
- [ ] Update `tests/DX.Blame.Tests.dproj` to reference new test unit files

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Async blame completes without blocking IDE | BLAME-03 | Requires running IDE with loaded BPL | 1. Load BPL in Delphi 2. Open a .pas file in a git repo 3. Verify IDE remains responsive during blame execution 4. Verify blame data appears (or check debug output) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
