# Phase 13: Statusbar Display & Navigation - Research

**Researched:** 2026-03-26
**Domain:** Delphi OTA plugin — statusbar panel lifecycle, editor context menu, revision navigation scroll
**Confidence:** HIGH (all APIs verified against existing codebase; OTA patterns confirmed from v1.0/v1.1 implementation)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISP-01 | Statusbar shows current line's blame info (author, relative time, summary) updating on cursor movement | INTAEditWindow.StatusBar panel injection; EditorSetCaretPos piggyback; FormatBlameAnnotation + Cache.TryGet data pipeline |
| DISP-02 | Clicking statusbar blame panel opens commit detail popup | Panel OnClick handler; GPopup.ShowForCommit reuse; screen coordinate derivation from TStatusBar.ClientToScreen |
| NAV-01 | Editor context menu has "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark | Extend existing OnEditorPopup in Navigation.pas; BlameSettings.Enabled toggle; re-create items each popup per existing pattern |
| NAV-02 | Navigating to historical revision scrolls editor to and centers the originating source line | NavigateToRevision signature extension; IOTAModuleServices.FindModule + IOTAEditView.SetCursorPos + Center after OpenFile |
</phase_requirements>

---

## Summary

Phase 13 delivers four discrete features across two units (Navigation.pas modification, new DX.Blame.Statusbar unit) plus Registration.pas wiring. No new VCS, Engine, or Cache work is required — all four features consume existing infrastructure.

**NAV-01 and NAV-02** are low-risk extensions to `DX.Blame.Navigation.pas`. The context menu toggle follows the exact pattern already used for "Show revision..." — remove items, recreate fresh on each popup. The auto-scroll adds one parameter to `NavigateToRevision` and a three-line OTA call after `OpenFile`.

**DISP-01 and DISP-02** require a new `DX.Blame.Statusbar` unit. The core challenge is panel lifecycle: the status bar belongs to the active edit window form, and that form can be created and destroyed as the user opens/closes editor windows. The known concern from STATE.md ("Panel lifecycle across editor window create/destroy needs empirical validation") is real and must be handled via `FreeNotification` tracking rather than assuming the panel persists.

**Primary recommendation:** Implement NAV-01 and NAV-02 first (low risk, high immediate value), then DISP-01 and DISP-02 (medium risk due to panel lifecycle). Wire everything in Registration.pas last.

---

## Standard Stack

### Core OTA Interfaces Used

| Interface | Purpose | Where Accessed |
|-----------|---------|----------------|
| `INTAEditWindow.StatusBar` | Returns `TStatusBar` for the active editor window | `(BorlandIDEServices as INTAEditorServices).TopEditWindow.StatusBar` |
| `INTAEditorServices.TopEditWindow` | Current active editor window | Registration and Statusbar unit |
| `IOTAEditorServices.TopView` | Current active edit view (cursor position) | Navigation.pas, new Statusbar unit |
| `IOTAEditView.SetCursorPos` | Position cursor in editor programmatically | NavigateToRevision after OpenFile |
| `IOTAEditView140.Center(Row, Col)` | Scroll editor so row is centered | NavigateToRevision after OpenFile |
| `IOTAModuleServices.FindModule` | Get the module after OpenFile | NavigateToRevision timing fix |
| `INTACodeEditorEvents370.EditorSetCaretPos` | Fires on every cursor movement | TDXBlameRenderer already implements this |

### Supporting VCL Components

| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| `TStatusBar.Panels.Add` | VCL standard | Add custom blame panel at end of existing panels | Always append, never insert |
| `TStatusPanel` | VCL standard | The actual panel object; set `Text`, `Width`, `Style = psText` | Store panel index for cleanup |
| `TComponent.FreeNotification` | VCL standard | Detect edit window form destruction before finalization | Prevents dangling panel reference |

### No New External Dependencies

Phase 13 uses only existing project dependencies: `ToolsAPI`, `Vcl.*`, `DX.Blame.*` units already in the package.

**No installation required.** All dependencies are already in `DX.Blame.dpk`.

