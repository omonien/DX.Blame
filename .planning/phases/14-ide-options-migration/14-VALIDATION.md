---
phase: 14
slug: ide-options-migration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (not yet configured in this project) |
| **Config file** | none — no test project exists |
| **Quick run command** | `powershell -Command "& './build/DelphiBuildDPROJ.ps1' -Project './src/DX.Blame.dproj'"` |
| **Full suite command** | Build + install BPL in Delphi 13 + manual verification |
| **Estimated runtime** | ~30 seconds (build) + ~60 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Build with DelphiBuildDPROJ.ps1
- **After every plan wave:** Install BPL, verify IDE Options page and menu removal
- **Before `/gsd:verify-work`:** Full feature matrix — SETT-01+02+03
- **Max feedback latency:** 30 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | SETT-01 | manual | Build + visual: Options page appears in IDE | N/A | ⬜ pending |
| 14-01-02 | 01 | 1 | SETT-02 | manual | Build + visual: all settings present on page | N/A | ⬜ pending |
| 14-02-01 | 02 | 2 | SETT-03 | manual | Build + visual: Tools menu items removed | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*No test infrastructure to create. All verification is IDE-hosted manual testing. Build compilation serves as automated gate.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| IDE Options page appears | SETT-01 | OTA INTAAddInOptions registration | 1. Tools > Options 2. Navigate to Third Party > DX.Blame 3. Verify TFrame appears |
| All settings present | SETT-02 | Visual layout verification | 1. Open Options page 2. Verify anchor mode, statusbar, inline, VCS, all display settings present |
| Tools menu removed | SETT-03 | IDE menu structure | 1. Check Tools menu 2. Verify no DX.Blame submenu items |
| Settings persist after OK | SETT-01 | DialogClosed lifecycle | 1. Change a setting 2. Click OK 3. Reopen Options 4. Verify change persisted |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
