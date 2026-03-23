# Phase 4: Tooltip and Commit Detail - Research

**Researched:** 2026-03-23
**Domain:** VCL popup panels, async git data retrieval, diff rendering in Delphi IDE plugin
**Confidence:** HIGH

## Summary

Phase 4 adds click-triggered commit detail popups and a modal diff dialog to the existing DX.Blame IDE plugin. The implementation builds entirely on established project patterns: INTACodeEditorEvents370 for click detection, TGitProcess for async git calls, TIniFile for persistence, and the singleton + finalization lifecycle pattern used throughout the codebase.

The core technical challenge is the popup panel implementation within the IDE editor space. A borderless TCustomForm descendant is the standard VCL approach for floating panels that must dismiss on click-outside -- it avoids the complexity of trying to parent a panel inside the IDE editor control. The diff dialog is straightforward: a modal TForm with a TRichEdit for color-coded unified diff output, following the exact same pattern as TFormDXBlameSettings.

**Primary recommendation:** Use a borderless TCustomForm for the popup panel, TRichEdit with RTF insertion for diff color coding, and extend the existing commit detail cache to be cleared alongside blame cache on project switch.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Click on the rendered blame annotation text opens a custom VCL popup panel (not hover, not system hint)
- Panel dismisses on click outside or Escape key
- Clicking a different annotation while popup is open replaces the content in-place (no close-then-reopen flicker)
- Uncommitted lines: clicking shows a "Not committed yet" message panel -- no hash, no diff button
- Short commit hash (7-char) -- clickable to copy full 40-char SHA to clipboard with brief visual feedback
- Author name, email, full absolute date/time
- Full multi-line commit message (not just first-line Summary)
- "Show Diff" action button to open commit detail dialog (TTIP-02)
- Panel adapts colors to current IDE theme (dark popup for dark theme, light for light) -- consistent with annotation color theming from Phase 3
- Modal VCL dialog showing full diff output
- Plain text with color coding: green for additions, red for deletions (unified diff format)
- Full commit header at top (hash, author, date, full message) above the diff
- Default scope: current file only, with toggle/button to expand to full commit diff (all files)
- Resizable dialog, starting at reasonable default size (e.g. 800x600)
- Dialog size persisted in INI file (same settings.ini from Phase 3)
- Lazy fetch + cache: full commit message and diff output fetched on first click/request, cached per commit hash
- All git fetches (git log for full message, git show for diff) run async in background thread with loading indicator
- Commit detail cache cleared together with blame cache on project switch -- keeps lifecycle simple
- Reuse TGitProcess pattern from Navigation.pas for git calls

### Claude's Discretion
- Exact VCL popup panel implementation (TCustomForm descendant, borderless form, etc.)
- Click detection on annotation area (coordinate math in EditorMouseDown vs hit-testing)
- Loading indicator design (spinner, "Loading..." text, etc.)
- Clipboard copy visual feedback mechanism
- Color coding implementation for diff (TRichEdit RTF, custom paint, etc.)
- INI keys for dialog size persistence
- Toggle UI for current-file vs full-commit diff scope

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TTIP-01 | User sees commit-hash, author, date, full commit message on clicking blame annotation | Popup panel architecture, click detection via EditorMouseDown hit-test, async git log for full message, commit detail cache |
| TTIP-02 | User can open commit detail view with full diff from the popup | Modal diff dialog with TRichEdit RTF color coding, git show/git diff commands, current-file vs full-commit scope toggle |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vcl.Forms (TCustomForm) | RTL | Borderless popup panel | Standard VCL approach for floating panels with click-outside dismissal |
| Vcl.ComCtrls (TRichEdit) | RTL | Diff display with color coding | Native RTF control handles colored text without custom painting |
| Vcl.Clipbrd | RTL | Copy commit hash to clipboard | Standard clipboard API |
| System.IniFiles (TIniFile) | RTL | Dialog size persistence | Already used for settings.ini -- extend same file |
| TGitProcess | Project | Async git CLI execution | Established project pattern for all git calls |
| TThread + TThread.Queue | RTL | Background git fetch | Established project async pattern from Phase 2 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Winapi.Windows | RTL | SetWindowPos, WM_ACTIVATEAPP hooking for popup dismissal | Click-outside detection |
| Vcl.Graphics | RTL | Theme color derivation for popup | Dark/light theme adaptation |
| System.Generics.Collections (TDictionary) | RTL | Commit detail cache keyed by hash | Cache full messages and diffs per commit |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TCustomForm popup | TPanel parented to editor | TPanel requires knowing the editor's parent form, risky in IDE context -- TCustomForm is self-contained |
| TRichEdit for diff | Custom TMemo + owner-draw | TMemo cannot do per-line coloring; owner-draw is fragile -- TRichEdit RTF is proven |
| TRichEdit for diff | TSynEdit / third-party | External dependency, compilation complexity -- TRichEdit is zero-dependency |