---

## Architecture Patterns

### Recommended Project Structure (new unit)

```
src/
├── DX.Blame.Statusbar.pas    # New unit: panel lifecycle + caret update handler
```

One new unit. Three modified units: `DX.Blame.Navigation.pas`, `DX.Blame.Registration.pas`, `DX.Blame.Settings.pas`.

### Pattern 1: Statusbar Panel Lifecycle (FreeNotification)

**What:** The blame panel is added to the editor window's TStatusBar. If the IDE destroys the edit window (user closes the window group), the TStatusBar is freed. The plugin must track this to avoid AV on cleanup.

**When to use:** Any time the plugin injects a component into a form it does not own.

**Implementation approach:**

```pascal
// DX.Blame.Statusbar.pas
type
  TDXBlameStatusbar = class(TComponent)
  private
    FPanel: TStatusPanel;
    FStatusBar: TStatusBar;
    FPanelIndex: Integer;
    FLineInfo: TBlameLineInfo;
    FHasBlameData: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AttachToStatusBar(AStatusBar: TStatusBar);
    procedure DetachFromStatusBar;
    procedure UpdateForLine(const AFileName: string; ALine: Integer);
    procedure HandlePanelClick;
  end;

procedure TDXBlameStatusbar.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited;
  // Called when FStatusBar is destroyed (because we called FreeNotification)
  if (Operation = opRemove) and (AComponent = FStatusBar) then
  begin
    FPanel := nil;       // panel is gone with the statusbar
    FStatusBar := nil;   // nil the reference — do NOT free, not owned
    FPanelIndex := -1;
  end;
end;

procedure TDXBlameStatusbar.AttachToStatusBar(AStatusBar: TStatusBar);
begin
  if FStatusBar <> nil then
    DetachFromStatusBar;

  FStatusBar := AStatusBar;
  // Subscribe to destruction notification
  AStatusBar.FreeNotification(Self);

  FPanel := FStatusBar.Panels.Add;
  FPanel.Width := 300;
  FPanel.Style := psText;
  FPanel.Text := '';
  FPanelIndex := FPanel.Index;
end;

procedure TDXBlameStatusbar.DetachFromStatusBar;
begin
  if (FStatusBar <> nil) and (FPanelIndex >= 0) and
     (FPanelIndex < FStatusBar.Panels.Count) then
    FStatusBar.Panels.Delete(FPanelIndex);
  FPanel := nil;
  FPanelIndex := -1;
  if FStatusBar <> nil then
  begin
    FStatusBar.RemoveFreeNotification(Self);
    FStatusBar := nil;
  end;
end;
```

**Note on TComponent owner:** `TDXBlameStatusbar` should be created with `nil` owner and freed explicitly during finalization. Using `TComponent` as base class (not `TObject`) is required for `FreeNotification` to work — it is a VCL mechanism that only applies to `TComponent` descendants.

### Pattern 2: Piggybacking on EditorSetCaretPos

**What:** The renderer already implements `EditorSetCaretPos` in `TDXBlameRenderer`. That fires on every cursor movement. The statusbar update should hook the same event rather than registering a duplicate notifier.

**Problem:** Direct coupling between Renderer and Statusbar would create a circular unit dependency (`DX.Blame.Renderer` using `DX.Blame.Statusbar`).

**Solution:** Use a callback/procedure variable in Registration.pas:

```pascal
// In DX.Blame.Renderer.pas — add a procedure variable:
var
  GOnCaretMoved: procedure(const AFileName: string; ALine: Integer) = nil;

// In EditorSetCaretPos, after FCurrentEditor := Editor:
if Assigned(GOnCaretMoved) and (FCurrentFileName <> '') then
  GOnCaretMoved(FCurrentFileName, FCurrentLine);
```

```pascal
// In DX.Blame.Registration.pas — wire it up:
DX.Blame.Renderer.GOnCaretMoved := GStatusbar.UpdateForLine;
```

This matches the existing `DX.Blame.KeyBinding.OnBlameToggled` callback pattern already in the codebase (line 281 of Registration.pas).

