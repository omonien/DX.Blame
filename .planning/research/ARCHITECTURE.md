# Architecture Patterns

**Domain:** Delphi IDE Plugin -- Git Blame Integration
**Researched:** 2026-03-17

## Recommended Architecture

### High-Level Design

```
+------------------+     +-------------------+     +------------------+
|  IDE Events      |     |  Blame Engine     |     |  Git CLI         |
|  (OTA Layer)     |---->|  (Core Logic)     |---->|  (Process Layer) |
|                  |     |                   |     |                  |
| - File open/close|     | - Cache mgmt      |     | - CreateProcess  |
| - File save      |     | - Blame lookup     |     | - Pipe capture   |
| - Editor paint   |     | - Parser           |     | - Porcelain parse|
| - Keyboard       |     | - Settings         |     |                  |
+------------------+     +-------------------+     +------------------+
        |                         |
        v                         v
+------------------+     +-------------------+
|  Rendering       |     |  Threading        |
|  (Paint Layer)   |     |  (Async Layer)    |
|                  |     |                   |
| - PaintLine impl |     | - TBlameThread    |
| - Text formatting|     | - ForceQueue      |
| - Color/font     |     | - Cancellation    |
+------------------+     +-------------------+
```

### Component Boundaries

| Component | Responsibility | Communicates With | Unit |
|-----------|---------------|-------------------|------|
| Plugin (Wizard) | Lifecycle management, service registration, splash/about | All components | DX.Blame.Plugin |
| Registration | Package init, wizard factory, OTA registration | Plugin | DX.Blame.Registration |
| EditorNotifier | INTACodeEditorEvents implementation, file tracking | BlameCache, Renderer | DX.Blame.EditorNotifier |
| BlameCache | Per-file blame data storage, invalidation | BlameEngine, EditorNotifier | DX.Blame.Cache |
| BlameEngine | Orchestrates blame: detect repo, run git, parse, cache | GitProcess, BlameParser, BlameCache | DX.Blame.GitBlame |
| BlameParser | Parse git blame --porcelain output into TBlameInfo records | BlameEngine | DX.Blame.GitBlame (same unit or sub-unit) |
| GitProcess | CreateProcess wrapper, pipe management, async execution | BlameEngine | DX.Blame.GitBlame |
| Renderer | Format blame text, paint on canvas | EditorNotifier, BlameCache, Settings | DX.Blame.Painting |
| Settings | Toggle state, display preferences, colors | All visual components | DX.Blame.Settings |
| KeyBinding | IOTAKeyboardBinding for toggle hotkey | Settings | DX.Blame.KeyBinding |
| Utils | Git repo detection, path utilities | BlameEngine | DX.Blame.Utils |
| Types | TBlameInfo, TBlameData, TBlameLineInfo records | All components | DX.Blame.GitBlame.Types |

### Data Flow

**On File Open:**
```
1. IOTAEditorNotifier.ViewActivated fires
2. EditorNotifier checks: Is file in a git repo? (Utils.FindGitRoot)
3. If yes: Is blame cached for this file? (BlameCache.HasBlame)
4. If no cache: Start TBlameThread(FilePath, RepoRoot)
5. TBlameThread runs: CreateProcess("git blame --porcelain <file>")
6. TBlameThread parses porcelain output into TBlameData
7. TBlameThread.ForceQueue -> BlameCache.Store(FilePath, BlameData)
8. BlameCache.Store triggers editor invalidation (IOTAEditView.Paint)
```

**On Editor Paint (per line):**
```
1. INTACodeEditorEvents.PaintLine fires (clsAfterText stage)
2. EditorNotifier gets logical line number from LineState
3. Looks up blame info: BlameCache.GetLine(FilePath, LineNumber)
4. If found: Renderer.DrawBlame(Context.Canvas, LineRect, BlameInfo)
5. Renderer formats text: "Author, 3 months ago"
6. Renderer draws text in muted color after code text
```

**On File Save:**
```
1. IOTAEditorNotifier detects save
2. BlameCache.Invalidate(FilePath)
3. Start new TBlameThread for the file (re-blame)
```

**On Toggle:**
```
1. IOTAKeyboardBinding or menu item triggers
2. Settings.Enabled := not Settings.Enabled
3. Invalidate all visible editor views to trigger repaint
```

## Patterns to Follow

### Pattern 1: Notifier Base Class (TNotifierObject)

**What:** All OTA notifiers must descend from TNotifierObject or implement IOTANotifier methods.
**When:** Every notifier class.
**Example:**
```pascal
TBlameEditorNotifier = class(TNotifierObject, INTACodeEditorEvents)
private
  FCache: TBlameCache;
  FEnabled: Boolean;
public
  // INTACodeEditorEvents
  function AllowedEvents: TCodeEditorEvents;
  function AllowedLineStages: TCodeEditorLineStages;
  procedure BeginPaint(const Editor: TWinControl; const ForceFullRepaint: Boolean);
  procedure EndPaint(const Editor: TWinControl);
  procedure PaintLine(const Context: INTACodeEditorPaintContext;
    const LineState: INTACodeEditorLineState;
    const Stage: TCodeEditorLineStage;
    var AllowDefaultPainting: Boolean);
end;
```

### Pattern 2: Selective Event Subscription

