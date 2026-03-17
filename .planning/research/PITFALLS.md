# Domain Pitfalls

**Domain:** Delphi IDE Plugin -- Git Blame Integration
**Researched:** 2026-03-17

## Critical Pitfalls

Mistakes that cause rewrites, IDE crashes, or major issues.

### Pitfall 1: Leaked OTA Notifiers Crash the IDE

**What goes wrong:** Plugin registers notifiers (IOTAEditorNotifier, INTACodeEditorEvents) but fails to remove them on unload. The IDE tries to call methods on freed objects.
**Why it happens:** Delphi packages can be unloaded at runtime. If the plugin destructor does not remove all notifiers, the IDE holds dangling interface references.
**Consequences:** Access violations in the IDE, often delayed until the next editor action. Hard to debug because the crash happens in IDE code, not plugin code.
**Prevention:** Track every notifier index returned by AddNotifier/AddEditorEventsNotifier. Remove all in destructor with try/except guards. Use a centralized notifier manager.
**Detection:** Test by installing the package, opening a file, then uninstalling the package. If the IDE crashes afterward, notifiers are leaking.

### Pitfall 2: Blocking the Main Thread with Git Blame

**What goes wrong:** Running `git blame` synchronously on the main thread. The IDE freezes for 1-5 seconds on large files.
**Why it happens:** CreateProcess is simple to use synchronously. Developers test with small files and never notice.
**Consequences:** IDE appears frozen. Users immediately uninstall the plugin.
**Prevention:** Always run git in a TThread. Use TThread.ForceQueue to deliver results to the main thread. Show "loading..." or nothing while blame is running.
**Detection:** Open a file with 5000+ lines. If the IDE hiccups, blame is blocking.

### Pitfall 3: Heavy Computation in PaintLine

**What goes wrong:** Doing anything expensive in the PaintLine callback -- parsing, string formatting, dictionary lookups with complex keys, file I/O.
**Why it happens:** PaintLine seems like a natural place to "compute and render." But it is called for EVERY visible line on EVERY repaint (scroll, resize, type a character).
**Consequences:** Editor becomes sluggish. Scrolling lags. Typing feels slow. Users blame the IDE, then discover the plugin.
**Prevention:** Pre-compute all blame display strings. PaintLine should do: one O(1) dictionary lookup + one Canvas.TextOut call. Nothing else.
**Detection:** Profile PaintLine with a timer. If any single call exceeds 0.1ms, it is too slow.

### Pitfall 4: EditView or Buffer Is Nil

**What goes wrong:** Accessing Context.EditView.Buffer.FileName without nil checks. The OTA can pass nil for EditView, and Buffer can be nil for certain view types (welcome page, diff views).
**Why it happens:** OTA documentation is sparse. Works fine in testing because developers only test with regular .pas files.
**Consequences:** Access violation in the IDE on certain screens (start page, diff viewer, binary files).
**Prevention:** Guard every OTA property access: `if Context.EditView = nil then Exit; if Context.EditView.Buffer = nil then Exit;`
**Detection:** Open the IDE start page, then open a .pas file. Switch between them rapidly.

### Pitfall 5: CreateProcess Pipe Deadlock

**What goes wrong:** Git blame output exceeds the pipe buffer size (4KB default). The parent process waits for the child to finish (WaitForSingleObject), but the child blocks because the pipe is full and nobody is reading.
**Why it happens:** Classic pipe deadlock. ReadFile is called AFTER WaitForSingleObject instead of BEFORE.
**Consequences:** Both processes hang forever. The blame thread never completes. No blame data appears.
**Prevention:** Read from the pipe in a loop WHILE the process is running, not after. Close the write end of the pipe in the parent process immediately after CreateProcess so ReadFile returns ERROR_BROKEN_PIPE when the child exits.
**Detection:** Run blame on a file with 10000+ lines. If the thread hangs, this is the cause.

## Moderate Pitfalls

### Pitfall 6: Path Case Sensitivity Mismatches

**What goes wrong:** Blame cache uses file paths as dictionary keys. OTA returns `C:\Projects\MyApp\Unit1.pas`, git returns `unit1.pas` (relative, lowercase). Cache miss on every lookup.
**Prevention:** Normalize all paths: resolve to absolute, lowercase, consistent separators. Use `SameFileName` for comparison. Store normalized paths as cache keys.

### Pitfall 7: Git Not in PATH

**What goes wrong:** CreateProcess fails silently. Plugin shows no blame and no error.
**Prevention:** On plugin startup, try running `git --version`. If it fails, show a one-time balloon notification: "DX.Blame: git not found in PATH." Disable blame until git is detected.