**Alternative — EditorViewActivated via separate notifier:** Would require a full `INTAEditServicesNotifier` registration for what is essentially a single callback. The piggyback approach is simpler and consistent with existing codebase patterns.

### Pattern 3: Context Menu Toggle Item (NAV-01)

**What:** Add "Enable Blame" toggle before the existing "Show revision..." item in `OnEditorPopup`.

**When to use:** Adding any new item to the editor popup. The existing remove-and-recreate pattern already handles stale state.

**Code pattern (in `TNavigationMenuHandler.OnEditorPopup`):**

```pascal
// Add BEFORE the existing GSeparatorItem creation:
var
  GEnableBlameItem: TMenuItem;  // new global alongside existing items

// Inside OnEditorPopup, at the top after RemoveOurItems:
GEnableBlameItem := TMenuItem.Create(nil);
GEnableBlameItem.Caption := 'Enable Blame'#9'Ctrl+Alt+B';
GEnableBlameItem.Checked := BlameSettings.Enabled;
GEnableBlameItem.OnClick := Self.OnToggleBlameClick;
TPopupMenu(Sender).Items.Add(GEnableBlameItem);
```

Add `GEnableBlameItem` to the `var` block alongside `GContextMenuItem` etc., and add `FreeAndNil(GEnableBlameItem)` to `RemoveOurItems` (before the existing frees, since it was added first).

The `#9` tab character in the caption is the Delphi convention for right-aligned shortcut hint in menu items.

**`OnToggleBlameClick` handler:**

```pascal
procedure TNavigationMenuHandler.OnToggleBlameClick(Sender: TObject);
begin
  BlameSettings.Enabled := not BlameSettings.Enabled;
  BlameSettings.Save;
  SyncEnableBlameCheckmark;   // syncs Tools > DX Blame > Enable Blame checkmark
  InvalidateAllEditors;
end;
```

`SyncEnableBlameCheckmark` is already exported from `DX.Blame.Registration` and imported in the `uses` clause of Navigation.pas (it is already in the implementation uses). Verify the circular dependency: Navigation.pas uses Registration.pas for `SyncEnableBlameCheckmark`. Registration.pas uses Navigation.pas for `AttachContextMenu`/`DetachContextMenu`. This is a mutual dependency — resolve by moving `SyncEnableBlameCheckmark` to a thin callback variable (same pattern as `OnBlameToggled` in KeyBinding), OR by placing the toggle logic inline and calling `InvalidateAllEditors` directly (which Navigation.pas already has via its `uses DX.Blame.Renderer` dependency). Check current `uses` — Navigation.pas already uses `DX.Blame.Settings` and `DX.Blame.Renderer` (`InvalidateAllEditors`). The circular dependency issue exists already with `SyncEnableBlameCheckmark` — see existing `DX.Blame.KeyBinding.OnBlameToggled := SyncEnableBlameCheckmark` pattern in Registration.pas line 281. Use the same pattern: add `var GOnBlameToggled: TNotifyEvent = nil` to Navigation.pas (or reuse the existing one from KeyBinding), wired in Registration.pas.

**Simplest resolution:** Navigation.pas should NOT import Registration.pas. Instead, export `GOnToggle: TNotifyEvent` from Navigation.pas (like KeyBinding does), and wire it in Registration.pas to call `SyncEnableBlameCheckmark`.

### Pattern 4: Auto-Scroll After OpenFile (NAV-02)

**What:** Extend `NavigateToRevision` to scroll the opened temp file to the source line.

**Current signature (Navigation.pas line 27):**

```pascal
procedure NavigateToRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string);
```

**New signature:**

```pascal
procedure NavigateToRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string;
  ALineNumber: Integer = 0);
```

**Scroll implementation (after `LActionServices.OpenFile(LTempFile)` at line 162):**