**What:** Only subscribe to events the plugin needs via AllowedEvents.
**When:** Always. Performance-critical for painting.
**Example:**
```pascal
function TBlameEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevPaintLineEvents, cevBeginEndPaintEvents];
  // Do NOT include mouse/scroll/gutter unless needed
end;

function TBlameEditorNotifier.AllowedLineStages: TCodeEditorLineStages;
begin
  Result := [clsAfterText]; // Paint after code text, not before
end;
```

### Pattern 3: Thread-Safe Cache with Locking

**What:** Blame cache accessed from paint thread (main) and blame thread (background).
**When:** Always -- PaintLine runs on main thread, blame loading runs on background thread.
**Example:**
```pascal
TBlameCache = class
private
  FLock: TCriticalSection;
  FData: TDictionary<string, TBlameData>;
public
  constructor Create;
  destructor Destroy; override;
  procedure Store(const AFilePath: string; const AData: TBlameData);
  function TryGetLine(const AFilePath: string; ALine: Integer;
    out AInfo: TBlameLineInfo): Boolean;
  procedure Invalidate(const AFilePath: string);
  procedure Clear;
end;
```

### Pattern 4: Proper Notifier Cleanup

**What:** Always remove notifiers on plugin shutdown. Leaked notifiers crash the IDE.
**When:** Plugin destruction / package finalization.
**Example:**
```pascal
destructor TBlamePlugin.Destroy;
begin
  if FEditorNotifierIndex >= 0 then
  begin
    var LServices: INTACodeEditorServices;
    if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
      LServices.RemoveEditorEventsNotifier(FEditorNotifierIndex);
  end;
  inherited;
end;
```

### Pattern 5: Guard Against Nil in OTA Callbacks

**What:** OTA callbacks can pass nil for EditView, Buffer, or other parameters.
**When:** Every OTA callback implementation.
**Example:**
```pascal
procedure TBlameEditorNotifier.PaintLine(...);
begin
  if not FEnabled then Exit;
  if Context = nil then Exit;
  if LineState = nil then Exit;

  var LLineNum := LineState.LogicalLineNumber;
  var LFileName := ''; // obtain from Context.EditView
  if Context.EditView = nil then Exit;
  if Context.EditView.Buffer = nil then Exit;
  LFileName := Context.EditView.Buffer.FileName;

  // Now safe to proceed
end;
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Blocking the Main Thread with Git

**What:** Calling CreateProcess synchronously on the main thread.
**Why bad:** Git blame on large files can take seconds. IDE freezes completely.
**Instead:** Always run git in a TThread. Marshal results back via TThread.ForceQueue.

### Anti-Pattern 2: Hooking TCustomEditControl.PaintLine

**What:** Using DDetours to hook the internal PaintLine method.
**Why bad:** Undocumented, breaks across IDE versions, conflicts with other plugins (CnPack, DDevExtensions), no official support.
**Instead:** Use INTACodeEditorEvents.PaintLine (official API since 11.3).

### Anti-Pattern 3: Heavy Computation in PaintLine

**What:** Parsing blame data, running git, or doing complex lookups during PaintLine.
**Why bad:** PaintLine is called for every visible line on every repaint. Must be sub-millisecond.
**Instead:** Pre-compute everything. PaintLine should only do: cache lookup + Canvas.TextOut.

### Anti-Pattern 4: Forgetting to Remove Notifiers

**What:** Not calling RemoveNotifier / RemoveEditorEventsNotifier on shutdown.
**Why bad:** IDE crash on next editor event after plugin unloaded.
**Instead:** Track all notifier indices. Remove in destructor. Use try/finally.

### Anti-Pattern 5: Assuming File Paths Are Consistent

**What:** Comparing file paths with simple string equality.
**Why bad:** Windows paths are case-insensitive. OTA may return different casing or trailing backslashes.
**Instead:** Normalize paths: `LowerCase(IncludeTrailingPathDelimiter(ExpandFileName(APath)))` or use `SameFileName`.

## Scalability Considerations

| Concern | Small file (100 lines) | Medium file (2000 lines) | Large file (10000+ lines) |
|---------|----------------------|-------------------------|--------------------------|
| Blame execution | < 100ms | 200-500ms | 1-3 seconds |
| Parse time | Negligible | < 50ms | 100-300ms |
| Cache memory | < 10KB | < 200KB | < 1MB |
| PaintLine perf | No concern | No concern | Must be O(1) lookup per line |
| Strategy | Sync possible but async preferred | Async required | Async required, consider incremental blame |

**Recommendation:** Always async. Even for small files, the overhead of a thread is negligible compared to the risk of blocking the IDE.

## Sources

- [Embarcadero: ToolsAPI Support for the Code Editor](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) -- Official API documentation for INTACodeEditorEvents painting.
- [Embarcadero OTAPI-Docs](https://github.com/Embarcadero/OTAPI-Docs) -- Community OTA reference.
- [Dave Hoyle: OTA Notifier Patterns](https://www.davidghoyle.co.uk/WordPress/?p=1272) -- Best practices for notifier lifecycle.
- [Parnassus: Code Editor Painting](https://parnassus.co/mysteries-ide-plugins-painting-code-editor-part-2/) -- Historical context for editor painting approaches.
