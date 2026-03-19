# Phase 3: Inline Rendering and UX - Research

**Researched:** 2026-03-19
**Domain:** Delphi OTA editor painting, keyboard bindings, settings persistence, IDE integration
**Confidence:** HIGH

## Summary

Phase 3 transforms DX.Blame from a background data pipeline into a visible user feature. The core technical challenge is painting blame annotations inline after the last character of each line in the IDE code editor. Delphi 13 (Studio 37.0) provides the modern `INTACodeEditorEvents` interface in `ToolsAPI.Editor.pas` with `PaintLine` and `PaintText` callbacks, plus `INTACodeEditorPaintContext` which gives access to canvas, line state, visible text rect, cell size, and editor state. This replaces the deprecated `INTAEditViewNotifier` approach and is the correct API for Delphi 11.3+.

The secondary challenges are: (1) registering a configurable hotkey via `IOTAKeyboardBinding`, (2) persisting settings to an INI file, (3) creating a settings dialog, (4) deriving theme-adaptive annotation color from the editor's background color, and (5) implementing parent-commit navigation by opening file content in a new editor tab. All of these have well-documented OTA patterns.

**Primary recommendation:** Use `INTACodeEditorEvents` (registered via `INTACodeEditorServices.AddEditorEventsNotifier`) for all editor painting. Use `PaintLine` at stage `plsEndPaint` with `BeforeEvent=False` to draw annotation text after the IDE has finished painting the line. Use `INTACodeEditorPaintContext.LineState.VisibleTextRect` and `CellSize` to compute the X position after the last character. Use `IOTAKeyboardBinding` for the toggle hotkey. Use standard `TIniFile` for settings persistence.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Default format: "Author, relative time" (e.g. "John Doe, 3 months ago")
- Configurable elements: Show Author (on/off), Date Format (relative/absolute), Show Summary (on/off)
- When summary enabled: "John Doe, 3 months ago - Fix null check"
- Max length: configurable with truncation and ellipsis (e.g. 80 chars default)
- Uncommitted lines: show "Not committed yet"
- Custom paint on editor canvas via OTA/NTA editor paint mechanism
- Font: same monospace font as the editor code, but italic style
- Color auto-adapts from IDE theme by default; user can override with fixed custom color
- Display scope: configurable -- default is current (caret) line only, user can switch to all lines
- Blame enabled by default on first install
- "Enable Blame" menu item becomes a working toggle (checkbox style)
- Toggle state persists across IDE restarts
- All settings persisted in INI file: %APPDATA%\DX.Blame\settings.ini
- Default hotkey: Ctrl+Alt+B for toggle blame on/off
- Hotkey is configurable in settings
- "Settings..." menu item opens a configuration dialog
- Parent commit navigation: context menu "Previous Revision" AND dedicated hotkey
- Parent revision opens in new read-only editor tab with title "filename.pas @ abc1234"
- Navigation is chainable; to go back, close the tab
- Uncommitted lines: "Previous Revision" not available

### Claude's Discretion
- Exact OTA/NTA interface for editor canvas painting (INTACustomEditorView, editor subclassing, etc.)
- Theme color derivation algorithm
- INI file structure and section naming
- Settings dialog layout and component choices
- Hotkey registration mechanism
- How to create a read-only editor view for parent revision content
- Context menu attachment mechanism for the annotation area

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BLAME-01 | User sees inline author + relative time at line end | INTACodeEditorEvents.PaintLine + PaintText for rendering; INTACodeEditorPaintContext for canvas/coordinates; text formatting from TBlameLineInfo |
| CONF-01 | User can configure display format (author on/off, date format, max length) | TIniFile settings persistence; TDXBlameSettings class; settings dialog |
| CONF-02 | User can configure blame text color or auto-derive from theme | INTACodeEditorOptions.BackgroundColor[atWhiteSpace] for theme detection; color derivation algorithm |
| UX-01 | User can toggle blame via menu entry | Existing DXBlameEnableItem TMenuItem -- wire OnClick, set Checked property |
| UX-02 | User can toggle blame via configurable hotkey | IOTAKeyboardBinding interface; IOTAKeyboardServices.AddKeyboardBinding |
| UX-03 | User can navigate to previous revision (parent commit) | IOTAActionServices.OpenFile + IOTASourceEditor buffer manipulation for temp file approach |
</phase_requirements>

## Standard Stack