```pascal
if ALineNumber > 0 then
begin
  LModuleServices := BorlandIDEServices as IOTAModuleServices;
  LModule := LModuleServices.FindModule(LTempFile);
  if LModule <> nil then
  begin
    for i := 0 to LModule.GetModuleFileCount - 1 do
    begin
      if Supports(LModule.GetModuleFileEditor(i), IOTASourceEditor, LSourceEditor) then
      begin
        LSourceEditor.Show;
        LEditView := (BorlandIDEServices as IOTAEditorServices).TopView;
        if LEditView <> nil then
        begin
          LEditPos.Col := 1;
          LEditPos.Line := ALineNumber;
          LEditView.SetCursorPos(LEditPos);
          LEditView.Center(ALineNumber, 1);
          LEditView.Paint;
        end;
        Break;
      end;
    end;
  end;
end;
```

**Caller change in `OnRevisionClick`** (line 216):

```pascal
NavigateToRevision(LFileName, LLineInfo.CommitHash, BlameEngine.RepoRoot,
  LLineInfo.FinalLine);
```

`LLineInfo.FinalLine` is the logical line number from the blame data — this is exactly what the user right-clicked on, so it is correct as the scroll target.

**Timer fallback for async OpenFile:** If `FindModule` returns nil (file not yet indexed by the IDE), use a one-shot `TTimer` (50ms interval, fires once, frees itself). This matches the engine debounce pattern already in the codebase. The timer stores the target line in a closure or global variable.

### Anti-Patterns to Avoid

- **Polling status bar:** Do not use TTimer to check cursor position. Use the caret-moved callback.
- **Panel at specific index:** Always `Panels.Add` (append), never `Panels.Insert`. Store the returned panel reference, not a hardcoded index.
- **Storing frame reference after DialogClosed:** Not applicable to this phase, but noted for consistency.
- **Restoring DetachContextMenu with `Assigned(GOriginalOnPopup)` guard:** The existing `DetachContextMenu` only restores `OnPopup` when `GOriginalOnPopup` is assigned (line 397 of Navigation.pas). This is correct — do not change this behavior.
- **Registering a duplicate INTAEditServicesNotifier:** The renderer already responds to caret movement. A second notifier is wasteful and adds lifecycle complexity. Use the callback variable pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Statusbar text formatting | Custom formatter | `FormatBlameAnnotation` in DX.Blame.Formatter | Already handles ShowAuthor, DateFormat, ShowSummary, MaxLength, truncation with ellipsis |
| Edit window destruction tracking | Polling / try-except | `TComponent.FreeNotification` | VCL mechanism designed for exactly this purpose |
| Blame data lookup | Direct cache access | `BlameEngine.Cache.TryGet` | Existing O(1) dictionary lookup with nil-safety |
| Popup display | New popup form | `GPopup.ShowForCommit` | Existing `TDXBlamePopup` already handles async commit detail loading |
| Relative time formatting | Custom date math | `FormatRelativeTime` in DX.Blame.Formatter | Already handles years/months/days/hours/minutes |
| Toggle callback wiring | Circular unit dependencies | Procedure variable pattern (like `KeyBinding.OnBlameToggled`) | Already established pattern in this codebase |

**Key insight:** Every piece of data and formatting logic already exists. Phase 13 is pure wiring and lifecycle management — no new algorithms.

---

## Common Pitfalls

### Pitfall 1: Panel Survives Editor Window Destruction
**What goes wrong:** The plugin stores a `TStatusPanel` reference. The IDE destroys the edit window form (and with it the `TStatusBar` and all panels). The next cursor movement tries to write to `FPanel.Text` and causes an AV.
**Why it happens:** Edit windows are independent forms. `TopEditWindow` only returns the currently active one. When it closes, its contents are freed.
**How to avoid:** Use `TComponent.FreeNotification` as shown in Pattern 1. Nil both `FPanel` and `FStatusBar` in the `Notification` callback.
**Warning signs:** AV when closing and reopening the editor window.

