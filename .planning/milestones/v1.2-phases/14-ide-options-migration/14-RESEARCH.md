# Phase 14: IDE Options Migration - Research

**Researched:** 2026-03-26
**Domain:** Delphi OTA INTAAddInOptions — embedding a TFrame into Tools > Options, and removing legacy Tools menu entries
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETT-01 | Settings accessible via Tools > Options > Third Party > DX.Blame (INTAAddInOptions TFrame) | INTAAddInOptions interface documented in ToolsAPI.pas line 6640; INTAEnvironmentOptionsServices handles registration. Well-established OTA pattern. |
| SETT-02 | Options page includes all settings: anchor mode, statusbar toggle, inline toggle, VCS preference, and all existing display settings | TDXBlameSettings singleton already has all required properties; TFormDXBlameSettings.pas LoadFromSettings/SaveToSettings cover every setting; frame reuses this logic verbatim. |
| SETT-03 | Tools > DX.Blame menu items (Settings dialog, Toggle) are removed after Options page migration | CreateToolsMenu / RemoveToolsMenu in Registration.pas; GMenuParentItem and GEnableBlameItem vars; both freed in RemoveToolsMenu. The Tools menu "Enable Blame" toggle becomes redundant once the context menu toggle (NAV-01, done in Phase 13) covers that action. |
</phase_requirements>

## Summary

Phase 14 completes the v1.2 milestone by migrating DX.Blame settings from a standalone modal dialog into the standard IDE Tools > Options dialog, then removing the now-redundant Tools menu. The work involves three new Delphi units and targeted changes to Registration.pas and the package files.

The INTAAddInOptions interface has been stable since Delphi 2007 and is unchanged in Delphi 13. The pattern (TFrame + thin adapter implementing INTAAddInOptions + registration via INTAEnvironmentOptionsServices) is well-established and documented in the existing ARCHITECTURE.md research. All settings are already stored in a singleton (TDXBlameSettings) with complete INI persistence; the frame will reuse the existing LoadFromSettings/SaveToSettings logic from TFormDXBlameSettings without duplication.

The existing Tools menu carries two items: "Enable Blame" (toggle) and "Settings..." (opens modal form). After Phase 14, the Ctrl+Alt+B hotkey and the context menu toggle (both shipped in Phase 13) replace the "Enable Blame" menu item. The IDE Options page replaces the "Settings..." item. Both menu items and the GMenuParentItem container are removed by deleting the CreateToolsMenu call and freeing the GMenuHandler object. The modal TFormDXBlameSettings and its DFM remain in the package — they are not removed but will no longer be reachable from any registered menu action.

**Primary recommendation:** Create DX.Blame.Settings.Frame (TFrame with all controls), create DX.Blame.Settings.Options (INTAAddInOptions adapter), wire registration/unregistration in Registration.pas, remove Tools menu creation, and delete the "DX Blame" submenu wiring.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ToolsAPI (INTAAddInOptions) | Delphi 13 / Studio 37 | Embeds a TFrame into Tools > Options | Official OTA interface, unchanged since Delphi 2007 |
| ToolsAPI (INTAEnvironmentOptionsServices) | Delphi 13 / Studio 37 | Registers and unregisters the AddInOptions instance | Companion service, same stability guarantee |
| Vcl.Forms (TFrame) | Delphi RTL/VCL | Container for settings controls inside Options dialog | Required by INTAAddInOptions.GetFrameClass |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DX.Blame.Settings | Existing singleton | Read/write all settings from/to INI | Loaded in FrameCreated, saved in DialogClosed(True) |
| DX.Blame.Engine | Existing | OnProjectSwitch — re-detect VCS after preference change | Called in DialogClosed only when VCSPreference changed |
| DX.Blame.Renderer | Existing | InvalidateAllEditors — force repaint after settings change | Called in DialogClosed(True) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| INTAAddInOptions + TFrame | Keep standalone TFormDXBlameSettings | Standalone dialog works but is amateurish compared to GExperts / DelphiLSP. IDE integration is the right approach. |
| Remove modal form entirely | Keep modal form, just stop exposing it | The modal form keeps DX.Blame.Settings.Form.pas and its DFM in the package but unreachable. Minimal risk. Preferred for this phase — SETT-03 only requires removing the menu items, not the form unit. |

