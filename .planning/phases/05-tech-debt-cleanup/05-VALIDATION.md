---
phase: 5
slug: tech-debt-cleanup
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-23
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (via git submodule) |
| **Config file** | tests/DX.Blame.Tests.dproj |
| **Quick run command** | `pwsh -File build/DelphiBuildDPROJ.ps1 -DPROJPath tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe` |
| **Full suite command** | Same as quick run (single test project) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Compile test project
- **After every plan wave:** Full test suite run
- **Before `/gsd:verify-work`:** Full suite must be green + manual IDE verification of theme color
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | CONF-02 | unit + compile | `pwsh -File build/DelphiBuildDPROJ.ps1 -DPROJPath tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe --exit:summary` | yes | pending |
| 05-01-02 | 01 | 1 | CONF-02 | compile | `pwsh -File build/DelphiBuildDPROJ.ps1 -DPROJPath tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe --exit:summary` | yes | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test stubs needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DeriveAnnotationColor returns theme-blended color with INTACodeEditorServices | CONF-02 | Cannot test INTACodeEditorServices outside IDE context | 1. Open IDE with light theme 2. Enable blame 3. Verify annotations are muted gray (darker than mid-gray) 4. Switch to dark theme 5. Verify annotations adapt (lighter muted gray) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
