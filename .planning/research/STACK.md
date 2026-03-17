# Technology Stack

**Project:** DX.Blame (Git Blame IDE Plugin for Delphi)
**Researched:** 2026-03-17

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| Delphi Open Tools API (OTA) | Delphi 11.3+ / 12 / 13 | IDE integration, editor access, notifiers | Official, supported API. No hacks needed. | HIGH |
| INTACodeEditorEvents | Introduced 11.3 (Alexandria Update 3) | Editor painting (PaintLine, PaintText, PaintGutter) | Official painting API replacing deprecated INTAEditViewNotifier. Provides Canvas, TRect, line numbers, and full context. No runtime hooks needed. | HIGH |
| INTACodeEditorServices | Introduced 11.3 | Register notifiers, query editor controls, request gutter columns | Entry point for all editor customization. AddEditorEventsNotifier registers the plugin. | HIGH |
| IOTAEditorServices | All OTA versions | Access to editor views, top buffer, current file | Standard OTA service for file/buffer access. | HIGH |
| IOTAKeyboardBinding | All OTA versions | Register toggle hotkey (e.g., Ctrl+Shift+B) | Standard OTA interface for keyboard shortcuts. Uses AddKeyBinding with TShortcut. | HIGH |

### Git CLI Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| CreateProcess + Pipes (Win32 API) | Windows API | Execute `git blame --porcelain` and capture stdout | Native Windows approach. No external dependencies. Pipes allow reading large output without deadlock. | HIGH |
| TThread / TTask | RTL | Async git blame execution | Blame must not block the IDE main thread. TThread is simpler and more predictable than TTask for single background operations. | HIGH |
| TThread.ForceQueue | RTL (Delphi 10.2+) | Marshal results back to main thread | Recommended by Embarcadero OTA docs for deferred operations from event handlers. Thread-safe main-thread dispatch. | HIGH |

### Supporting Libraries

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| DDetours (Mahdi Safsafi) | v2.2 (MPL-2.0) | Runtime method hooking | FALLBACK ONLY: If targeting Delphi 11.0-11.2 (before INTACodeEditorEvents). Not needed for 11.3+. | MEDIUM |
| DGH OTA Template (David Hoyle) | Latest | Reference implementation for wizard registration, splash screen, about box | Study and adapt patterns, do not depend on as library. | MEDIUM |

### OTA Interfaces Used (Complete Map)

| Interface | Purpose | Registration |
|-----------|---------|-------------|
| IOTAWizard | Main plugin entry point | Register in package initialization |
| IOTAIDENotifier / IOTAIDENotifier80 | Project open/close, file notifications | BorlandIDEServices as IOTAServices |
| IOTAEditorNotifier | Editor tab open/close/modify events | IOTAModule.AddNotifier |
| INTACodeEditorEvents | Editor painting (PaintLine) and mouse events | INTACodeEditorServices.AddEditorEventsNotifier |
| INTACodeEditorServices | Query editor controls, state, gutter | BorlandIDEServices as INTACodeEditorServices |
| INTACodeEditorState | Visible lines, character-to-pixel conversion | Obtained from INTACodeEditorServices |
| INTACodeEditorLineState | Per-line rectangles, line numbers, visibility | Passed in PaintLine context |
| INTACodeEditorPaintContext | Canvas, rects, edit view during painting | Parameter to PaintLine/PaintText |
| IOTAKeyboardBinding | Hotkey registration | IOTAKeyboardServices.AddKeyboardBinding |
| IOTASplashScreenServices | Splash screen branding | Package initialization |
| IOTAAboutBoxServices | About box entry | Package initialization |
| IOTAModuleServices | Get current module/file path | BorlandIDEServices as IOTAModuleServices |
| IOTASourceEditor | Access source buffer, file name | IOTAModule.GetModuleFileEditor |

## Key API: INTACodeEditorEvents Painting

### PaintLine

The central method for inline blame rendering. Called for each visible line during editor repaint.

```pascal
procedure PaintLine(
  const Context: INTACodeEditorPaintContext;  // Canvas, TRect, EditView
  const LineState: INTACodeEditorLineState;   // Line number, rects
  const Stage: TCodeEditorLineStage;          // Before/after text painting
  var AllowDefaultPainting: Boolean           // Suppress default if needed
);
```

**Usage for DX.Blame:** After default painting (post-text stage), draw blame annotation text to the right of the last character using `Context.Canvas.TextOut` within the line rect.

### AllowedEvents / AllowedLineStages

Performance optimization: Only subscribe to events the plugin needs.

```pascal
function AllowedEvents: TCodeEditorEvents;
// Return: [cevPaintLineEvents, cevBeginEndPaintEvents]
// Do NOT subscribe to mouse/scroll/gutter unless needed.

function AllowedLineStages: TCodeEditorLineStages;
// Return: [clsAfterText]  -- paint AFTER the code text is rendered
```

