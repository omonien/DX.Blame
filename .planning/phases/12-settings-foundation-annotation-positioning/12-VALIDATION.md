---
phase: 12
slug: settings-foundation-annotation-positioning
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-26
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (project standard) |
| **Config file** | `tests/` directory — not yet created for this project |
| **Quick run command** | Visual verification in IDE (OTA renderer not unit-testable) |
| **Full suite command** | Settings round-trip: change settings, close/reopen IDE, verify restored |
| **Estimated runtime** | ~30 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Visual verification in IDE — activate caret-anchored mode, navigate through lines of varying length
- **After every plan wave:** Full settings round-trip — change both new settings, close IDE, reopen, verify settings restored
- **Before `/gsd:verify-work`:** All visual behaviors match DISP-03/04/05 success criteria
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | DISP-03 | manual | Visual: caret-anchored X position | N/A | ⬜ pending |
| 12-01-02 | 01 | 1 | DISP-04 | manual | Visual: only caret line uses caret-anchor in dsAllLines | N/A | ⬜ pending |
| 12-01-03 | 01 | 1 | DISP-03 | unit | Settings INI round-trip for AnnotationPosition | N/A | ⬜ pending |
| 12-02-01 | 02 | 1 | DISP-05 | manual | Visual: ShowInline=False suppresses annotations | N/A | ⬜ pending |
| 12-02-02 | 02 | 1 | DISP-05 | unit | Settings INI round-trip for ShowInline/ShowStatusbar | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. OTA renderer behavior is manual-only (no DUnitX mock for INTACodeEditorPaintContext). Settings persistence is testable but test project not yet created — defer to Phase 14 or later.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Caret-anchored annotation follows caret column | DISP-03 | Renderer uses OTA paint context — no mock available | 1. Enable caret-anchored in settings 2. Open file with varying line lengths 3. Move caret — annotation X should follow caret column |
| Non-caret lines stay end-of-line in dsAllLines | DISP-04 | Same OTA limitation | 1. Enable dsAllLines + caret-anchored 2. Move caret between lines 3. Only current line annotation should shift |
| ShowInline=False suppresses all inline annotations | DISP-05 | Renderer visual output | 1. Disable ShowInline in settings 2. Open blamed file 3. No inline annotations should appear |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