**Installation:** No new external packages. All OTA interfaces are in ToolsAPI.pas (already in requires clause).

## Architecture Patterns

### Recommended Project Structure

Three new files added to `src/`:

```
src/
├── DX.Blame.Settings.Frame.pas   (new) — TFrame with all settings controls, no OTA dependency
├── DX.Blame.Settings.Frame.dfm   (new) — frame layout derived from Settings.Form.dfm
├── DX.Blame.Settings.Options.pas (new) — INTAAddInOptions adapter, bridges IDE and TFrame
├── DX.Blame.Settings.Form.pas    (keep) — unchanged, no longer exposed via menu
├── DX.Blame.Registration.pas     (modify) — add Options registration, remove Tools menu
├── DX.Blame.dpk                  (modify) — add two new units to contains clause
└── DX.Blame.dproj                (modify) — add DCCReference entries for new units
```

### Pattern 1: INTAAddInOptions Bridge (Thin Adapter)

**What:** A minimal TInterfacedObject that implements the 8 INTAAddInOptions methods, delegating to TFrameDXBlameSettings for load, save, and validate.

**When to use:** The only correct pattern for IDE Options integration. The IDE owns the frame's lifetime; the adapter bridges the IDE's lifecycle callbacks to frame methods.

**Example:**
```pascal
// Source: ToolsAPI.pas (line 6640), verified against ARCHITECTURE.md
TDXBlameAddInOptions = class(TInterfacedObject, INTAAddInOptions)
private
  FFrame: TFrameDXBlameSettings;
public
  function GetArea: string;                         // return ''
  function GetCaption: string;                      // return 'DX Blame'
  function GetFrameClass: TCustomFrameClass;        // return TFrameDXBlameSettings
  procedure FrameCreated(AFrame: TCustomFrame);     // cast, store, LoadFromSettings
  procedure DialogClosed(Accepted: Boolean);        // if Accepted: SaveToSettings, nil FFrame
  function ValidateContents: Boolean;               // return True (simple checkboxes)
  function GetHelpContext: Integer;                 // return 0
  function IncludeInIDEInsight: Boolean;            // return True
end;
```

### Pattern 2: Frame Load/Save (Reuse Form Logic)

**What:** TFrameDXBlameSettings exposes `LoadFromSettings` and `SaveToSettings` methods that mirror TFormDXBlameSettings exactly, reading from/writing to the BlameSettings singleton.

**When to use:** In FrameCreated (load) and DialogClosed(True) (save). The frame is stateless between showings — no persistent fields beyond what the controls hold.

**Key side effects that SaveToSettings MUST replicate (from Settings.Form.pas lines 183-191):**
```pascal
// After writing settings to singleton:
LSettings.Save;
InvalidateAllEditors;
// VCS re-detection when preference changed:
if LVCSChanged then
  BlameEngine.OnProjectSwitch(LModuleServices.MainProjectGroup.ActiveProject.FileName);
```

### Pattern 3: Registration / Unregistration

**What:** Registration.pas creates and holds the INTAAddInOptions instance as a unit-level var, registers during Register(), unregisters during finalization.

**Critical ordering:** Unregister BEFORE RemoveWizard. The current finalization sequence ends:
```
6. RemoveToolsMenu
7. RemoveWizard
8. RemoveAboutBox
```

The new sequence becomes:
```
6. (RemoveToolsMenu removed — no-op, menu no longer created)
6.5. UnregisterAddInOptions  (NEW — must precede wizard removal)
7. RemoveWizard
8. RemoveAboutBox
```