### Registration

```pascal
var
  LServices: INTACodeEditorServices;
  LNotifierIndex: Integer;
begin
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
    LNotifierIndex := LServices.AddEditorEventsNotifier(FCodeEditorNotifier);
end;
```

## Git Blame Integration

### Command

```
git blame --porcelain <filepath>
```

The `--porcelain` format outputs machine-parseable blocks per line:

```
<40-char SHA> <orig-line> <final-line> [<num-lines>]
author <name>
author-mail <email>
author-time <unix-timestamp>
author-tz <timezone>
committer <name>
committer-mail <email>
committer-time <unix-timestamp>
committer-tz <timezone>
summary <commit message first line>
filename <path>
	<actual line content prefixed with tab>
```

### Async Execution Pattern

```pascal
TBlameThread = class(TThread)
private
  FFilePath: string;
  FRepoRoot: string;
  FOnComplete: TProc<TBlameData>;
protected
  procedure Execute; override;
end;

procedure TBlameThread.Execute;
var
  LOutput: string;
  LBlameData: TBlameData;
begin
  LOutput := RunGitCommand(FRepoRoot, 'blame --porcelain "' + FFilePath + '"');
  LBlameData := TBlameParser.Parse(LOutput);
  if not Terminated then
    TThread.ForceQueue(nil,
      procedure
      begin
        FOnComplete(LBlameData);
      end);
end;
```

### CreateProcess with Pipe Pattern

```pascal
function RunGitCommand(const AWorkDir, AArgs: string): string;
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LCmd: string;
  LBytesRead: DWORD;
  LBuffer: TBytes;
begin
  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  CreatePipe(LReadPipe, LWritePipe, @LSA, 0);
  SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);

  ZeroMemory(@LSI, SizeOf(LSI));
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  LSI.hStdOutput := LWritePipe;
  LSI.hStdError := LWritePipe;
  LSI.wShowWindow := SW_HIDE;

  LCmd := 'git ' + AArgs;
  CreateProcess(nil, PChar(LCmd), nil, nil, True,
    CREATE_NO_WINDOW, nil, PChar(AWorkDir), LSI, LPI);

  CloseHandle(LWritePipe); // Must close write end so ReadFile returns on process exit

  SetLength(LBuffer, 65536);
  Result := '';
  while ReadFile(LReadPipe, LBuffer[0], Length(LBuffer), LBytesRead, nil) and (LBytesRead > 0) do
    Result := Result + TEncoding.UTF8.GetString(LBuffer, 0, LBytesRead);

  CloseHandle(LReadPipe);
  CloseHandle(LPI.hProcess);
  CloseHandle(LPI.hThread);
end;
```

## Delphi Version Compatibility Strategy

| Feature | Delphi 11.0-11.2 | Delphi 11.3+ | Delphi 12 | Delphi 13 |
|---------|-------------------|---------------|-----------|-----------|
| INTACodeEditorEvents | NOT available | Available | Available | Available |
| INTAEditViewNotifier | Available (deprecated 11.3) | Available but deprecated | Deprecated | Deprecated |
| IOTAKeyboardBinding | Available | Available | Available | Available |
| TThread.ForceQueue | Available | Available | Available | Available |

**Decision: Target Delphi 11.3+ minimum.**

Rationale: INTACodeEditorEvents is the correct, official API for editor painting. Supporting 11.0-11.2 would require either the deprecated INTAEditViewNotifier or DDetours-based runtime hooks -- both approaches are fragile and add significant complexity. Delphi 11.3 was released in early 2023; expecting users to have at least 11.3 is reasonable for a new plugin in 2026.

Use `{$IF CompilerVersion >= 35.1}` (Delphi 11.3 = compiler version 35.1) for any conditional compilation if needed.

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Editor painting | INTACodeEditorEvents (official) | DDetours + PaintLine hook | Hooks are fragile across IDE versions, can conflict with other plugins, and are undocumented. Official API is stable and supported. |
| Editor painting (legacy) | INTACodeEditorEvents | INTAEditViewNotifier | Deprecated since 11.3. Will likely be removed in future versions. |
| Git integration | git CLI via CreateProcess | libgit2 native bindings | Massive dependency, complex build setup, DLL distribution. git CLI is simpler and always matches user's git version. |
| Git integration | CreateProcess + Pipes | ShellExecute | ShellExecute cannot capture stdout. CreateProcess with pipes is required for output capture. |
| Async execution | TThread | TTask (PPL) | TTask is fine for fire-and-forget but TThread gives better control over cancellation and lifecycle for a long-running blame operation. |
| Async execution | TThread | OmniThreadLibrary | External dependency. TThread from RTL is sufficient for single background operations. |
| Package type | Design-time BPL | DLL Expert | Design-time package is the standard for IDE plugins. Simpler installation via Component > Install Packages. |
| Caching | TDictionary in-memory | SQLite / file cache | Blame data is transient (valid only while file is open and unchanged). In-memory cache is simpler and sufficient. |