### Core (already in project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ToolsAPI | Delphi 13 (37.0) | IDE integration interfaces | Required for all IDE plugin development |
| ToolsAPI.Editor | Delphi 13 (37.0) | Code editor painting and events | Modern editor API, replaces deprecated INTAEditViewNotifier |
| System.IniFiles | RTL | Settings persistence | Standard Delphi INI file support |
| Vcl.Forms / Vcl.StdCtrls / Vcl.ExtCtrls | RTL/VCL | Settings dialog | Standard VCL form components |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.DateUtils | RTL | Relative time formatting (MinutesBetween, DaysBetween etc.) | Formatting "3 months ago" strings |
| System.IOUtils | RTL | Directory creation for settings path | Ensuring %APPDATA%\DX.Blame\ exists |
| Vcl.Graphics | RTL/VCL | TColor manipulation, canvas drawing | Theme color derivation, annotation painting |
| Vcl.Menus | RTL/VCL | TShortCut, Shortcut() function | Hotkey definition for IOTAKeyboardBinding |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| INTACodeEditorEvents (modern) | INTAEditViewNotifier (deprecated) | INTAEditViewNotifier is deprecated since 11.3; INTACodeEditorEvents is the current supported API |
| TIniFile | TRegistryIniFile / Registry | INI file is user-decided and more portable/inspectable than registry |
| IOTAKeyboardBinding | IOTAActionServices + menu shortcut | IOTAKeyboardBinding is the standard OTA pattern for editor key bindings |

## Architecture Patterns

### Recommended Project Structure (New Units)
```
src/
  DX.Blame.Settings.pas          # TDXBlameSettings singleton - INI read/write, all config state
  DX.Blame.Renderer.pas          # TDXBlameRenderer - INTACodeEditorEvents impl, all painting logic
  DX.Blame.KeyBinding.pas        # TDXBlameKeyBinding - IOTAKeyboardBinding impl, hotkey toggle
  DX.Blame.Settings.Form.pas     # TFormDXBlameSettings - VCL settings dialog
  DX.Blame.Settings.Form.dfm     # Settings dialog form layout
  DX.Blame.Formatter.pas         # FormatBlameAnnotation() - pure function, text formatting logic
  DX.Blame.Navigation.pas        # Parent commit navigation logic (UX-03)
```

### Pattern 1: INTACodeEditorEvents for Editor Painting
**What:** Register an INTACodeEditorEvents notifier via INTACodeEditorServices.AddEditorEventsNotifier to receive PaintLine callbacks.
**When to use:** For all custom painting in the code editor.
**Example:**
```pascal
// Source: ToolsAPI.Editor.pas (Delphi 13 / Studio 37.0)
type
  TDXBlameRenderer = class(TNotifierObject, INTACodeEditorEvents, INTACodeEditorEvents370)
  protected
    { INTACodeEditorEvents }
    procedure EditorScrolled(const Editor: TWinControl;
      const Direction: TCodeEditorScrollDirection);
    procedure EditorResized(const Editor: TWinControl);
    procedure EditorElided(const Editor: TWinControl; const LogicalLineNum: Integer);
    procedure EditorUnElided(const Editor: TWinControl; const LogicalLineNum: Integer);
    procedure EditorMouseDown(const Editor: TWinControl; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer); overload;
    procedure EditorMouseMove(const Editor: TWinControl; Shift: TShiftState; X, Y: Integer);
    procedure EditorMouseUp(const Editor: TWinControl; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer); overload;
    procedure BeginPaint(const Editor: TWinControl; const ForceFullRepaint: Boolean);
    procedure EndPaint(const Editor: TWinControl);
    procedure PaintLine(const Rect: TRect; const Stage: TPaintLineStage;
      const BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    procedure PaintGutter(const Rect: TRect; const Stage: TPaintGutterStage;
      const BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    procedure PaintText(const Rect: TRect; const ColNum: SmallInt; const Text: string;
      const SyntaxCode: TOTASyntaxCode; const Hilight, BeforeEvent: Boolean;
      var AllowDefaultPainting: Boolean; const Context: INTACodeEditorPaintContext);
    function AllowedEvents: TCodeEditorEvents;
    function AllowedGutterStages: TPaintGutterStages;
    function AllowedLineStages: TPaintLineStages;
    function UIOptions: TCodeEditorUIOptions;
    { INTACodeEditorEvents370 }
    procedure EditorMouseDown(const Editor: TWinControl; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer; var Handled: Boolean); overload;
    procedure EditorMouseUp(const Editor: TWinControl; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer; var Handled: Boolean); overload;
    procedure EditorKeyDown(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorKeyUp(const Editor: TWinControl; Key: Word;
      Shift: TShiftState; var Handled: Boolean);
    procedure EditorSetCaretPos(const Editor: TWinControl; X, Y: Integer);
  end;
```