**Registration code in Register():**
```pascal
// Source: ARCHITECTURE.md Pattern 3, verified against ToolsAPI.pas
var LEnvOptSvc: INTAEnvironmentOptionsServices;
if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
begin
  GAddInOptions := TDXBlameAddInOptions.Create;
  LEnvOptSvc.RegisterAddInOptions(GAddInOptions);
end;
```

**Unregistration in finalization:**
```pascal
if GAddInOptions <> nil then
begin
  var LEnvOptSvc: INTAEnvironmentOptionsServices;
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
    LEnvOptSvc.UnregisterAddInOptions(GAddInOptions);
  GAddInOptions := nil;
end;
```

### Pattern 4: Frame DFM Derivation

**What:** TFrameDXBlameSettings uses the same GroupBoxes and controls as TFormDXBlameSettings but without the ButtonOK, ButtonCancel, ColorDialog (non-visual), and the top-level TForm wrapper. All five GroupBoxes (Format, Appearance, Display, VCS, Hotkey) are preserved verbatim.

**DPI / layout guidance:** The existing form uses absolute pixel positions. Since the IDE Options dialog may apply DPI scaling differently across Delphi versions, the frame should set `ParentFont := True` on its root so it inherits the IDE's font. Anchoring (akLeft, akTop, akRight) on GroupBoxes prevents overlap at 150%+ DPI.

### Anti-Patterns to Avoid

- **Storing FFrame outside FrameCreated/DialogClosed:** The IDE destroys the frame when the Options dialog closes. Any FFrame reference beyond DialogClosed is dangling. Set `FFrame := nil` at the end of DialogClosed.
- **Returning non-empty string from GetArea:** Per ToolsAPI comments, return `''` to appear under the standard "Third Party" node. Any custom area string may produce unexpected tree placement or break across IDE versions (Pitfall 8).
- **Forgetting to call InvalidateAllEditors in DialogClosed:** The existing SaveToSettings in the form calls this. The new Options page DialogClosed must replicate it. Without this call, changed display settings (ShowInline, DisplayScope, AnnotationPosition) only take effect on the next IDE paint cycle trigger.
- **Removing TFormDXBlameSettings from the package:** SETT-03 only requires removing the Tools menu items. The modal form remains in the package. The DFM resource is compiled into the BPL regardless; keeping the unit costs nothing and preserves a fallback.
- **Creating GMenuHandler / GMenuParentItem:** The CreateToolsMenu call and all related vars (GMenuParentItem, GEnableBlameItem, GMenuHandler, TDXBlameMenuHandler class) should be removed from Registration.pas. RemoveToolsMenu becomes a no-op and can be deleted or left empty. The SyncEnableBlameCheckmark procedure should remain — it is still called by KeyBinding.pas (OnBlameToggled) and Navigation.pas (GOnContextMenuToggle); it can simply check `GEnableBlameItem <> nil` which will always be nil.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Settings page in IDE Options | Custom window injection, NTA wizard UI hacks | INTAAddInOptions + TFrame | OTA-sanctioned pattern, handles focus, tab order, OK/Cancel button disable on validation failure |
| IDE Options registration | BorlandIDEServices casting + direct tree manipulation | INTAEnvironmentOptionsServices.RegisterAddInOptions | IDE manages tree node lifecycle, cleanup, and persistence of frame position |
| Copy of settings controls | Duplicate EditMaxLength, ComboBoxDateFormat etc. in new unit | Reuse layout from Settings.Form.dfm, derive TFrameDXBlameSettings | DRY — all control names, default values, and load/save logic already correct in TFormDXBlameSettings |

**Key insight:** INTAAddInOptions is the right tool and has been for 15+ years. There is no shortcut that is more reliable.

## Common Pitfalls

### Pitfall 1: Frame Reference Becomes Dangling After DialogClosed
**What goes wrong:** Developer stores `FFrame` from FrameCreated and reads from it after DialogClosed. The IDE destroys the frame immediately after calling DialogClosed.
**Why it happens:** `FrameCreated(AFrame)` hands you a reference that looks persistent. It is not.
**How to avoid:** Set `FFrame := nil` at the very end of `DialogClosed`, after all reading is done. Never access FFrame outside these two callbacks.
**Warning signs:** AV when opening Tools > Options a second time, or when clicking OK.

