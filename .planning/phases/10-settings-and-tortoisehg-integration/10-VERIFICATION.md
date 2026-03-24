---
phase: 10-settings-and-tortoisehg-integration
verified: 2026-03-24T20:00:00Z
status: human_needed
score: 11/11 must-haves verified
re_verification: false
human_verification:
  - test: "Open the settings dialog in the IDE and verify the Version Control GroupBox appears between Display and Hotkey groups"
    expected: "A 'Version Control' group containing a 'VCS Backend:' label and a combo with Auto/Git/Mercurial items is visible"
    why_human: "Cannot drive the VCL dialog without a running Delphi IDE instance"
  - test: "Select 'Git' in the VCS Backend combo, click OK, reopen settings and confirm the combo still shows 'Git'"
    expected: "Selection persists across dialog open/close cycles (reads back from settings.ini [VCS] Preference=Git)"
    why_human: "INI round-trip requires a live IDE session with %APPDATA% write access"
  - test: "Open a Mercurial project, right-click in the editor and verify 'Open in TortoiseHg Annotate' and 'Open in TortoiseHg Log' are present in the context menu"
    expected: "Two items appear below a separator after 'Show revision...', but only when TortoiseHg is installed"
    why_human: "Context menu injection requires a running IDE and a real editor popup event"
  - test: "Open a Git project, right-click in the editor and confirm the TortoiseHg items are absent"
    expected: "No TortoiseHg items appear for Git projects"
    why_human: "Provider-conditional visibility requires the IDE to have initialized the Git provider"
  - test: "Clicking 'Open in TortoiseHg Annotate' launches thg annotate with the correct arguments"
    expected: "TortoiseHg opens the annotate view for the current file; process launches fire-and-forget"
    why_human: "ShellExecute behavior requires a running IDE and a TortoiseHg installation"
---

# Phase 10: Settings and TortoiseHg Integration Verification Report

**Phase Goal:** Users can configure VCS preference and launch TortoiseHg directly from the IDE context menu
**Verified:** 2026-03-24T20:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can select Auto / Git / Mercurial as VCS preference in the settings dialog | VERIFIED | `GroupBoxVCS`, `ComboBoxVCSPreference` with 3-item list in DFM (line 161-188); published in `TFormDXBlameSettings` (Settings.Form.pas lines 55-57) |
| 2 | VCS preference is persisted to settings.ini under [VCS] section | VERIFIED | `Load` reads `LIni.ReadString('VCS', 'Preference', 'Auto')` (Settings.pas lines 169-175); `Save` writes `LIni.WriteString('VCS', 'Preference', ...)` in case block (lines 216-220) |
| 3 | VCS preference of Git or Mercurial forces that provider in DetectProvider, skipping auto-detection | VERIFIED | Case block at top of `DetectProvider` (VCS.Discovery.pas lines 180-207) creates forced provider and `Exit`s before `ScanForVCS` is called |
| 4 | VCS preference of Auto preserves existing auto-detection and dual-VCS prompt behavior | VERIFIED | `vpAuto` is the `else` branch of the case — falls through to existing `ScanForVCS` / `ResolveChoice` path (VCS.Discovery.pas line 208 comment) |
| 5 | Changing VCS preference and clicking OK triggers re-detection for the current project | VERIFIED | `LVCSChanged` comparison before save (Settings.Form.pas line 151); `BlameEngine.OnProjectSwitch` called via `IOTAModuleServices` when changed (lines 172-179) |
| 6 | User can right-click in an Hg project and see 'Open in TortoiseHg Annotate' in the context menu | VERIFIED (code) / NEEDS HUMAN (runtime) | `GThgAnnotateItem` created with caption 'Open in TortoiseHg Annotate' and wired to `OnThgAnnotateClick` in `OnEditorPopup` (Navigation.pas lines 328-332) |
| 7 | User can right-click in an Hg project and see 'Open in TortoiseHg Log' in the context menu | VERIFIED (code) / NEEDS HUMAN (runtime) | `GThgLogItem` created with caption 'Open in TortoiseHg Log' and wired to `OnThgLogClick` (Navigation.pas lines 333-336) |
| 8 | Clicking 'Open in TortoiseHg Annotate' launches thg annotate with the current file | VERIFIED (code) / NEEDS HUMAN (runtime) | `OnThgAnnotateClick` calls `LaunchThg('annotate', BlameEngine.RepoRoot, LFileName)` (Navigation.pas lines 235-250); `LaunchThg` calls `ShellExecute` with `ACommand + ' -R "..." "..."'` (lines 223-233) |
| 9 | Clicking 'Open in TortoiseHg Log' launches thg log with the current file | VERIFIED (code) / NEEDS HUMAN (runtime) | `OnThgLogClick` calls `LaunchThg('log', BlameEngine.RepoRoot, LFileName)` (Navigation.pas lines 252-267) |
| 10 | TortoiseHg menu items are NOT visible when the active provider is Git | VERIFIED (code) / NEEDS HUMAN (runtime) | Condition guards creation: `SameText(BlameEngine.Provider.GetDisplayName, 'Mercurial')` — items skipped when Git provider is active (Navigation.pas line 321) |
| 11 | TortoiseHg menu items are NOT visible when thg.exe cannot be found | VERIFIED (code) / NEEDS HUMAN (runtime) | Condition guards creation: `FindThgExecutable <> ''` (Navigation.pas line 322); `FindThgExecutable` returns `''` when `thg.exe` absent alongside `hg.exe` (Hg.Discovery.pas lines 173-183) |