**Registration:**
```pascal
var
  LServices: INTACodeEditorServices;
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    GEditorNotifierIndex := LServices.AddEditorEventsNotifier(TDXBlameRenderer.Create);
end;
```

**Unregistration:**
```pascal
if GEditorNotifierIndex >= 0 then
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    LServices.RemoveEditorEventsNotifier(GEditorNotifierIndex);
  GEditorNotifierIndex := -1;
end;
```

### Pattern 2: PaintLine Implementation for Inline Annotations
**What:** Draw annotation text after the last character of a line during the plsEndPaint stage.
**When to use:** In the PaintLine callback, when Stage = plsEndPaint and BeforeEvent = False.
**Example:**
```pascal
// Source: ToolsAPI.Editor.pas interface analysis
procedure TDXBlameRenderer.PaintLine(const Rect: TRect;
  const Stage: TPaintLineStage; const BeforeEvent: Boolean;
  var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
var
  LCanvas: TCanvas;
  LLineState: INTACodeEditorLineState;
  LVisibleTextRect: TRect;
  LAnnotationX: Integer;
  LLineNum: Integer;
  LText: string;
  LCellSize: TSize;
begin
  // Only paint after the IDE has finished painting the line
  if (Stage <> plsEndPaint) or BeforeEvent then
    Exit;

  LLineNum := Context.LogicalLineNum;  // 1-based logical line
  LCanvas := Context.Canvas;
  LLineState := Context.LineState;
  LVisibleTextRect := LLineState.VisibleTextRect;
  LCellSize := Context.CellSize;

  // Compute X position: after visible text + padding
  LAnnotationX := LVisibleTextRect.Right + (LCellSize.cx * 3); // 3 chars padding

  // Format and draw annotation text
  LText := FormatBlameAnnotation(LLineNum); // retrieves from cache, formats
  if LText <> '' then
  begin
    LCanvas.Font.Style := [fsItalic];
    LCanvas.Font.Color := GetAnnotationColor;
    LCanvas.TextOut(LAnnotationX, Rect.Top, LText);
  end;
end;

function TDXBlameRenderer.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevPaintLineEvents];
end;

function TDXBlameRenderer.AllowedLineStages: TPaintLineStages;
begin
  Result := [plsEndPaint];
end;
```

### Pattern 3: IOTAKeyboardBinding for Hotkey
**What:** Register a partial keyboard binding for Ctrl+Alt+B to toggle blame.
**When to use:** For the configurable toggle hotkey.
**Example:**
```pascal
// Source: ToolsAPI.pas IOTAKeyboardBinding
type
  TDXBlameKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  public
    procedure ToggleBlame(const Context: IOTAKeyContext;
      KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

function TDXBlameKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TDXBlameKeyBinding.GetName: string;
begin
  Result := 'DX.Blame.ToggleBlame';
end;

function TDXBlameKeyBinding.GetDisplayName: string;
begin
  Result := 'DX Blame Toggle';
end;

procedure TDXBlameKeyBinding.BindKeyboard(
  const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding(
    [ShortCut(Ord('B'), [ssCtrl, ssAlt])], ToggleBlame, nil);
end;

procedure TDXBlameKeyBinding.ToggleBlame(const Context: IOTAKeyContext;
  KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  BlameSettings.Enabled := not BlameSettings.Enabled;
  BlameSettings.Save;
  // Invalidate editor to trigger repaint
  InvalidateAllEditors;
  BindingResult := krHandled;
end;
```

**Registration:**
```pascal
(BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(
  TDXBlameKeyBinding.Create);
```