### Pitfall 2: Circular Unit Dependency via SyncEnableBlameCheckmark
**What goes wrong:** `OnToggleBlameClick` in Navigation.pas calls `SyncEnableBlameCheckmark` from Registration.pas. Registration.pas already uses Navigation.pas for `AttachContextMenu`. This creates a circular dependency that will not compile.
**Why it happens:** Both units need each other. The existing solution for this exact pattern (KeyBinding needing to sync the menu) is the procedure variable `OnBlameToggled` in `DX.Blame.KeyBinding`.
**How to avoid:** Add `var GOnContextMenuToggle: TNotifyEvent = nil` to Navigation.pas. Wire it in Registration.pas's `Register` procedure: `DX.Blame.Navigation.GOnContextMenuToggle := SyncEnableBlameCheckmark`. Call it from `OnToggleBlameClick`.
**Warning signs:** Compiler error "circular unit reference."

### Pitfall 3: DetachContextMenu Bug with nil GOriginalOnPopup
**What goes wrong:** If `GOriginalOnPopup` was nil when `AttachContextMenu` ran (the IDE's `EditorLocalMenu.OnPopup` was not set), `DetachContextMenu` never restores it — but still leaves `GMenuHandler.OnEditorPopup` assigned. After detach, the editor still fires the plugin's handler.
**Root cause:** Line 397 of Navigation.pas: `if (GHookedPopup <> nil) and Assigned(GOriginalOnPopup) then`. When `GOriginalOnPopup` is nil, the guard prevents restoration.
**How to avoid:** Change to always assign: `GHookedPopup.OnPopup := GOriginalOnPopup` regardless of whether it is assigned. Setting OnPopup to nil is equivalent to "no handler" and is correct.
**Warning signs:** After unloading the package, right-clicking in editor still shows DX Blame items.

### Pitfall 4: Auto-Scroll on Asynchronous OpenFile
**What goes wrong:** `IOTAActionServices.OpenFile` is called. The plugin immediately calls `IOTAEditorServices.TopView.SetCursorPos` but `TopView` still points to the PREVIOUS file (the one the user right-clicked from). The cursor is set in the wrong file.
**Why it happens:** `OpenFile` may open the file asynchronously in some IDE states. Even when synchronous, `TopView` may not have switched yet.
**How to avoid:** After `OpenFile`, call `IOTAModuleServices.FindModule(LTempFile)` to confirm the file is loaded. If nil, use a one-shot TTimer. Then iterate the module's editors to find the source editor, call `Show`, then use `TopView`.
**Warning signs:** The temp file opens at line 1 regardless of which line was right-clicked.

### Pitfall 5: Statusbar Panel Click Coordinate
**What goes wrong:** The popup `ShowForCommit` requires a screen position. The click handler for a `TStatusPanel` receives no position parameter. Getting the wrong coordinates places the popup in the wrong location.
**How to avoid:** In the panel click handler (implemented as `TStatusBar.OnClick` or by subclassing), use `TStatusBar.ClientToScreen(TPoint.Create(FPanel.Left, 0))` to get the screen position of the panel's left edge, then use `Point(x, TStatusBar.ClientToScreen(TPoint.Zero).Y)` for vertical alignment above the statusbar.
**Warning signs:** Popup appears in the top-left corner of the screen or at 0,0.

### Pitfall 6: ShowStatusbar Not Yet in Settings
**What goes wrong:** Phase 12 added `ShowInline`. Phase 13 needs `ShowStatusbar`. If the planner forgets to add this setting first, the statusbar unit has no way to respect the user's preference.
**How to avoid:** First task of the statusbar plan: add `FShowStatusbar: Boolean` and `ShowStatusbar` property to `TDXBlameSettings` with INI persistence in `[Display]` section, default `False`.
**Warning signs:** Statusbar appears even when user disabled it in settings.

---

## Code Examples

Verified patterns from existing codebase:

### Current EditorSetCaretPos (Renderer.pas line 170-178)
```pascal
// Source: src/DX.Blame.Renderer.pas lines 170-178
procedure TDXBlameRenderer.EditorSetCaretPos(const Editor: TWinControl;
  X, Y: Integer);
begin
  FCurrentEditor := Editor;
  InvalidateAllEditors;
end;
```
**For Phase 13:** Add `GOnCaretMoved` call here with `FCurrentFileName` and `FCurrentLine`.

### OnBlameToggled Callback Pattern (KeyBinding pattern, Registration.pas line 281)
```pascal
// Source: src/DX.Blame.Registration.pas line 281
DX.Blame.KeyBinding.OnBlameToggled := SyncEnableBlameCheckmark;
```
Phase 13 NAV-01 uses an identical pattern for `GOnContextMenuToggle`.

### Existing Context Menu Item Injection Pattern (Navigation.pas lines 309-317)
```pascal
// Source: src/DX.Blame.Navigation.pas lines 309-317
GSeparatorItem := TMenuItem.Create(nil);
GSeparatorItem.Caption := '-';
TPopupMenu(Sender).Items.Add(GSeparatorItem);

GContextMenuItem := TMenuItem.Create(nil);
GContextMenuItem.Caption := LCaption;
GContextMenuItem.Enabled := LAvailable;
GContextMenuItem.OnClick := Self.OnRevisionClick;
TPopupMenu(Sender).Items.Add(GContextMenuItem);
```
NAV-01 adds `GEnableBlameItem` before `GSeparatorItem` in this same block.

### Existing NavigateToRevision OpenFile Call (Navigation.pas lines 160-162)
```pascal
// Source: src/DX.Blame.Navigation.pas lines 160-162
if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
  LActionServices.OpenFile(LTempFile);
```
NAV-02 extends this with `FindModule` + `SetCursorPos` + `Center` immediately after.

### Existing Finalization Cleanup Order (Registration.pas lines 304-332)
```
1. DetachContextMenu
2. UnregisterKeyBinding
3. CleanupPopup
4. UnregisterRenderer
5. UnregisterIDENotifiers
6. RemoveToolsMenu
7. RemoveWizard
8. RemoveAboutBox
```
Phase 13 inserts statusbar cleanup at step 3.5 (after CleanupPopup, before UnregisterRenderer):
```
3.5. CleanupStatusbar (DetachFromStatusBar + FreeAndNil)
```

### ShowForCommit Signature (Popup.pas line 74-75)
```pascal
// Source: src/DX.Blame.Popup.pas lines 74-75
procedure ShowForCommit(const ALineInfo: TBlameLineInfo;
  const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);
```
DISP-02: statusbar click calls this with current line info and panel screen coordinates.

---

## State of the Art

| Old Pattern | Phase 13 Pattern | Reason |
|-------------|------------------|--------|
| Single edit window assumption | FreeNotification per-window tracking | Pitfall 4 (multi-window) is out of scope for v1.2 per research notes, but FreeNotification must still guard the single-window case |
| Direct Settings calls only in Renderer | GOnCaretMoved callback for cross-unit notification | Avoids circular dependency Renderer <-> Statusbar |
| `NavigateToRevision` with no line param | Optional `ALineNumber: Integer = 0` default | Backward compatible — existing callers need no change until they want auto-scroll |

**Deprecated patterns for this phase:**
- Accessing `TopEditWindow` and assuming it persists indefinitely — must guard with nil checks at every access point.

---

## Open Questions

1. **Does `IOTAActionServices.OpenFile` return synchronously in Delphi 13?**
   - What we know: GExperts documentation says it is synchronous in most cases; Pitfall 5 (auto-scroll timing) in PITFALLS.md identifies it as a potential race in some IDE versions.
   - What's unclear: Whether Delphi 13 specifically guarantees synchronous return.
   - Recommendation: Implement the `FindModule` check with TTimer fallback. If `FindModule` returns non-nil immediately in practice, the timer never fires. Zero cost for the common case.

2. **Multiple edit windows: should Phase 13 support them?**
   - What we know: PITFALLS.md Pitfall 4 documents that `TopEditWindow` returns only one window. The ARCHITECTURE.md notes this as a known limitation for v1.2.
   - What's unclear: Whether the user's environment typically uses multiple edit windows.
   - Recommendation: Scope Phase 13 to the single active edit window. Use `FreeNotification` to guard against destruction, but do not build multi-window panel management (that is a future scope item). Document the limitation.

3. **`TStatusPanel` click detection mechanism**
   - What we know: `TStatusBar.OnClick` fires when ANY panel is clicked. `TStatusBar.GetPanelAt(X, Y)` is not a standard method — panel hit testing must be done manually by iterating `Panels[i].Left/Width` against the click X coordinate. Alternatively, the `TStatusBar.OnMouseDown` event provides coordinates.
   - Recommendation: Use `TStatusBar.OnMouseDown` handler assigned during `AttachToStatusBar`. Check which panel was clicked by comparing X against panel widths.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (not yet configured in this project) |
| Config file | none — no test project exists |
| Quick run command | n/a — no automated tests in this project |
| Full suite command | n/a |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DISP-01 | Statusbar updates on cursor movement | manual-only | n/a | n/a |
| DISP-02 | Statusbar click opens commit popup | manual-only | n/a | n/a |
| NAV-01 | Context menu shows toggle with correct checkmark | manual-only | n/a | n/a |
| NAV-02 | Navigate to revision scrolls to source line | manual-only | n/a | n/a |

**Manual-only justification:** All four requirements depend on the live Delphi IDE environment (OTA events, editor windows, status bars). There is no existing test infrastructure in this project and OTA interactions cannot be unit-tested without full IDE hosting. Verification is performed by building and installing the BPL in the IDE.

### Sampling Rate
- **Per task:** Build with `DelphiBuildDPROJ.ps1`, install BPL in Delphi 13, smoke-test the specific feature.
- **Per wave merge:** Full feature matrix test: DISP-01+02, NAV-01+02 all exercised.
- **Phase gate:** All four requirements pass manual verification before `/gsd:verify-work`.

### Wave 0 Gaps
None — no test infrastructure to create. Verification is IDE-hosted manual testing.

---

## Sources

### Primary (HIGH confidence)
- `src/DX.Blame.Navigation.pas` — full source inspection; current signatures, variable names, OnEditorPopup pattern, RemoveOurItems pattern, existing var declarations
- `src/DX.Blame.Renderer.pas` — EditorSetCaretPos implementation, PaintLine ShowInline guard position
- `src/DX.Blame.Registration.pas` — finalization order (lines 304-332), OnBlameToggled wiring pattern (line 281), GEnableBlameItem usage
- `src/DX.Blame.Settings.pas` — existing properties, [Display] INI section, ShowInline pattern to replicate for ShowStatusbar
- `src/DX.Blame.Formatter.pas` — FormatBlameAnnotation signature confirmed; ready for statusbar use
- `src/DX.Blame.Popup.pas` — ShowForCommit signature confirmed; reusable for DISP-02
- `src/DX.Blame.dpk` — current `contains` list; Statusbar unit must be added
- `.planning/research/ARCHITECTURE.md` — StatusBar integration patterns, data flow diagrams, Pitfall cross-references
- `.planning/research/PITFALLS.md` — Pitfalls 3, 4, 5, 7, 10, 13, 16 directly applicable to this phase

### Secondary (MEDIUM confidence)
- `.planning/research/FEATURES.md` — feature descriptions, implementation notes for Statusbar (lines 101-119) and Context Menu Toggle (lines 144-167) and Auto-Scroll (lines 155-169)
- `.planning/phases/12-*/12-01-SUMMARY.md` and `12-02-SUMMARY.md` — confirmed what Phase 12 actually built; verified ShowInline is in place with correct guard position

### Tertiary (LOW confidence — not used; all claims sourced from codebase directly)
None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs confirmed by reading actual source files
- Architecture: HIGH — patterns derived from existing implementation in same codebase
- Pitfalls: HIGH — cross-referenced with PITFALLS.md which was written from direct codebase analysis
- Auto-scroll timing: MEDIUM — OpenFile synchronicity in Delphi 13 not confirmed; timer fallback mitigates risk

**Research date:** 2026-03-26
**Valid until:** 2026-04-26 (OTA interfaces stable; 30 days is appropriate for this domain)