### Pitfall 2: UnregisterAddInOptions Called After BorlandIDEServices Is Invalid
**What goes wrong:** UnregisterAddInOptions is placed after RemoveWizard in finalization. At that point BorlandIDEServices may already be torn down.
**How to avoid:** Insert UnregisterAddInOptions BEFORE step 7 (RemoveWizard) in the finalization sequence. Use Supports() guard.
**Warning signs:** AV during IDE shutdown or BPL unload, not during normal operation.

### Pitfall 3: GetArea Returns Non-Empty String
**What goes wrong:** Plugin appears under an unexpected tree node instead of "Third Party".
**How to avoid:** Always return `''` from GetArea. ToolsAPI.pas comments explicitly warn against non-empty values.
**Warning signs:** Settings page visible in Tools > Options but not under "Third Party" > "DX Blame".

### Pitfall 4: SaveToSettings Skips InvalidateAllEditors or OnProjectSwitch
**What goes wrong:** User changes DisplayScope or AnnotationPosition in IDE Options, clicks OK, but inline annotations do not update until the next file open/close. VCS preference change has no effect until IDE restart.
**Why it happens:** These side effects exist in TFormDXBlameSettings.SaveToSettings (lines 181, 184-191) but are easy to miss when writing the new DialogClosed.
**How to avoid:** Copy the full SaveToSettings logic including InvalidateAllEditors call and the LVCSChanged block into DialogClosed(True).

### Pitfall 5: CheckBoxShowStatusbar Wired Wrong in Frame
**What goes wrong:** The "Show in Statusbar" checkbox saves correctly to BlameSettings but the running GStatusbar instance is not updated until the next IDE restart. This is because DialogClosed only calls InvalidateAllEditors (renderer), not GStatusbar.UpdateForLine.
**How to avoid:** This is acceptable behavior for Phase 14. The statusbar will reflect the new setting on the next caret movement (GOnCaretMoved fires UpdateForLine which reads ShowStatusbar). No immediate update is needed.

### Pitfall 6: DPK and DPROJ Not Updated
**What goes wrong:** Package compiles but the new units are missing from the BPL because DX.Blame.dpk contains clause was not updated.
**How to avoid:** Add both new units to the dpk `contains` clause and to `DX.Blame.dproj` DCCReference entries. Pattern established in Phase 13-01 (DX.Blame.Statusbar added to both files).

## Code Examples

Verified patterns from existing codebase and ToolsAPI.pas:

### INTAAddInOptions GetArea and GetCaption
```pascal
// Source: ToolsAPI.pas comments (INTAAddInOptions interface)
// Return '' to appear under Third Party. Caption = tree node label.
function TDXBlameAddInOptions.GetArea: string;
begin
  Result := ''; // empty string = Third Party node
end;

function TDXBlameAddInOptions.GetCaption: string;
begin
  Result := 'DX Blame';
end;
```

### FrameCreated — populate controls from settings
```pascal
// Source: ARCHITECTURE.md Pattern 3, consistent with ToolsAPI.pas contract
procedure TDXBlameAddInOptions.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := TFrameDXBlameSettings(AFrame);
  FFrame.LoadFromSettings;
end;
```

### DialogClosed — save or discard
```pascal
// Source: ARCHITECTURE.md Pattern 3
procedure TDXBlameAddInOptions.DialogClosed(Accepted: Boolean);
begin
  if Accepted then
    FFrame.SaveToSettings; // triggers Save, InvalidateAllEditors, VCS re-detect
  FFrame := nil; // CRITICAL: IDE destroys frame after this callback
end;
```

### ValidateContents — always true for simple checkbox UI
```pascal
function TDXBlameAddInOptions.ValidateContents: Boolean;
begin
  Result := True; // MaxLength validated by UpDown (range 20-200); no other complex input
end;
```