### Pitfall 8: Blame Data Out of Sync After External Changes

**What goes wrong:** User commits in an external terminal. Blame cache still holds old data.
**Prevention:** Re-blame on every file save (IOTAEditorNotifier). For external changes, consider re-blaming when the editor view is activated (user switches tabs). Accept that blame may be stale until re-focus -- this is how GitLens works too.

### Pitfall 9: Unicode File Paths

**What goes wrong:** CreateProcess with PChar on a path containing non-ASCII characters. Command line encoding issues.
**Prevention:** Use CreateProcessW (the Unicode version, which is the default in modern Delphi). Ensure the working directory is properly quoted. Test with umlauts, CJK characters, and spaces in paths.

### Pitfall 10: Multiple Editor Views of Same File

**What goes wrong:** Delphi allows splitting the editor or having the same file open in multiple views. Blame cache stores per-file, but PaintLine fires for each view independently.
**Prevention:** Cache is per file path, not per view. This is correct -- same file, same blame data. But ensure the notifier tracks which views are showing which files. Use `Context.EditView.Buffer.FileName` each time, not a cached assumption.

### Pitfall 11: Code Folding Confuses Line Numbers

**What goes wrong:** Physical line numbers (what the user sees) differ from logical line numbers (actual file lines) when code is folded.
**Prevention:** Always use the logical line number from INTACodeEditorLineState for blame lookup. The physical line number is only for rendering position. The official API provides both.

## Minor Pitfalls

### Pitfall 12: Blame Text Overlaps Code

**What goes wrong:** Inline blame text is rendered on top of long code lines.
**Prevention:** Calculate the end of the actual code text on the line. Start blame text rendering with a gap (e.g., 4 spaces / 40 pixels) after the last character. If the code extends beyond the visible area, consider hiding blame for that line or showing a truncated version.

### Pitfall 13: IDE Theme Changes

**What goes wrong:** Plugin uses hardcoded colors. Looks fine in the default theme, invisible in dark theme.
**Prevention:** Read editor colors from INTACodeEditorOptions or use a muted/semi-transparent color that works in both themes. Provide a color setting.

### Pitfall 14: Package Naming Conflicts

**What goes wrong:** Package name conflicts with other installed packages. Registration procedure name conflicts.
**Prevention:** Use a unique prefix (DX.Blame). Register procedure must be named exactly `Register` in a unit included in the package's Contains list.

### Pitfall 15: Stale Cache After Branch Switch

**What goes wrong:** User switches git branches. All blame data is now wrong.
**Prevention:** Consider running `git rev-parse HEAD` periodically or on editor activation. If HEAD changes, invalidate entire cache. Alternatively, accept this as a known limitation in v1 and document it.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Package setup & registration | Pitfall 1 (leaked notifiers), Pitfall 14 (naming) | Follow DGH OTA Template patterns exactly |
| Git CLI execution | Pitfall 2 (blocking), Pitfall 5 (deadlock), Pitfall 7 (git not found) | Thread from day 1. Read pipe while process runs. Check git exists on startup. |
| Porcelain parsing | Pitfall 9 (unicode) | Test with non-ASCII file content and paths |
| Editor painting | Pitfall 3 (slow PaintLine), Pitfall 4 (nil), Pitfall 11 (folding), Pitfall 12 (overlap) | O(1) lookups only. Nil guards everywhere. Use logical line numbers. |
| Caching | Pitfall 6 (paths), Pitfall 8 (stale), Pitfall 10 (multi-view) | Normalize paths. Re-blame on save. Cache per file not per view. |
| Settings & UX | Pitfall 13 (theme) | Support light/dark or use adaptive colors |

## Sources

- [Parnassus: Code Editor Painting Part 2](https://parnassus.co/mysteries-ide-plugins-painting-code-editor-part-2/) -- Documents EditView nil issues and multi-plugin conflicts.
- [Dave Hoyle: OTA Notifiers](https://www.davidghoyle.co.uk/WordPress/?p=1272) -- Notifier lifecycle and cleanup patterns.
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) -- Common OTA mistakes.
- [IdeasAwakened: CreateProcess](https://ideasawakened.com/post/use-createprocess-and-capture-the-output-in-windows) -- Pipe deadlock documentation.
- [Sebastian Schoener: Win32 Async Redirect](https://blog.s-schoener.com/2024-06-16-stream-redirection-win32/) -- Pipe buffer issues.
- [Embarcadero: ToolsAPI Code Editor](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) -- Performance guidance for PaintLine.