## Architecture Patterns

### Recommended New Units
```
src/
  DX.Blame.Popup.pas            # Borderless popup form + click detection logic
  DX.Blame.CommitDetail.pas     # Commit detail cache + async fetch
  DX.Blame.Diff.Form.pas        # Modal diff dialog (TForm + TRichEdit)
  DX.Blame.Diff.Form.dfm        # DFM for diff dialog
```

### Pattern 1: Borderless Popup Form
**What:** A TCustomForm descendant with BorderStyle=bsNone that positions itself near the click location and dismisses on deactivation.
**When to use:** For the commit info popup panel.
**Example:**
```pascal
// Borderless popup with deactivation dismiss
type
  TDXBlamePopup = class(TCustomForm)
  private
    FCommitHash: string;
    procedure CMDeactivate(var Message: TMessage); message CM_DEACTIVATE;
    procedure DoEscapeKey(var Key: Word; Shift: TShiftState);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor CreateNew(AOwner: TComponent); // no DFM needed
    procedure ShowForCommit(const ALineInfo: TBlameLineInfo;
      const AScreenPos: TPoint);
    procedure UpdateContent(const ALineInfo: TBlameLineInfo);
  end;

procedure TDXBlamePopup.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style := WS_POPUP or WS_BORDER;
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW; // no taskbar button
end;

procedure TDXBlamePopup.CMDeactivate(var Message: TMessage);
begin
  inherited;
  Hide; // dismiss on click outside
end;
```
**Key detail:** WS_EX_TOOLWINDOW prevents the popup from appearing in the taskbar. CM_DEACTIVATE fires when another window gets focus, providing clean click-outside dismissal.

### Pattern 2: Hit-Test in EditorMouseDown
**What:** Determine if a click occurred in the annotation area by comparing X coordinate against the annotation start position.
**When to use:** In TDXBlameRenderer.EditorMouseDown (INTACodeEditorEvents370 overload with var Handled).
**Example:**
```pascal
// In TDXBlameRenderer.EditorMouseDown (370 overload)
// The click is in annotation territory if X > VisibleTextRect.Right + padding
// We need to store the last-painted annotation X from PaintLine
procedure TDXBlameRenderer.EditorMouseDown(const Editor: TWinControl;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer;
  var Handled: Boolean);
var
  LLine: Integer;
  LAnnotationX: Integer;
begin
  if Button <> mbLeft then Exit;
  if not BlameSettings.Enabled then Exit;

  // Convert Y to logical line (Y / cell height + top visible line)
  // Use stored annotation X threshold from last paint cycle
  LAnnotationX := FLastAnnotationX; // stored during PaintLine
  if X >= LAnnotationX then
  begin
    // Click is in annotation area -- show popup
    Handled := True;
    ShowBlamePopup(Editor, X, Y);
  end;
end;
```
**Critical note:** PaintLine knows the exact AnnotationX for each line via `Context.LineState.VisibleTextRect.Right + (Context.CellSize.cx * 3)`. Store this per-line or store the minimum X threshold across the paint cycle.

### Pattern 3: Async Commit Detail Fetch
**What:** Background thread fetches full commit message and diff, caches result, delivers to main thread.
**When to use:** When popup opens (for full message) and when "Show Diff" is clicked (for diff content).
**Example:**
```pascal
// Reuse TGitProcess pattern from existing codebase
procedure FetchCommitDetail(const ACommitHash, ARepoRoot: string;
  AOnComplete: TProc<TCommitDetail>);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      LProcess: TGitProcess;
      LOutput: string;
      LDetail: TCommitDetail;
    begin
      LProcess := TGitProcess.Create(FindGitExecutable, ARepoRoot);
      try
        // Full commit message: git log -1 --format=%B <hash>
        LProcess.Execute('log -1 --format=%B ' + ACommitHash, LOutput);
        LDetail.FullMessage := LOutput;

        // Diff for current file: git show <hash> -- <file>
        // Or full commit: git show <hash>
        LProcess.Execute('show ' + ACommitHash, LOutput);
        LDetail.FullDiff := LOutput;
      finally
        LProcess.Free;
      end;

      TThread.Queue(nil,
        procedure
        begin
          AOnComplete(LDetail);
        end);
    end
  ).Start;
end;
```
**Note:** Use `git log -1 --format=%B` for the full multi-line message (Summary field in TBlameLineInfo only has the first line). Use `git show <hash> -- <relpath>` for single-file diff and `git show <hash>` for full-commit diff.