### Registration in Register()
```pascal
// Source: Registration.pas pattern (existing wizard registration model)
var LEnvOptSvc: INTAEnvironmentOptionsServices;
GAddInOptions := TDXBlameAddInOptions.Create;
if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
  LEnvOptSvc.RegisterAddInOptions(GAddInOptions);
```

### Unregistration in finalization
```pascal
// Insert after RemoveToolsMenu removal, before RemoveWizard
if GAddInOptions <> nil then
begin
  var LEnvOptSvc: INTAEnvironmentOptionsServices;
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LEnvOptSvc) then
    LEnvOptSvc.UnregisterAddInOptions(GAddInOptions);
  GAddInOptions := nil;
end;
```

### Removing Tools Menu (what to delete from Registration.pas)
The following become dead code once CreateToolsMenu is no longer called:
- `TDXBlameMenuHandler` class (ToggleBlame, ShowSettings methods)
- `CreateToolsMenu` procedure
- `RemoveToolsMenu` procedure
- `GMenuParentItem`, `GEnableBlameItem`, `GMenuHandler` vars
- `DX.Blame.Settings.Form` in implementation uses clause (no longer called from Registration)

`SyncEnableBlameCheckmark` must remain because KeyBinding.pas and Navigation.pas reference it via callbacks. Its body simplifies to a no-op (GEnableBlameItem will be nil):
```pascal
procedure SyncEnableBlameCheckmark;
begin
  // Tools menu removed in v1.2 — no-op, kept for callback contract
end;
```

### Frame DFM skeleton (controls to include)
The TFrameDXBlameSettings DFM includes all five GroupBoxes from the form DFM:
- `GroupBoxFormat` (ShowAuthor, DateFormat, ShowSummary, MaxLength/UpDown)
- `GroupBoxAppearance` (RadioButtonAutoColor, RadioButtonCustomColor, PanelColorPreview, ButtonChooseColor, ColorDialog)
- `GroupBoxDisplay` (RadioButtonCurrentLine, RadioButtonAllLines, ComboBoxAnnotationPosition, CheckBoxShowInline, CheckBoxShowStatusbar)
- `GroupBoxVCS` (ComboBoxVCSPreference)
- `GroupBoxHotkey` (LabelHotkeyValue, LabelHotkeyInfo)

Excluded from frame DFM: `ButtonOK`, `ButtonCancel` (IDE provides these).

Frame ClientHeight = sum of GroupBox heights + spacing (~620px). The IDE Options dialog resizes to fit the frame.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Modal TForm dialog from Tools menu | TFrame in IDE Tools > Options | v1.2 Phase 14 | Professional integration, IDE-standard UX |
| Tools menu "DX Blame" submenu | Context menu toggle (Ctrl+Alt+B) + IDE Options page | v1.2 Phase 13+14 | Less menu clutter, standard access patterns |

**Deprecated/outdated after Phase 14:**
- `TDXBlameMenuHandler`: replaced by context menu toggle in Navigation.pas (already shipped in Phase 13)
- `CreateToolsMenu` / `RemoveToolsMenu`: superseded by INTAAddInOptions registration
- Direct `TFormDXBlameSettings.ShowSettings` call path from Registration.pas: no longer triggered by any menu action

## Open Questions

1. **ColorDialog in the Frame**
   - What we know: TColorDialog is a non-visual component. In TFormDXBlameSettings it is owned by the form and works correctly. In a TFrame, the ownership is similar.
   - What's unclear: Whether TColorDialog works correctly when its owner is a TFrame inside the IDE Options dialog rather than a TForm.
   - Recommendation: Place ColorDialog in the Frame DFM as a non-visual component owned by the frame. If it causes issues, create it programmatically in ButtonChooseColorClick instead.