## Installation

No external packages required. Pure Delphi RTL + OTA.

```
Required units (all ship with Delphi):
- ToolsAPI
- ToolsAPI.Editor  (Delphi 11.3+)
- System.Classes
- System.SysUtils
- System.Generics.Collections
- System.Threading (if using TTask, optional)
- Winapi.Windows
- Vcl.Graphics
```

## Project Structure (per CLAUDE.md conventions)

```
DX.Blame/
  src/
    DX.Blame.dpk                    -- Design-time package
    DX.Blame.Registration.pas       -- Register, wizard creation, splash screen
    DX.Blame.Plugin.pas             -- Main plugin class (IOTAWizard)
    DX.Blame.EditorNotifier.pas     -- INTACodeEditorEvents implementation
    DX.Blame.GitBlame.pas           -- Git CLI execution, porcelain parser
    DX.Blame.GitBlame.Types.pas     -- TBlameInfo, TBlameData records
    DX.Blame.Cache.pas              -- Per-file blame cache (TDictionary)
    DX.Blame.Painting.pas           -- Blame text rendering logic
    DX.Blame.Settings.pas           -- Toggle state, display format, colors
    DX.Blame.KeyBinding.pas         -- IOTAKeyboardBinding for toggle hotkey
    DX.Blame.Utils.pas              -- Git repo detection, path utilities
  tests/
    DX.Blame.Tests.dproj            -- DUnitX tests (parser, cache logic)
  build/
    DelphiBuildDPROJ.ps1            -- Universal build script
  docs/
    -- Style guide, documentation
```

## Sources

- [Embarcadero: ToolsAPI Support for the Code Editor (Athens)](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) -- Official docs for INTACodeEditorEvents, introduced 11.3. HIGH confidence.
- [Embarcadero: INTACodeEditorEvents.BeginPaint](https://docwiki.embarcadero.com/Libraries/Athens/en/ToolsAPI.Editor.INTACodeEditorEvents.BeginPaint) -- Official method reference. HIGH confidence.
- [Embarcadero: INTACodeEditorEvents.PaintText](https://docwiki.embarcadero.com/Libraries/Athens/en/ToolsAPI.Editor.INTACodeEditorEvents.PaintText) -- Official method reference. HIGH confidence.
- [Embarcadero Blog: Ultimate Open Tools APIs for Decorating Your IDE](https://blogs.embarcadero.com/quickly-learn-about-the-ultimate-open-tools-apis-for-decorating-your-delphi-c-builder-ide/) -- Overview with usage examples. HIGH confidence.
- [Embarcadero OTAPI-Docs (GitHub)](https://github.com/Embarcadero/OTAPI-Docs) -- Community-maintained OTA documentation. MEDIUM confidence.
- [DGH2112 OTA Template (GitHub)](https://github.com/DGH2112/OTA-Template) -- Reference implementation for wizard structure. MEDIUM confidence.
- [Dave Hoyle: OTA Blog Series](https://www.davidghoyle.co.uk/WordPress/?page_id=667) -- Comprehensive OTA tutorials including notifiers, about boxes, splash screens. MEDIUM confidence.
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) -- Common OTA questions and solutions. MEDIUM confidence.
- [Parnassus: Mysteries of IDE Plugins Part 1](https://parnassus.co/mysteries-of-ide-plugins-painting-in-the-code-editor-part-1/) -- Documents the OLD (pre-11.3) hook-based approach. Useful for understanding history, NOT recommended for new code. MEDIUM confidence.
- [Parnassus: Mysteries of IDE Plugins Part 2](https://parnassus.co/mysteries-ide-plugins-painting-code-editor-part-2/) -- PaintLine hook parameters. Historical reference only. MEDIUM confidence.
- [DDetours (GitHub)](https://github.com/MahdiSafsafi/DDetours) -- Runtime hooking library. MPL-2.0. Last updated 2020. Only needed for pre-11.3 support. LOW confidence for Delphi 13 compatibility.
- [IdeasAwakened: CreateProcess and capture output](https://ideasawakened.com/post/use-createprocess-and-capture-the-output-in-windows) -- Delphi CreateProcess pattern with pipes. MEDIUM confidence.
- [Git blame documentation](https://git-scm.com/docs/git-blame) -- Official porcelain format specification. HIGH confidence.
- [Cary Jensen: Creating Editor Key Bindings](http://caryjensen.blogspot.com/2010/06/creating-editor-key-bindings-in-delphi.html) -- IOTAKeyboardBinding tutorial. MEDIUM confidence.