### Pattern 4: RTF Diff Coloring in TRichEdit
**What:** Insert diff lines into TRichEdit with per-line color formatting using SelAttributes.
**When to use:** When populating the diff dialog with git show output.
**Example:**
```pascal
procedure LoadDiffIntoRichEdit(ARichEdit: TRichEdit; const ADiff: string);
var
  LLines: TArray<string>;
  LLine: string;
begin
  ARichEdit.Lines.BeginUpdate;
  try
    ARichEdit.Clear;
    LLines := ADiff.Split([sLineBreak]);
    for LLine in LLines do
    begin
      ARichEdit.SelStart := Length(ARichEdit.Text);
      ARichEdit.SelLength := 0;

      if LLine.StartsWith('+') and not LLine.StartsWith('+++') then
        ARichEdit.SelAttributes.Color := clGreen  // addition
      else if LLine.StartsWith('-') and not LLine.StartsWith('---') then
        ARichEdit.SelAttributes.Color := clRed    // deletion
      else if LLine.StartsWith('@@') then
        ARichEdit.SelAttributes.Color := clBlue   // hunk header
      else
        ARichEdit.SelAttributes.Color := ARichEdit.Font.Color; // default

      ARichEdit.SelText := LLine + sLineBreak;
    end;
  finally
    ARichEdit.Lines.EndUpdate;
  end;
end;
```
**Important:** Set ARichEdit.Font.Name to a monospace font (e.g. 'Consolas') for proper diff alignment. Also set ReadOnly := True and WordWrap := False.

### Anti-Patterns to Avoid
- **Parenting VCL controls inside the IDE editor:** The editor TWinControl is not designed to host child controls. Use a separate top-level form instead.
- **Synchronous git calls on the main thread:** git show on large files can take seconds. Always use background threads.
- **Using system hints/tooltips for rich content:** Windows tooltips have limited formatting and cannot contain interactive elements (buttons, clickable text).
- **Caching diffs by file path:** Cache by commit hash, not file path. The same commit may be referenced from multiple files.
- **Using TThread callbacks with Delphi generics:** As discovered in Phase 2, TProc callbacks can cause type incompatibility. Use the anonymous thread pattern or dedicated thread class.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RTF text coloring | Custom canvas painting in TMemo | TRichEdit.SelAttributes | TRichEdit handles scrolling, selection, copy natively |
| Popup dismissal | Manual mouse hook / WM_NCHITTEST | CM_DEACTIVATE on borderless form | VCL handles focus tracking; manual hooks are fragile in IDE context |
| Clipboard operations | Win32 API (OpenClipboard etc.) | Vcl.Clipbrd.Clipboard.AsText | Standard Delphi pattern, handles format conversion |
| INI persistence | Custom file format | TIniFile (already used) | Consistent with existing settings.ini pattern |
| Thread-safe cache | Manual lock-free structure | TDictionary + TCriticalSection | Established pattern from TBlameCache |

**Key insight:** The entire Phase 4 feature set can be built using only RTL and VCL components. No external dependencies are needed.

## Common Pitfalls

### Pitfall 1: Popup Focus Stealing from IDE Editor
**What goes wrong:** Showing a borderless form takes focus from the editor, which can trigger IDE editor state changes.
**Why it happens:** TCustomForm.Show sets focus to the new form.
**How to avoid:** Use ShowWindow(Handle, SW_SHOWNOACTIVATE) instead of Show for the initial display, then let the user click into the popup to interact. Alternatively, accept the focus change and use CM_DEACTIVATE for clean dismissal.
**Warning signs:** Editor cursor moves or selection changes when popup appears.

### Pitfall 2: Coordinate Translation for Popup Position
**What goes wrong:** Popup appears at wrong screen position because editor coordinates are client-relative.
**Why it happens:** EditorMouseDown provides client coordinates (X, Y relative to the editor TWinControl), but the popup needs screen coordinates.
**How to avoid:** Use `Editor.ClientToScreen(Point(X, Y))` to convert before positioning the popup.
**Warning signs:** Popup appears at top-left of screen or offset from the click.