### Pattern 4: Theme Color Derivation
**What:** Compute a muted annotation color from the editor's background color.
**When to use:** When user has not set a custom color override.
**Example:**
```pascal
// Source: ToolsAPI.Editor.pas INTACodeEditorOptions
function DeriveAnnotationColor: TColor;
var
  LServices: INTACodeEditorServices;
  LBgColor: TColor;
  LR, LG, LB: Byte;
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
  begin
    LBgColor := ColorToRGB(LServices.Options.BackgroundColor[atWhiteSpace]);
    LR := GetRValue(LBgColor);
    LG := GetGValue(LBgColor);
    LB := GetBValue(LBgColor);

    // Blend toward 50% gray: light themes get darker, dark themes get lighter
    // Factor 0.4 = 40% toward gray from background
    LR := LR + Round((128 - Integer(LR)) * 0.4);
    LG := LG + Round((128 - Integer(LG)) * 0.4);
    LB := LB + Round((128 - Integer(LB)) * 0.4);

    Result := RGB(LR, LG, LB);
  end
  else
    Result := clGray; // Fallback
end;
```

### Pattern 5: Settings Persistence with TIniFile
**What:** Read/write all settings from %APPDATA%\DX.Blame\settings.ini.
**When to use:** On plugin load and when user changes settings.
**Example:**
```pascal
// INI structure
// [General]
// Enabled=1
// DisplayScope=CurrentLine  (or AllLines)
//
// [Format]
// ShowAuthor=1
// DateFormat=Relative  (or Absolute)
// ShowSummary=0
// MaxLength=80
//
// [Appearance]
// UseCustomColor=0
// CustomColor=$808080
//
// [Hotkey]
// ToggleBlame=Ctrl+Alt+B

function GetSettingsPath: string;
begin
  Result := IncludeTrailingPathDelimiter(
    GetEnvironmentVariable('APPDATA')) + 'DX.Blame\settings.ini';
end;
```

### Pattern 6: Determining the Current Caret Line
**What:** Get the current cursor line from IOTAEditView.CursorPos or via INTACodeEditorEvents370.EditorSetCaretPos.
**When to use:** For "current line only" display scope.
**Example:**
```pascal
// Option A: Via INTACodeEditorEvents370.EditorSetCaretPos callback
// The 370 interface adds EditorSetCaretPos(Editor, X, Y) where Y = line number
// Track this in a field FCurrentLine and use in PaintLine to decide whether to render

// Option B: Via IOTAEditView.CursorPos
// Available from INTACodeEditorPaintContext.EditView.CursorPos.Line
// Can be queried during PaintLine
```

### Anti-Patterns to Avoid
- **Do NOT use INTAEditViewNotifier for painting:** Deprecated since 11.3. Use INTACodeEditorEvents instead.
- **Do NOT hook TCustomEditControl.PaintLine directly:** This is an internal VMT patching technique that breaks across Delphi versions. The official API is INTACodeEditorEvents.
- **Do NOT paint during BeforeEvent=True in plsEndPaint:** Paint during the "after" event (BeforeEvent=False) so the IDE's default rendering has completed.
- **Do NOT store settings in the registry:** User decision specifies INI file at %APPDATA%.
- **Do NOT create heavy objects in PaintLine:** This callback fires for every visible line on every repaint. Pre-compute and cache annotation strings.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Editor canvas painting | Custom WinAPI hooks or VMT patching | INTACodeEditorEvents.PaintLine | Official API, version-stable, provides canvas + coordinates |
| Keyboard shortcut binding | WH_KEYBOARD hook or message interception | IOTAKeyboardBinding | Standard OTA pattern, appears in IDE key binding options |
| Theme color detection | Parsing IDE config files or registry | INTACodeEditorOptions.BackgroundColor | Direct API access to editor colors |
| Editor invalidation | FindWindow + InvalidateRect | INTACodeEditorServices.InvalidateEditor / InvalidateTopEditor | Safe, version-stable API |
| INI file read/write | Custom file parsing | System.IniFiles.TIniFile | Battle-tested RTL class |
| Relative time formatting | Manual date math | System.DateUtils (YearsBetween, MonthsBetween, etc.) | Handles leap years, DST edge cases |

**Key insight:** Delphi 13 provides a complete, modern editor events API via `ToolsAPI.Editor.pas`. Every aspect of Phase 3 rendering is covered by official interfaces -- there is zero need for internal API hacking.

## Common Pitfalls

### Pitfall 1: PaintLine Performance
**What goes wrong:** Annotation rendering causes visible lag when scrolling because formatting or cache lookups are expensive per-line.
**Why it happens:** PaintLine fires for every visible line on every repaint cycle.
**How to avoid:** Pre-format annotation strings on blame data arrival (in HandleBlameComplete). Cache formatted strings in a parallel array. In PaintLine, only do a dictionary lookup + TextOut.
**Warning signs:** Jerky scrolling, noticeable delay when moving the cursor.

