# Phase 2: Blame Data Pipeline - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The plugin detects git repos, executes git blame asynchronously, parses porcelain output, and stores results in a thread-safe per-file cache. No visual rendering — this phase delivers the data layer that Phase 3 consumes.

</domain>

<decisions>
## Implementation Decisions

### Git Discovery
- Search system PATH first, then check common install locations (C:\Program Files\Git\cmd, etc.)
- Repo detection: quick filesystem walk for .git folder first, then verify with `git rev-parse --show-toplevel`
- Detection runs once on project open; result is cached until project switch
- If git is not found: show a one-time notification (IDE message), then disable blame features silently — menu stays greyed out

### Error Behavior
- Untracked files (new, outside repo): silent skip — no annotation, no message
- Blame failure on tracked files (binary, git error): log to IDE Messages window
- Uncommitted lines in blame output: show as "Not committed yet" (distinct annotation)
- On blame error: retry once after a short delay (~2-3s) to handle transient git lock issues; if retry fails, log and give up

### Cache Lifecycle
- Cache eviction: invalidate on file save (triggers re-blame), remove from cache when tab is closed
- No maximum cache size — cache grows proportional to open tabs, tab close keeps it bounded
- Re-blame after save uses ~500ms debounce to avoid rapid re-blames during Save All or fast Ctrl+S sequences
- Clear entire cache on project switch — old blame data is stale for a different repo

### Blame Trigger Scope
- Blame the entire file at once (not just visible lines) — one git process per file, data ready for any line
- Triggers: file open and file save only — no periodic timer, no focus-based re-blame
- Large files (1000+ lines): same behavior — blame runs async, doesn't block IDE
- Cancellation: terminate in-progress git process and discard results if tab is closed before blame finishes

### Claude's Discretion
- Exact threading implementation (TThread subclass, anonymous thread, etc.)
- CreateProcess pipe reading strategy and buffer management
- Porcelain parser internal structure and data types
- Thread-safe cache implementation details (TCriticalSection, TMonitor, etc.)
- Exact notification mechanism from background thread to main thread
- Git path search order for common install locations

</decisions>

<specifics>
## Specific Ideas

- GitLens-style "Not committed yet" for uncommitted lines — should feel familiar to VS Code users
- One-time notification for missing git should be non-modal (IDE Messages, not a dialog box)
- Debounce on save re-blame is important for Save All scenarios in large projects

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DX.Blame.Registration.pas`: OTA wizard and menu placeholder — Phase 2 units will be called from here or from new notifiers
- `DX.Blame.Version.pas`: Version constants — can be extended with feature flags if needed

### Established Patterns
- Single design-time package architecture (DX.Blame.dpk)
- OTA service access via `Supports(BorlandIDEServices, IXxxServices, LServices)` pattern
- Menu items created in Registration.pas — Phase 2 won't touch menus but needs to hook into file open/save events

### Integration Points
- OTA Editor Notifiers (IOTAEditorNotifier) for file open/close/save events
- INTAEditServicesNotifier for editor tab tracking
- Background thread results delivered to main thread via TThread.ForceQueue or TThread.Synchronize
- Cache will be consumed by Phase 3's rendering code

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-blame-data-pipeline*
*Context gathered: 2026-03-19*