### Pitfall 3: Stale Popup Reference After Editor Tab Switch
**What goes wrong:** Popup references an editor that is no longer the active tab, causing access violations.
**Why it happens:** User clicks annotation, popup shows, then switches editor tab without dismissing.
**How to avoid:** Hide the popup when editor context changes (handle in EditorScrolled or via IDE notifier events). Store a reference to the editor TWinControl and validate it before updating popup.
**Warning signs:** AV when popup tries to reposition or update content.

### Pitfall 4: TRichEdit RTF Color Not Visible on Dark Theme
**What goes wrong:** Green additions and red deletions are unreadable on dark IDE themes.
**Why it happens:** clGreen/clRed are calibrated for light backgrounds.
**How to avoid:** Derive diff colors from the IDE theme background. For dark themes, use lighter shades (e.g., RGB(144, 238, 144) for additions, RGB(255, 150, 150) for deletions). Use DeriveAnnotationColor approach to detect theme.
**Warning signs:** Diff text invisible or barely readable.

### Pitfall 5: Git Show Output Encoding
**What goes wrong:** Non-ASCII characters in commit messages or file content appear garbled.
**Why it happens:** TGitProcess reads output as UTF-8, but git show may output different encodings depending on config.
**How to avoid:** The existing TGitProcess already uses TEncoding.UTF8.GetString which handles standard git output. No action needed unless specific encoding issues arise.
**Warning signs:** Garbled characters in commit messages with non-ASCII content.

### Pitfall 6: Large Diff Output Freezing TRichEdit
**What goes wrong:** Loading thousands of diff lines into TRichEdit is slow, causing the dialog to appear frozen.
**Why it happens:** TRichEdit.SelText + SelAttributes per line is O(n) per insertion due to internal re-layout.
**How to avoid:** Build RTF string manually and assign via TRichEdit.Lines.LoadFromStream (RTF format) for bulk loading. Or truncate very large diffs with a "Showing first N lines" notice.
**Warning signs:** Dialog takes more than 1-2 seconds to populate for large diffs.

## Code Examples

### Git Commands for Commit Detail

```bash
# Full commit message (multi-line, body only, no header decoration)
git log -1 --format=%B <commit-hash>

# Diff for current file only at specific commit
git show <commit-hash> -- <relative-path>

# Full commit diff (all files)
git show <commit-hash>

# Compact: full header + diff in one call
git show --format=fuller <commit-hash> -- <relative-path>
```

### Clipboard Copy with Visual Feedback

```pascal
procedure CopyHashToClipboard(const AFullHash: string; ALabel: TLabel);
var
  LTimer: TTimer;
  LOldCaption: string;
begin
  Clipboard.AsText := AFullHash;

  // Brief visual feedback: change label text momentarily
  LOldCaption := ALabel.Caption;
  ALabel.Caption := 'Copied!';
  ALabel.Font.Color := clGreen;

  LTimer := TTimer.Create(ALabel); // owned by label, auto-freed
  LTimer.Interval := 1500;
  LTimer.OnTimer :=
    procedure(Sender: TObject)
    begin
      ALabel.Caption := LOldCaption;
      ALabel.Font.Color := ALabel.Parent.Font.Color;
      TTimer(Sender).Free;
    end;
  // Note: anonymous method on TNotifyEvent requires method wrapper
  // Use a handler class method instead (same pattern as TNavigationMenuHandler)
  LTimer.Enabled := True;
end;
```

**Note:** Delphi cannot assign anonymous methods directly to TNotifyEvent. Use a helper class method (same pattern as TNavigationMenuHandler.OnRevisionClick in Navigation.pas).

### INI Persistence for Dialog Size

```pascal
// In DX.Blame.Settings -- extend existing Load/Save
// [DiffDialog] section
// Width=800
// Height=600

FDiffDialogWidth := LIni.ReadInteger('DiffDialog', 'Width', 800);
FDiffDialogHeight := LIni.ReadInteger('DiffDialog', 'Height', 600);

LIni.WriteInteger('DiffDialog', 'Width', FDiffDialogWidth);
LIni.WriteInteger('DiffDialog', 'Height', FDiffDialogHeight);
```

### Theme-Adaptive Popup Colors

