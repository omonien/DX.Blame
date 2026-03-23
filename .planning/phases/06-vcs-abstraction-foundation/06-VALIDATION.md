---
phase: 6
slug: vcs-abstraction-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (Git submodule under /libs) |
| **Config file** | tests/ project — not yet created for v1.1 |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.groupproj` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.groupproj` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run compilation check via build script
- **After every plan wave:** Full compilation of group project
- **Before `/gsd:verify-work`:** Full suite must compile clean
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | VCSA-02 | compile | `build script` | ✅ | ⬜ pending |
| 06-01-02 | 01 | 1 | VCSA-03 | compile | `build script` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 1 | VCSA-01 | compile | `build script` | ✅ | ⬜ pending |
| 06-02-02 | 02 | 1 | VCSA-04 | compile+manual | `build script` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. This is a pure refactoring phase — compilation success is the primary verification. No new test framework setup needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Git blame annotations appear identically after refactoring | VCSA-02, VCSA-03, VCSA-04 | Visual IDE behavior cannot be automated | Install package in Delphi IDE, open a Git-tracked .pas file, verify blame annotations appear as before |
| TGitProcess delegates to TVCSProcess with no behavioral change | VCSA-03 | Process execution behavior tested through IDE usage | Run blame on multiple files, verify output matches pre-refactoring behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