### Pitfall 2: Canvas State Corruption
**What goes wrong:** Changing canvas font/color in PaintLine affects subsequent IDE painting.
**Why it happens:** The canvas object is shared with the IDE's own painting code.
**How to avoid:** Save and restore canvas state (Font, Brush, Pen) around custom drawing. Use try/finally.
**Warning signs:** Code text appears in wrong font or color after blame annotation area.

### Pitfall 3: Coordinate Calculation Errors with Folded Code
**What goes wrong:** Annotations appear on wrong lines when code regions are folded/elided.
**Why it happens:** Using EditorLineNum (visual) vs LogicalLineNum (source) incorrectly.
**How to avoid:** Always use Context.LogicalLineNum to index into blame data. The blame data is indexed by source line number (1-based), matching LogicalLineNum.
**Warning signs:** Wrong blame info shown after folding/unfolding code sections.

### Pitfall 4: Missing Horizontal Scroll Handling
**What goes wrong:** Annotation renders at a fixed X position, overlapping code when scrolled right, or disappearing when scrolled left.
**Why it happens:** Not accounting for horizontal scroll offset in annotation X position.
**How to avoid:** Use LineState.VisibleTextRect which accounts for scroll position. If the visible text rect is fully scrolled out of view, use LineState.CodeRect.Right or a column-based calculation via EditorState.LeftColumn and CellSize.
**Warning signs:** Annotations overlap code text when user scrolls horizontally.

### Pitfall 5: INI File Directory Not Existing
**What goes wrong:** TIniFile.Create fails or silently does not write when %APPDATA%\DX.Blame\ does not exist.
**Why it happens:** First-time install, directory was never created.
**How to avoid:** Use ForceDirectories(ExtractFileDir(GetSettingsPath)) before first write.
**Warning signs:** Settings not persisting across IDE restarts.

### Pitfall 6: Keyboard Binding Index Not Tracked
**What goes wrong:** Memory leak or AV on BPL unload because keyboard binding was not unregistered.
**Why it happens:** IOTAKeyboardServices.AddKeyboardBinding returns an index; not storing or using it for cleanup.
**How to avoid:** Store the index in a global var. In finalization, call RemoveKeyboardBinding(Index).
**Warning signs:** IDE crashes or error messages when unloading the package.

### Pitfall 7: Parent Revision Tab File Conflicts
**What goes wrong:** Opening the same file at the same revision twice creates conflicts or overwrites.
**Why it happens:** Using the same temp file path for different revision views.
**How to avoid:** Use a unique temp file name incorporating the commit hash, e.g., `filename.abc1234.pas`. Clean up temp files when the tab is closed.
**Warning signs:** File content mismatch when navigating parent revisions.

## Code Examples

### Example 1: Relative Time Formatting
```pascal
// Pure function, no OTA dependency -- suitable for DX.Blame.Formatter.pas
function FormatRelativeTime(ADateTime: TDateTime): string;
var
  LNow: TDateTime;
  LYears, LMonths, LDays, LHours, LMinutes: Integer;
begin
  LNow := Now;
  LYears := YearsBetween(LNow, ADateTime);
  if LYears > 0 then
    Exit(IntToStr(LYears) + IfThen(LYears = 1, ' year ago', ' years ago'));

  LMonths := MonthsBetween(LNow, ADateTime);
  if LMonths > 0 then
    Exit(IntToStr(LMonths) + IfThen(LMonths = 1, ' month ago', ' months ago'));

  LDays := DaysBetween(LNow, ADateTime);
  if LDays > 0 then
    Exit(IntToStr(LDays) + IfThen(LDays = 1, ' day ago', ' days ago'));

  LHours := HoursBetween(LNow, ADateTime);
  if LHours > 0 then
    Exit(IntToStr(LHours) + IfThen(LHours = 1, ' hour ago', ' hours ago'));

  LMinutes := MinutesBetween(LNow, ADateTime);
  if LMinutes > 0 then
    Exit(IntToStr(LMinutes) + IfThen(LMinutes = 1, ' minute ago', ' minutes ago'));

  Result := 'just now';
end;
```

