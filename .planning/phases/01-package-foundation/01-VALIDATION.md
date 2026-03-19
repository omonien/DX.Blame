---
phase: 1
slug: package-foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (latest, git submodule) |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj`
- **After every plan wave:** Run `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | UX-04 | build | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | UX-04 | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | UX-04 | manual-only | N/A — requires IDE interaction | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/DX.Blame.Tests.dproj` — DUnitX test project
- [ ] `tests/DX.Blame.Tests.Version.pas` — version constant tests
- [ ] `libs/DUnitX/` — git submodule
- [ ] `build/DelphiBuildDPROJ.ps1` — build script from omonien/DelphiStandards
- [ ] `res/DX.Blame.SplashIcon.bmp` — placeholder 24x24 bitmap
- [ ] `.gitignore` and `.gitattributes` — from omonien/DelphiStandards

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| BPL installs via Component > Install Packages | UX-04 | Requires running IDE | 1. Open Delphi 13. 2. Component > Install Packages. 3. Add DX.Blame.bpl. 4. Verify no errors. |
| Plugin appears in IDE splash screen | UX-04 | Visual verification at IDE start | 1. Close IDE. 2. Re-open IDE. 3. Watch splash screen for "DX.Blame" entry. |
| Plugin appears in Help > About | UX-04 | Requires running IDE | 1. Open IDE. 2. Help > About. 3. Scroll to find "DX.Blame" with icon and description. |
| BPL uninstalls without crashes | UX-04 | Requires running IDE | 1. Component > Install Packages. 2. Remove DX.Blame.bpl. 3. Verify no AV or crash. 4. Re-install to confirm clean cycle. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