```pascal
// Detect dark vs light theme from editor background
function IsDarkTheme: Boolean;
var
  LServices: INTACodeEditorServices;
  LBgColor: TColor;
  LR, LG, LB: Byte;
begin
  Result := False;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
  begin
    LBgColor := ColorToRGB(LServices.Options.BackgroundColor[atWhiteSpace]);
    LR := GetRValue(LBgColor);
    LG := GetGValue(LBgColor);
    LB := GetBValue(LBgColor);
    // Luminance threshold: dark if average < 128
    Result := ((LR + LG + LB) div 3) < 128;
  end;
end;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| System hints for tooltips | Custom borderless form popups | Always (in IDE plugins) | System hints cannot contain buttons or interactive elements |
| TMemo for code display | TRichEdit with RTF coloring | Always (for colored text) | RTF provides per-character formatting without custom painting |
| Synchronous git calls | TThread + TThread.Queue async | Project Phase 2 | Non-blocking UI during git operations |

## Open Questions

1. **PaintLine annotation X storage for hit-testing**
   - What we know: PaintLine computes LAnnotationX per line. EditorMouseDown needs to know whether the click X falls in the annotation area.
   - What's unclear: Whether storing a single "last annotation X" value is sufficient (it varies per line due to different visible text widths).
   - Recommendation: Store annotation rects per visible line during PaintLine (small dictionary or array indexed by visible row), cleared at BeginPaint. This allows precise per-line hit testing.

2. **Popup Z-order inside IDE**
   - What we know: A borderless TCustomForm will be a top-level window. It should appear above the editor but not above other IDE dialogs.
   - What's unclear: Whether the IDE has z-order management that could conflict.
   - Recommendation: Use FormStyle = fsStayOnTop cautiously, or simply rely on default z-order which places the most recently shown form on top. Test in IDE.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (latest, via git submodule) |
| Config file | tests/DX.Blame.Tests.dpr |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |
| Full suite command | Same as quick run (single test project) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TTIP-01 | Commit detail cache stores/retrieves by hash | unit | `DX.Blame.Tests.exe --run=TCommitDetailCacheTests` | No -- Wave 0 |
| TTIP-01 | Full message fetch via git log format | manual-only | Manual: requires git repo context | N/A |
| TTIP-01 | Popup shows correct fields for uncommitted line | manual-only | Manual: requires IDE runtime | N/A |
| TTIP-02 | Diff RTF coloring correctly assigns colors per line type | unit | `DX.Blame.Tests.exe --run=TDiffFormatterTests` | No -- Wave 0 |
| TTIP-02 | Dialog size persistence round-trips through INI | unit | `DX.Blame.Tests.exe --run=TSettingsTests` | Yes (extend existing) |
| TTIP-02 | Current-file diff uses correct git show arguments | unit | `DX.Blame.Tests.exe --run=TCommitDetailTests` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run -- build + run tests
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before /gsd:verify-work

### Wave 0 Gaps
- [ ] `tests/DX.Blame.Tests.CommitDetail.pas` -- covers commit detail cache and git command construction
- [ ] `tests/DX.Blame.Tests.DiffFormatter.pas` -- covers RTF line coloring logic (pure function, testable without IDE)
- [ ] Extend `tests/DX.Blame.Tests.Settings.pas` -- covers DiffDialog Width/Height persistence

## Sources

### Primary (HIGH confidence)
- Project source code: DX.Blame.Renderer.pas, DX.Blame.Navigation.pas, DX.Blame.Settings.pas, DX.Blame.Engine.pas -- established patterns
- Project source code: DX.Blame.Settings.Form.pas/dfm -- modal dialog pattern reference
- Project source code: DX.Blame.Git.Process.pas -- async git execution pattern
- Delphi RTL: TCustomForm, TRichEdit, Vcl.Clipbrd -- standard VCL components

### Secondary (MEDIUM confidence)
- VCL TCustomForm.CreateParams with WS_POPUP | WS_EX_TOOLWINDOW -- standard Windows API pattern for popup windows
- CM_DEACTIVATE for popup dismissal -- well-documented VCL message handling pattern
- TRichEdit.SelAttributes for per-line coloring -- standard RTF control usage

### Tertiary (LOW confidence)
- None -- all patterns are based on established VCL and project patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all VCL/RTL, no external dependencies, patterns proven in earlier phases
- Architecture: HIGH -- direct extension of existing codebase patterns (TGitProcess, TBlameCache, modal forms)
- Pitfalls: HIGH -- well-known VCL popup patterns; coordinate translation and theme adaptation are standard challenges

**Research date:** 2026-03-23
**Valid until:** 2026-04-23 (stable -- RTL/VCL patterns do not change)