### Example 2: Annotation Text Assembly
```pascal
function FormatBlameAnnotation(const ALineInfo: TBlameLineInfo;
  const ASettings: TDXBlameSettings): string;
var
  LParts: TStringBuilder;
begin
  if ALineInfo.IsUncommitted then
    Exit(cNotCommittedAuthor);

  LParts := TStringBuilder.Create;
  try
    if ASettings.ShowAuthor then
      LParts.Append(ALineInfo.Author);

    if ASettings.ShowAuthor then
      LParts.Append(', ');

    case ASettings.DateFormat of
      dfRelative: LParts.Append(FormatRelativeTime(ALineInfo.AuthorTime));
      dfAbsolute: LParts.Append(FormatDateTime('yyyy-mm-dd', ALineInfo.AuthorTime));
    end;

    if ASettings.ShowSummary and (ALineInfo.Summary <> '') then
    begin
      LParts.Append(' ' + #$2022 + ' '); // bullet separator
      LParts.Append(ALineInfo.Summary);
    end;

    Result := LParts.ToString;

    // Truncate with ellipsis if exceeding max length
    if (ASettings.MaxLength > 0) and (Length(Result) > ASettings.MaxLength) then
      Result := Copy(Result, 1, ASettings.MaxLength - 1) + #$2026; // ellipsis
  finally
    LParts.Free;
  end;
end;
```

### Example 3: Invalidating the Editor After Settings Change
```pascal
// Source: ToolsAPI.Editor.pas INTACodeEditorServices
procedure InvalidateAllEditors;
var
  LServices: INTACodeEditorServices;
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    LServices.InvalidateTopEditor;
end;
```

