---
phase: 9
slug: mercurial-provider
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (Git submodule under /libs) |
| **Config file** | tests/ directory (project structure standard) |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk` + manual IDE test with Hg repo |
| **Estimated runtime** | ~30 seconds (compilation) |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk`
- **After every plan wave:** Full package build + manual IDE load with Mercurial repository
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | HGB-05 | unit | Test ParseHgAnnotateOutput with synthetic input | No -- Wave 0 | ⬜ pending |
| 09-02-01 | 02 | 1 | HGB-01 | integration | Manual -- requires real Hg repo | manual-only | ⬜ pending |
| 09-02-02 | 02 | 1 | HGB-02 | integration | Manual -- requires real Hg repo | manual-only | ⬜ pending |
| 09-02-03 | 02 | 1 | HGB-03 | integration | Manual -- requires real Hg repo | manual-only | ⬜ pending |
| 09-02-04 | 02 | 1 | HGB-04 | integration | Manual -- requires real Hg repo | manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Unit test for ParseHgAnnotateOutput with sample template output (synthetic strings, no hg.exe required)
- [ ] Compilation verification is the primary automated gate

*Existing infrastructure covers compilation checks. Manual testing with real Hg repo required for HGB-01 through HGB-04.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Inline blame annotations for Hg files | HGB-01 | Requires real Hg repo and IDE interaction | Open file in Hg repo, verify annotations appear with author + relative time |
| Commit detail popup via hg log | HGB-02 | Requires real Hg repo and IDE interaction | Click annotation, verify commit details (hash, author, date, message) |
| RTF diff for Hg commits | HGB-03 | Requires real Hg repo and IDE interaction | Open diff dialog, verify RTF color-coded diff output |
| Revision navigation via hg cat | HGB-04 | Requires real Hg repo and IDE interaction | Use context menu to navigate to annotated revision |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
