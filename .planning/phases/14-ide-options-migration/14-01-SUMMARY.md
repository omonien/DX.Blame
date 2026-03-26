---
phase: 14-ide-options-migration
plan: "01"
subsystem: settings-ui
tags: [ide-integration, ota, settings, options-dialog, tframe]
dependency_graph:
  requires: []
  provides: [DX.Blame.Settings.Frame, DX.Blame.Settings.Options, INTAAddInOptions-registration]
  affects: [DX.Blame.Registration, DX.Blame.dpk, DX.Blame.dproj]
tech_stack:
  added: [INTAAddInOptions, INTAEnvironmentOptionsServices, TFrame]
  patterns: [INTAAddInOptions-bridge, frame-load-save-delegation, reverse-order-finalization]
key_files:
  created:
    - src/DX.Blame.Settings.Frame.pas
    - src/DX.Blame.Settings.Frame.dfm
    - src/DX.Blame.Settings.Options.pas
  modified:
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.dpk
    - src/DX.Blame.dproj
decisions:
  - "FFrame niled in DialogClosed — IDE destroys frame immediately after callback (Pitfall 1)"
  - "GAddInOptions typed as INTAAddInOptions interface (not class) so ref-counting keeps instance alive"
  - "GetArea returns empty string to place node under standard Third Party tree (Pitfall 3)"
  - "UnregisterAddInOptions inserted at step 6.5 in finalization, before RemoveWizard (Pitfall 2)"
  - "Win64 build used for CI verification — Win32 BPL locked by running IDE is expected in dev environment"
metrics:
  duration: "5 min"
  completed: "2026-03-26"
  tasks_completed: 2
  files_modified: 6
---

# Phase 14 Plan 01: IDE Options Migration — Frame and Adapter Summary

**One-liner:** INTAAddInOptions adapter with TFrameDXBlameSettings embedding all DX.Blame settings under Tools > Options > Third Party > DX Blame.

## What Was Built

Created the two units and one DFM needed to register DX.Blame settings in the IDE Tools > Options dialog, and wired registration/unregistration into the plugin lifecycle.

**DX.Blame.Settings.Frame (new):**
- TFrame with all 5 GroupBoxes: Format, Appearance, Display, VCS, Hotkey
- Control names identical to TFormDXBlameSettings for consistency
- `LoadFromSettings` reads from `BlameSettings` singleton; populates all controls
- `SaveToSettings` writes all controls back, calls `LSettings.Save`, `InvalidateAllEditors`, and triggers `BlameEngine.OnProjectSwitch` when VCS preference changed
- `Anchors = [akLeft, akTop, akRight]` on all GroupBoxes for DPI-safe resizing
- `ParentFont = True` on frame root to inherit IDE font

**DX.Blame.Settings.Options (new):**
- `TDXBlameAddInOptions` implementing all 8 `INTAAddInOptions` methods
- `GetArea` returns `''` (Third Party node placement)
- `GetCaption` returns `'DX Blame'`
- `FrameCreated` casts, stores `FFrame`, calls `LoadFromSettings`
- `DialogClosed(True)` calls `SaveToSettings`; always nils `FFrame`
- `IncludeInIDEInsight` returns `True` for IDE Insight search coverage

**DX.Blame.Registration (modified):**
- Added `GAddInOptions: INTAAddInOptions = nil` unit-level var
- Registration in `Register()` after `CreateToolsMenu`: creates `TDXBlameAddInOptions`, calls `RegisterAddInOptions`
- Unregistration at finalization step 6.5, before `RemoveWizard` (Pitfall 2 ordering)

**Package files (modified):**
- `DX.Blame.dpk`: two new entries before `DX.Blame.Settings.Form` line
- `DX.Blame.dproj`: `DCCReference` entries with `<Form>` and `<DesignClass>TFrame</DesignClass>` for frame

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| FFrame niled at end of DialogClosed | IDE destroys TFrame immediately after DialogClosed returns — any retained reference is dangling (Pitfall 1) |
| GAddInOptions typed as INTAAddInOptions | Interface type ensures ref-counting keeps the adapter alive between IDE open/close of Options dialog |
| GetArea returns empty string | ToolsAPI.pas comments specify '' = Third Party node; non-empty strings may produce wrong tree placement across IDE versions (Pitfall 3) |
| UnregisterAddInOptions before RemoveWizard | BorlandIDEServices may be partially torn down after RemoveWizard; unregistering first is safe (Pitfall 2) |
| Win64 build as CI proxy | Win32 BPL is locked by the running IDE during development; Win64 compile verifies code correctness equivalently |

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

| Check | Result |
|-------|--------|
| Frame.pas has LoadFromSettings and SaveToSettings | PASS |
| Frame.dfm has 5 GroupBoxes (Format, Appearance, Display, VCS, Hotkey) | PASS |
| Frame.dfm has no ButtonOK or ButtonCancel | PASS |
| Options.pas implements all 8 INTAAddInOptions methods | PASS |
| GetArea returns empty string | PASS |
| GetCaption returns 'DX Blame' | PASS |
| FFrame set to nil in DialogClosed | PASS |
| UnregisterAddInOptions before RemoveWizard in finalization | PASS |
| Package compiles with 0 errors (Win64) | PASS |

## Self-Check: PASSED

All created files exist and commits are present:
- `f198d95` — feat(14-01): create TFrameDXBlameSettings and TDXBlameAddInOptions
- `f233709` — feat(14-01): register AddInOptions and update package files