### Example 4: Opening a File for Parent Revision (UX-03)
```pascal
// Strategy: Write git show output to a temp file, open it in IDE, mark tab title
procedure OpenParentRevision(const AFileName: string; const ACommitHash: string);
var
  LParentHash: string;
  LTempDir: string;
  LTempFile: string;
  LContent: string;
  LBaseName: string;
  LActionServices: IOTAActionServices;
begin
  // 1. Get parent commit hash: git rev-parse <hash>^
  // 2. Get file content at parent: git show <parent>:<relative-path>
  // 3. Write to temp file with unique name
  LBaseName := ChangeFileExt(ExtractFileName(AFileName), '');
  LTempDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'DX.Blame';
  ForceDirectories(LTempDir);
  LTempFile := LTempDir + '\' + LBaseName + '.' + Copy(LParentHash, 1, 7) + '.pas';

  // Write content to temp file
  TFile.WriteAllText(LTempFile, LContent, TEncoding.UTF8);

  // Open in IDE
  if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
    LActionServices.OpenFile(LTempFile);
end;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| INTAEditViewNotifier.PaintLine | INTACodeEditorEvents.PaintLine | Delphi 11.3 (28.0) | INTAEditViewNotifier deprecated; INTACodeEditorEvents is the modern replacement with richer context |
| VMT patching of TCustomEditControl | INTACodeEditorServices | Delphi 10.4+ | Official API eliminates brittle internal hacking |
| IOTAEditorServices for editor access | INTACodeEditorServices | Delphi 10.4+ | More complete editor control access, invalidation, and state queries |
| N/A | INTACodeEditorEvents370 | Delphi 13 (37.0) | Adds EditorSetCaretPos, EditorKeyDown/Up, EditorMouseDown/Up with Handled parameter |

**Deprecated/outdated:**
- INTAEditViewNotifier: Deprecated since Delphi 11.3. Use INTACodeEditorEvents.
- TCustomEditControl direct manipulation: Fragile, breaks across versions. Use official ToolsAPI.Editor APIs.

## Open Questions

1. **Parent revision tab title customization**
   - What we know: IOTAActionServices.OpenFile opens a file and creates a tab with the filename as title. The temp file can be named to include the commit hash.
   - What's unclear: Whether the tab title can be changed after opening (e.g., to "filename.pas @ abc1234" instead of the temp filename). IOTAModule.SetFileName or window caption manipulation may be needed.
   - Recommendation: Use the temp file naming convention (e.g., `Filename.abc1234.pas`) as the de facto tab title. This is good enough and avoids fragile IDE internals. The short hash in the filename serves the purpose.

2. **Context menu for "Previous Revision"**
   - What we know: INTACodeEditorEvents370 provides mouse events with coordinates. IOTAEditView.GetEditWindow.Form.FindComponent('EditorLocalMenu') returns the editor popup menu.
   - What's unclear: Whether adding items to the editor's local popup is stable across IDE versions.
   - Recommendation: Add a "Previous Revision" item to the editor's context menu via FindComponent('EditorLocalMenu'). This is a known GExperts pattern. As fallback, the hotkey always works.

3. **Configurable hotkey persistence**
   - What we know: IOTAKeyboardBinding binds a fixed shortcut at registration time. The user wants to configure the hotkey.
   - What's unclear: Whether IOTAKeyboardBinding can be dynamically re-registered with a different shortcut.
   - Recommendation: For v1, use the default Ctrl+Alt+B. Store the preference in settings.ini. To change the hotkey, require IDE restart (remove and re-add the binding on load). Document this limitation.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (existing in project) |
| Config file | tests/DX.Blame.Tests.dpr |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe` |
| Full suite command | Same as quick run (single test project) |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BLAME-01 | Annotation text formatting (relative time, author, truncation) | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Formatter` | No -- Wave 0 |
| CONF-01 | Settings read/write persistence | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Settings` | No -- Wave 0 |
| CONF-02 | Theme color derivation algorithm | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Formatter` | No -- Wave 0 |
| UX-01 | Menu toggle (requires IDE) | manual-only | N/A -- requires running IDE | N/A |
| UX-02 | Hotkey toggle (requires IDE) | manual-only | N/A -- requires running IDE | N/A |
| UX-03 | Parent revision navigation (requires IDE + git repo) | manual-only | N/A -- requires running IDE | N/A |

### Sampling Rate
- **Per task commit:** Build test project and run
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before /gsd:verify-work

### Wave 0 Gaps
- [ ] `tests/DX.Blame.Tests.Formatter.pas` -- covers BLAME-01 annotation formatting, relative time, truncation
- [ ] `tests/DX.Blame.Tests.Settings.pas` -- covers CONF-01 settings read/write round-trip
- [ ] Update `tests/DX.Blame.Tests.dpr` to include new test units

## Sources

### Primary (HIGH confidence)
- ToolsAPI.Editor.pas (Delphi 13 / Studio 37.0, local file) -- INTACodeEditorEvents, INTACodeEditorPaintContext, INTACodeEditorServices, TPaintLineStage, INTACodeEditorOptions, INTACodeEditorLineState interface declarations
- ToolsAPI.pas (Delphi 13 / Studio 37.0, local file) -- IOTAKeyboardBinding, IOTAEditView, TOTAEditPos, IOTAActionServices

### Secondary (MEDIUM confidence)
- [Embarcadero Blog: Open Tools APIs for Decorating IDE](https://blogs.embarcadero.com/quickly-learn-about-the-ultimate-open-tools-apis-for-decorating-your-delphi-c-builder-ide/) -- INTAEditViewNotifier deprecation, INTACodeEditorEvents recommendation
- [Embarcadero DocWiki: ToolsAPI Support for the Code Editor](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) -- PaintLine usage, AllowedEvents flags
- [Embarcadero DocWiki: INTACodeEditorEvents.BeginPaint](https://docwiki.embarcadero.com/Libraries/Athens/en/ToolsAPI.Editor.INTACodeEditorEvents.BeginPaint) -- Registration and event flags
- [Cary Jensen: Creating Editor Key Bindings](http://caryjensen.blogspot.com/2010/06/creating-editor-key-bindings-in-delphi.html) -- IOTAKeyboardBinding implementation pattern
- [GExperts Open Tools API FAQ](https://www.gexperts.org/open-tools-api-faq/) -- Editor popup menu access pattern

### Tertiary (LOW confidence)
- [Parnassus: Painting in the Code Editor Part 2](https://parnassus.co/mysteries-ide-plugins-painting-code-editor-part-2/) -- Historical TCustomEditControl patterns (outdated, but informative for understanding)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- interfaces verified directly in ToolsAPI.Editor.pas from Delphi 13 installation
- Architecture: HIGH -- patterns derived from official interface declarations and base class TNTACodeEditorNotifier
- Pitfalls: MEDIUM -- based on general OTA experience and canvas painting principles; some edge cases may emerge in practice
- Parent revision navigation: MEDIUM -- IOTAActionServices.OpenFile is verified, but tab title customization approach needs validation during implementation

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable -- Delphi 13 released, APIs unlikely to change)
