---
phase: 01-package-foundation
verified: 2026-03-19T10:02:06Z
status: human_needed
score: 5/7 must-haves verified
human_verification:
  - test: "Install BPL via Component > Install Packages and confirm IDE registration"
    expected: "DX.Blame appears in the installed packages list with description 'DX.Blame - Git Blame for Delphi'. Plugin appears in splash screen on next IDE start and in Help > About with version '1.0.0.0'."
    why_human: "Requires a running Delphi 13 IDE. The Summary documents this as approved at checkpoint:human-verify but the approval is self-reported in the SUMMARY -- no independent confirmation exists in the codebase."
  - test: "Uninstall BPL via Component > Install Packages and verify clean unload"
    expected: "No crash, no access violation. 'DX Blame' disappears from Tools menu. IDE continues working normally."
    why_human: "Runtime behavior. The finalization code is correctly structured in reverse order but a subtle guard condition (> 0 instead of >= 0) could silently skip wizard or about-box cleanup if the IDE assigned index 0. Confirm no AV occurs on the first installed package to rule this out."
notes_on_guard_condition: |
  finalization uses GWizardIndex > 0 and GAboutPluginIndex > 0 as guards.
  If the IDE returns index 0 from AddWizard or AddPluginInfo (valid for the first
  registered item), cleanup is silently skipped. This does not cause a crash (the
  IDE still owns the objects) but it is a latent leak on uninstall. Recommend
  changing guards to >= 0 or <> -1. Rated as warning, not blocker.
---

# Phase 1: Package Foundation Verification Report

**Phase Goal:** Create a compilable, installable DX.Blame design-time package (BPL) that registers with the Delphi IDE -- providing splash screen entry, About dialog info, and a placeholder Tools menu -- and unloads cleanly.
**Verified:** 2026-03-19T10:02:06Z
**Status:** human_needed
**Re-verification:** No -- initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | BPL compiles successfully for Delphi 13 using DelphiBuildDPROJ.ps1 | VERIFIED | `build/Win32/Debug/DX.Blame370.bpl` exists (38,912 bytes, compiled 2026-03-19). `.dcu` files present in `src/`. |
| 2 | DPK declares designide dependency and contains Registration + Version units | VERIFIED | `src/DX.Blame.dpk` lines 34-41: `requires rtl, vcl, designide` and `contains DX.Blame.Registration, DX.Blame.Version` |
| 3 | Registration unit registers wizard, splash icon, about box entry, and Tools menu placeholder | VERIFIED | All four registrations confirmed in `src/DX.Blame.Registration.pas`: splash in initialization (line 172), wizard in Register (line 146), about box in Register (line 152), menu in Register via CreateToolsMenu (line 163) |
| 4 | Finalization removes all registrations in reverse order without leaks | PARTIAL | Reverse order confirmed (menu, wizard, about). Guard condition `GWizardIndex > 0` and `GAboutPluginIndex > 0` (lines 186, 191) will silently skip cleanup if IDE assigns index 0 to either registration. Should be `>= 0`. Not a crash risk but a latent cleanup gap. |
| 5 | Menu placeholder has two disabled items: Enable Blame and Settings... | VERIFIED | `CreateToolsMenu` (lines 109-119): two TMenuItems created with `Enabled := False`, captions 'Enable Blame' and 'Settings...' |
| 6 | Plugin appears in IDE splash screen and Help > About dialog | NEEDS HUMAN | Code paths are correct. Summary reports human checkpoint approved. Independent confirmation needed. |
| 7 | BPL installs and unloads cleanly without crashes or access violations | NEEDS HUMAN | Finalization structure is correct. Guard condition warning applies. Summary reports checkpoint approved. Independent confirmation needed. |

