---
phase: 13
slug: statusbar-display-navigation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (not yet configured in this project) |
| **Config file** | none — no test project exists |
| **Quick run command** | `powershell -Command "& './build/DelphiBuildDPROJ.ps1' -Project './src/DX.Blame.dproj'"` |
| **Full suite command** | Build + install BPL in Delphi 13 + manual smoke test |
| **Estimated runtime** | ~30 seconds (build) + ~60 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Build with DelphiBuildDPROJ.ps1
- **After every plan wave:** Install BPL, exercise all features in the wave
- **Before `/gsd:verify-work`:** Full feature matrix — DISP-01+02, NAV-01+02
- **Max feedback latency:** 30 seconds (build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | DISP-01 | manual | Build + visual: statusbar updates on cursor move | N/A | ⬜ pending |
| 13-01-02 | 01 | 1 | DISP-02 | manual | Build + visual: statusbar click opens popup | N/A | ⬜ pending |
| 13-02-01 | 02 | 1 | NAV-01 | manual | Build + visual: context menu toggle with checkmark | N/A | ⬜ pending |
| 13-02-02 | 02 | 1 | NAV-02 | manual | Build + visual: revision nav scrolls to line | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*No test infrastructure to create. All verification is IDE-hosted manual testing. Build compilation serves as automated gate.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Statusbar updates on cursor movement | DISP-01 | OTA editor events, live IDE required | 1. Open blamed file 2. Move cursor between lines 3. Verify statusbar shows author + time + summary |
| Statusbar click opens popup | DISP-02 | Mouse interaction with IDE statusbar | 1. Click statusbar blame panel 2. Verify commit popup appears |
| Context menu toggle with checkmark | NAV-01 | OTA editor popup menu | 1. Right-click in editor 2. Verify "Enable/Disable Blame (Ctrl+Alt+B)" with correct checkmark |
| Revision nav scrolls to source line | NAV-02 | Editor view positioning | 1. Right-click annotation 2. Navigate to revision 3. Verify editor scrolls to source line |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