**Score:** 11/11 truths verified in code

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/DX.Blame.Settings.pas` | `TDXBlameVCSPreference` enum and `VCSPreference` property on `TDXBlameSettings` | VERIFIED | Enum declared at line 34; field `FVCSPreference` at line 52; property at line 79; INI load/save at lines 169-175, 216-220 |
| `src/DX.Blame.Settings.Form.pas` | GroupBox with `ComboBoxVCSPreference` in settings dialog | VERIFIED | `GroupBoxVCS` at line 55, `ComboBoxVCSPreference` at line 57 (published); load at line 139, save at line 165 |
| `src/DX.Blame.Settings.Form.dfm` | `GroupBoxVCS` layout between Display and Hotkey groups | VERIFIED | `GroupBoxVCS` at DFM line 161, `Top=340`, between `GroupBoxDisplay` (`Top=264`) and `GroupBoxHotkey` (`Top=405`); `ClientHeight=535` |
| `src/DX.Blame.VCS.Discovery.pas` | VCS preference check at top of `DetectProvider` | VERIFIED | Case block at lines 180-207 using `BlameSettings.VCSPreference`, exits before auto-detection |
| `src/DX.Blame.Hg.Discovery.pas` | `FindThgExecutable` function deriving `thg.exe` from `hg.exe` path | VERIFIED | Function declared in interface (line 46) and implemented at lines 173-183; derives via `TPath.Combine(TPath.GetDirectoryName(LHgPath), 'thg.exe')` |
| `src/DX.Blame.Navigation.pas` | TortoiseHg Annotate and Log menu items; `OnThgAnnotateClick` | VERIFIED | `OnThgAnnotateClick` at line 235, `OnThgLogClick` at line 252, `LaunchThg` helper at line 223, `GThgAnnotateItem`/`GThgLogItem` global vars at lines 82-83, injected in `OnEditorPopup` at lines 319-337 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Settings.Form.pas` | `Settings.pas` | `LoadFromSettings` reads `VCSPreference`, `SaveToSettings` writes `VCSPreference` | WIRED | Load: `ComboBoxVCSPreference.ItemIndex := Ord(LSettings.VCSPreference)` (line 139); Save: `LSettings.VCSPreference := TDXBlameVCSPreference(ComboBoxVCSPreference.ItemIndex)` (line 165) |
| `VCS.Discovery.pas` | `Settings.pas` | `BlameSettings.VCSPreference` checked at top of `DetectProvider` | WIRED | `case BlameSettings.VCSPreference of` at line 180; `DX.Blame.Settings` in implementation uses clause (line 54) |
| `Navigation.pas` | `Hg.Discovery.pas` | `FindThgExecutable` called to get `thg.exe` path and check availability | WIRED | `FindThgExecutable` called in condition guard (line 322) and in `LaunchThg` body (line 228); `DX.Blame.Hg.Discovery` in implementation uses clause (line 63) |
| `Navigation.pas` | `Engine.pas` | `BlameEngine.Provider.GetDisplayName` checked for 'Mercurial' | WIRED | `SameText(BlameEngine.Provider.GetDisplayName, 'Mercurial')` at line 321; `DX.Blame.Engine` in implementation uses clause (line 61) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SETT-01 | 10-01-PLAN.md | User can select VCS preference (Auto/Git/Mercurial) in settings dialog | SATISFIED | `ComboBoxVCSPreference` with 3 items in DFM; `VCSPreference` property persisted to `[VCS]` INI section; forced provider in `DetectProvider` |
| SETT-02 | 10-02-PLAN.md | User can open current file in TortoiseHg Annotate via context menu | SATISFIED | `GThgAnnotateItem` with `OnThgAnnotateClick` wired to `LaunchThg('annotate', ...)` via `ShellExecute` |
| SETT-03 | 10-02-PLAN.md | User can open current file in TortoiseHg Log via context menu | SATISFIED | `GThgLogItem` with `OnThgLogClick` wired to `LaunchThg('log', ...)` via `ShellExecute` |