**Score:** 5/7 truths fully verified (2 need human confirmation)

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|---------|--------|---------|
| `src/DX.Blame.Registration.pas` | Central OTA lifecycle: wizard, splash, about, menu (min 80 lines) | VERIFIED | 195 lines. All four OTA registrations present. Full implementation, not a stub. |
| `src/DX.Blame.Version.pas` | Version constants and plugin metadata | VERIFIED | Exports all 8 required constants: `cDXBlameMajorVersion`, `cDXBlameMinorVersion`, `cDXBlameRelease`, `cDXBlameBuild`, `cDXBlameVersion`, `cDXBlameName`, `cDXBlameDescription`, `cDXBlameCopyright` |
| `src/DX.Blame.dpk` | Design-time package source referencing designide | VERIFIED | Contains `designide` in requires, `{$DESIGNONLY}`, `{$LIBSUFFIX AUTO}`, `{$DESCRIPTION 'DX.Blame - Git Blame for Delphi'}` |
| `src/DX.Blame.dproj` | Project file with correct build output paths and version info | VERIFIED | BPL output: `../build/$(Platform)/$(Config)`, DCU/DCP: `../build/$(Platform)/$(Config)/dcu`. VerInfo 1.0.0.0, CompanyName=Olaf Monien, IncludeVerInfo=true |
| `res/DX.Blame.res.rc` (planned name) | Resource script referencing DXBLAMESPLASH BITMAP | VERIFIED (name deviation) | Actual file is `res/DX.Blame.Splash.rc`. Contains `DXBLAMESPLASH BITMAP "DX.Blame.SplashIcon.bmp"`. Compiled to `res/DX.Blame.Splash.res`. DPK references compiled `.res` directly. Summary documents this as an intentional fix for RLINK32 16-bit resource error. |
| `build/DelphiBuildDPROJ.ps1` | Universal build script from omonien/DelphiStandards | VERIFIED | 10,800 bytes, present at `build/DelphiBuildDPROJ.ps1` |
| `tests/DX.Blame.Tests.dproj` | DUnitX test project | VERIFIED | Present at `tests/DX.Blame.Tests.dproj` with correct DUnitX search paths |
| `tests/DX.Blame.Tests.dpr` | DUnitX test runner program | VERIFIED | Present at `tests/DX.Blame.Tests.dpr` |
| `tests/DX.Blame.Tests.Version.pas` | Unit tests for version constants (min 20 lines) | VERIFIED | 120 lines. 10 test methods covering all version constants. `uses DX.Blame.Version` confirmed. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `src/DX.Blame.Registration.pas` | `src/DX.Blame.Version.pas` | uses clause | WIRED | Line 32: `DX.Blame.Version` in uses. Constants `cDXBlameName`, `cDXBlameDescription`, `cDXBlameCopyright`, `cDXBlameVersion` used at lines 62, 154, 158, 173. |
| `src/DX.Blame.Registration.pas` | `res/DX.Blame.Splash.res` | LoadBitmap with DXBLAMESPLASH resource | WIRED | `DXBLAMESPLASH` referenced at lines 151 and 174 via `LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH')`. Resource compiled to `.res` and referenced in DPK line 4. |
| `src/DX.Blame.dpk` | `src/DX.Blame.Registration.pas` | contains clause | WIRED | Line 40: `DX.Blame.Registration in 'DX.Blame.Registration.pas'` |
| `src/DX.Blame.dproj` | `build/` | output path configuration | WIRED | `DCC_BplOutput`, `DCC_DcuOutput`, `DCC_DcpOutput` all reference `../build/$(Platform)/$(Config)` |
| `tests/DX.Blame.Tests.Version.pas` | `src/DX.Blame.Version.pas` | uses clause | WIRED | Line 22: `DX.Blame.Version` in uses. Constants used in all 10 test methods. |
| `DX.Blame.groupproj` | `tests/DX.Blame.Tests.dproj` | project group entry | WIRED | Lines 9-10: `<Projects Include="tests\DX.Blame.Tests.dproj">`. Target `DX_Blame_Tests` defined at line 29. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| UX-04 | 01-01-PLAN, 01-02-PLAN | Plugin installed as Design-Time Package (BPL), supports Delphi 11.3+, 12 and 13 | SATISFIED (automated) / NEEDS HUMAN (Delphi 11.3 and 12 range) | BPL compiles for Delphi 13 (DX.Blame370.bpl). IDE integration verified by human checkpoint per SUMMARY. Delphi 11.3 and 12 compatibility is asserted by the SUMMARY but not independently confirmed. `{$LIBSUFFIX AUTO}` is present to support multi-version deployment. |