2. **SyncEnableBlameCheckmark after Tools menu removal**
   - What we know: This procedure is assigned as a callback in both KeyBinding.pas (OnBlameToggled) and Navigation.pas (GOnContextMenuToggle). Both units reference Registration.SyncEnableBlameCheckmark.
   - What's unclear: Whether leaving SyncEnableBlameCheckmark as a no-op will cause any linter or dead-code warning in Delphi.
   - Recommendation: Keep the procedure, change the body to a comment. No compilation issue expected.

3. **Frame size in IDE Options dialog across Delphi versions**
   - What we know: Delphi 12.2+ modernized the Options dialog layout. The frame is embedded in a scroll container in some versions.
   - What's unclear: Whether our frame height (~620px) fits without scrolling on a 1080p display at 100% DPI.
   - Recommendation: Test empirically after implementation. If too tall, move GroupBoxHotkey content to a smaller label row to reduce height.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (libs/DUnitX) |
| Config file | tests/ project |
| Quick run command | `build\DelphiBuildDPROJ.ps1 -ProjectFile tests\DX.Blame.Tests.dproj` |
| Full suite command | Same — single test project |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETT-01 | IDE Options page registered under Third Party > DX Blame | manual-only | N/A — requires live IDE | N/A |
| SETT-02 | All settings appear in Options page and round-trip via INI | unit | build test project | depends on test project state |
| SETT-03 | Tools > DX.Blame menu items absent after migration | manual-only | N/A — requires live IDE | N/A |

**Note:** SETT-01 and SETT-03 require a running Delphi IDE to verify. The automated build (compilation success) is the proxy for correctness. SETT-02 settings persistence is testable via the existing TDXBlameSettings unit tests if they exist.

### Sampling Rate
- **Per task commit:** Compile via `DelphiBuildDPROJ.ps1` — zero compilation errors is the gate
- **Per wave merge:** Compile + inspect IDE at runtime
- **Phase gate:** Manually verify Tools > Options > Third Party > DX Blame page appears with all settings before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] No new test files needed — all new logic is UI wiring and INTAAddInOptions delegation. Compilation success + manual IDE verification is the validation path for this phase.

## Sources

### Primary (HIGH confidence)
- `src/DX.Blame.Settings.Form.pas` — exact LoadFromSettings/SaveToSettings logic, SaveToSettings side effects (lines 150-192)
- `src/DX.Blame.Registration.pas` — current finalization sequence, GMenuParentItem/GEnableBlameItem/GMenuHandler vars, CreateToolsMenu, SyncEnableBlameCheckmark
- `src/DX.Blame.Settings.pas` — all properties requiring settings controls in the new frame
- `src/DX.Blame.Settings.Form.dfm` — control layout to replicate in frame DFM
- `src/DX.Blame.dpk` — contains clause pattern established in Phase 13
- `.planning/research/ARCHITECTURE.md` — INTAAddInOptions bridge pattern, 8-method interface spec, registration/unregistration code patterns
- `.planning/research/PITFALLS.md` — Pitfalls 1, 2, 8, 9 directly applicable to this phase

### Secondary (MEDIUM confidence)
- `.planning/research/FEATURES.md` — IDE Options Page section (lines 123-138), implementation notes
- `ToolsAPI.pas` line 6640 (INTAAddInOptions), line 6760 (INTAEnvironmentOptionsServices) — verified in prior research
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) — practical OTA patterns including AddInOptions

### Tertiary (LOW confidence)
- None — all critical claims for this phase are verified against the existing codebase.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — INTAAddInOptions is well-documented, stable since 2007, used by GExperts and DelphiLSP
- Architecture: HIGH — exact interface methods and code patterns already researched and documented in ARCHITECTURE.md; confirmed against actual Registration.pas and Settings.Form.pas
- Pitfalls: HIGH — all pitfalls verified against actual codebase analysis (finalization order, frame lifecycle, GetArea behavior)

**Research date:** 2026-03-26
**Valid until:** 2026-06-26 (INTAAddInOptions is very stable; 90-day validity appropriate)