No orphaned requirements — all three SETT requirements appear in plan frontmatter and are covered.

### Anti-Patterns Found

None. Zero occurrences of TODO, FIXME, XXX, HACK, PLACEHOLDER, or stub patterns in any of the five modified files.

### Human Verification Required

The code implementation is complete and all wiring is correct. The following items require a running Delphi IDE to confirm runtime behavior:

#### 1. Settings Dialog Visual Layout

**Test:** Open DX.Blame Settings from the IDE Tools menu. Scroll through the dialog.
**Expected:** A "Version Control" GroupBox appears between the "Display" and "Hotkey" groups, containing a "VCS Backend:" label and a combo box showing "Auto (detect from repository)", "Git", and "Mercurial".
**Why human:** VCL dialog rendering requires a live IDE instance.

#### 2. VCS Preference INI Persistence

**Test:** Select "Git" in the VCS Backend combo, click OK. Reopen the settings dialog.
**Expected:** The combo still shows "Git". Inspect `%APPDATA%\DX.Blame\settings.ini` — a `[VCS]` section with `Preference=Git` should exist.
**Why human:** INI round-trip requires write access to `%APPDATA%` and a running IDE.

#### 3. TortoiseHg Context Menu — Mercurial Project

**Test:** Open a Mercurial project in the IDE with TortoiseHg installed. Right-click in the editor.
**Expected:** After the "Show revision..." item, a separator and then "Open in TortoiseHg Annotate" and "Open in TortoiseHg Log" appear.
**Why human:** Context menu injection requires the editor popup event to fire in a live IDE.

#### 4. TortoiseHg Context Menu — Git Project

**Test:** Open a Git project. Right-click in the editor.
**Expected:** No TortoiseHg items appear. Only the standard "Show revision..." item (plus separator) added by DX.Blame.
**Why human:** Provider-conditional visibility requires the IDE to have initialized TGitProvider.

#### 5. TortoiseHg Launch

**Test:** In a Mercurial project with TortoiseHg installed, right-click and select "Open in TortoiseHg Annotate".
**Expected:** The TortoiseHg Annotate window opens for the current file. The IDE does not freeze (fire-and-forget).
**Why human:** ShellExecute behavior and external process launch require a live environment.

### Summary

All 11 observable truths are code-verified across both plan units. All 6 artifacts exist, are substantive (not stubs), and are wired correctly. All 4 key links are confirmed active. All 3 requirements (SETT-01, SETT-02, SETT-03) are satisfied by direct code evidence. No anti-patterns or stubs were found.

The status is `human_needed` because the conditional context menu injection and ShellExecute launch are runtime behaviors that cannot be confirmed without a running Delphi IDE session. The code is correct and complete; human verification is a final smoke-test, not a gap closure.

---

_Verified: 2026-03-24T20:00:00Z_
_Verifier: Claude (gsd-verifier)_