No orphaned requirements found. REQUIREMENTS.md traceability table maps UX-04 exclusively to Phase 1 and marks it Complete.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/DX.Blame.Registration.pas` | 186, 191 | `GWizardIndex > 0` and `GAboutPluginIndex > 0` guards in finalization | Warning | If IDE assigns index 0 to the first registration, cleanup call is silently skipped. Does not crash but leaks the registration slot on BPL uninstall. Fix: change both guards to `>= 0`. |
| `src/DX.Blame.Registration.pas` | 42 | Comment "Phase 1 placeholder -- Execute is a no-op" | Info | Accurate and intentional -- wizard Execute is a legitimate no-op for this phase. Not a stub issue. |

No TODO/FIXME/HACK markers in implementation files. No `AddProductBitmap` usage (correctly uses `AddPluginBitmap`). No `BorlandIDEServices as IOTASplashScreenServices` (correctly uses global `SplashScreenServices` with Assigned check). No empty implementations.

---

## Human Verification Required

### 1. BPL IDE Registration Confirmation

**Test:** Start Delphi 13. Install `build/Win32/Debug/DX.Blame370.bpl` via Component > Install Packages > Add. Restart IDE. Observe splash screen.
**Expected:** "DX.Blame" appears on the splash screen bitmap strip. In Help > About, "DX.Blame" entry shows "Git Blame for Delphi" description with version "1.0.0.0". Under Tools menu, "DX Blame" submenu has two greyed items: "Enable Blame" and "Settings...".
**Why human:** The SUMMARY documents a passing checkpoint:human-verify, but this verification must be independently confirmed. Cannot be verified programmatically.

### 2. Clean BPL Uninstall (with Guard Condition Awareness)

**Test:** With DX.Blame installed, go to Component > Install Packages. Select DX.Blame. Click Remove. Confirm no AV or exception dialog appears. Verify "DX Blame" is gone from Tools menu. Restart IDE and confirm no residual errors.
**Expected:** Clean uninstall. No access violations. "DX Blame" menu entry disappears.
**Why human:** The finalization guard `GWizardIndex > 0` (rather than `>= 0`) is a potential silent failure if DX.Blame is the first wizard registered. Observing a crash-free uninstall under real IDE conditions confirms or clears this concern.

### 3. Delphi 11.3 and 12 Compatibility (if applicable)

**Test:** Install `DX.Blame<suffix>.bpl` in Delphi 12 or 11.3 if available.
**Expected:** Same splash/about/menu behavior as Delphi 13. No linker errors.
**Why human:** UX-04 requires Delphi 11.3+ compatibility. REQUIREMENTS.md marks it Complete, but only Delphi 13 compilation was confirmed in the automated build. `{$LIBSUFFIX AUTO}` handles BPL naming differences but older IDE API compatibility cannot be verified without those installations.

---

## Gaps Summary

No blocking gaps found. All automated artifacts exist, are substantive, and are correctly wired. The one code-quality concern (finalization guard using `> 0` instead of `>= 0`) is a warning-level issue that will only manifest if DX.Blame is the very first OTA wizard registered in the IDE -- an unlikely but possible scenario. It should be corrected in the next plan that touches `DX.Blame.Registration.pas`.

The two remaining "needs human" truths (IDE registration visibility, clean unload) have self-reported passing evidence in the SUMMARY from the checkpoint:human-verify task. Human confirmation here is a formality to establish independent verification, not because there is reason to doubt the implementation.

---

_Verified: 2026-03-19T10:02:06Z_
_Verifier: Claude (gsd-verifier)_
