# Project Research Summary

**Project:** DX.Blame (Git Blame IDE Plugin for Delphi)
**Domain:** Delphi IDE Plugin — Git Blame Integration
**Researched:** 2026-03-17
**Confidence:** HIGH

## Executive Summary

DX.Blame is a Delphi IDE plugin that renders inline git blame annotations directly in the code editor — similar to GitLens for VS Code. The recommended approach is a clean, dependency-free implementation using Delphi's official Open Tools API (OTA) with INTACodeEditorEvents (introduced in Delphi 11.3) for painting, plus native Win32 CreateProcess/pipe patterns for executing git blame asynchronously. No external libraries are required. The entire stack ships with Delphi itself, making installation trivial: one design-time BPL registered via Component > Install Packages.

The architecture decomposes clearly into five layers: the OTA event layer (notifiers that react to IDE events), the blame engine (git execution, porcelain parsing, cache management), the rendering layer (PaintLine callback doing O(1) cache lookups and Canvas.TextOut), the async threading layer (TThread + ForceQueue for non-blocking git execution), and settings/key binding. The data flow is well-understood and linear: file open triggers async git blame, parsed results populate an in-memory TDictionary cache, and PaintLine reads from the cache on every editor repaint.

The two overriding risks are IDE stability and editor performance. Leaked OTA notifiers cause delayed access violations in the IDE — every notifier index must be tracked and removed on plugin unload. Heavy computation in PaintLine causes visible editor lag — the callback must be kept to a single O(1) lookup plus a TextOut call. Both risks have well-established mitigations documented by the OTA community. A third risk — CreateProcess pipe deadlock on large files — is equally well-documented and straightforward to avoid by reading the pipe while the process runs rather than after it exits.

## Key Findings

### Recommended Stack

The plugin requires no external dependencies beyond standard Delphi RTL and the OTA units that ship with the IDE. INTACodeEditorEvents (ToolsAPI.Editor unit, Delphi 11.3+) is the correct, officially supported API for editor painting — it replaces the deprecated INTAEditViewNotifier and eliminates any need for runtime hooking via DDetours. Delphi 11.3 is the minimum supported version; targeting 11.3/12/13 covers the broad active user base while using only stable, forward-compatible interfaces.

**Core technologies:**
- **INTACodeEditorEvents** (OTA, Delphi 11.3+): Editor painting via PaintLine — the only officially supported way to draw in the code editor
- **INTACodeEditorServices** (OTA): Notifier registration and editor state queries
- **IOTAKeyboardBinding** (OTA): Toggle hotkey registration without polling
- **IOTAWizard** (OTA): Plugin entry point and lifecycle management
- **CreateProcess + anonymous pipes** (Win32 API): Capture git blame stdout without external dependencies; read pipe while process runs to avoid deadlock
- **TThread + TThread.ForceQueue** (RTL): Async git execution with safe main-thread result delivery; ForceQueue is explicitly recommended by Embarcadero for OTA background operations
- **TDictionary + TCriticalSection** (RTL): Thread-safe in-memory per-file blame cache with normalized path keys

**Version decision:** Delphi 11.3+ minimum. INTACodeEditorEvents is the correct API; supporting older versions would require deprecated or hook-based approaches that are fragile and unsupported.

### Expected Features

The feature research is anchored on GitLens (VS Code) as the established reference for what users expect from IDE blame integration. The feature dependency chain runs strictly from git repo detection through blame execution, parsing, and caching, then to rendering and UX controls.

**Must have (table stakes):**
- Inline blame annotation at end of current line — author + relative time (e.g., "John Doe, 3 months ago")
- Automatic blame load on file open via IOTAEditorNotifier.ViewActivated
- Cache invalidation and re-blame on file save
- Non-blocking execution — TThread + CreateProcess; the IDE must never freeze
- Toggle on/off via menu item and keyboard shortcut (IOTAKeyboardBinding)
- Git repo detection by walking parent directories for .git folder
- Delphi 11.3 / 12 / 13 support

**Should have (competitive differentiators):**
- Hover tooltip showing full commit info (hash, message, date) without leaving the editor
- Configurable display format (show/hide author, date format, max length)
- Configurable blame text color to match IDE theme (light/dark adaptive)
- Commit detail view from tooltip (git show output in modal form)

**Defer (v2+):**
- Blame for selection range (git blame -L)
- Navigate to previous revision (time-travel through file history)
- External branch-switch detection — stale cache on branch change accepted as v1 known limitation

**Explicit anti-features:** No gutter column (invasive, conflicts with other plugins), no libgit2 dependency, no real-time blame on keystrokes, no SVN/Mercurial support.

### Architecture Approach

The architecture is a five-layer pipeline with clear component boundaries and no circular dependencies. The OTA event layer receives IDE signals and delegates to the blame engine; the blame engine orchestrates git execution, parsing, and cache management; the rendering layer reads from cache and draws; the threading layer keeps git off the main thread; and settings provide shared state. All inter-layer communication flows downward or through the cache as a shared data store protected by a TCriticalSection.

**Major components:**
1. **Plugin / Registration** (`DX.Blame.Plugin`, `DX.Blame.Registration`) — IOTAWizard lifecycle, splash screen, about box, service registration on package init/finit
2. **EditorNotifier** (`DX.Blame.EditorNotifier`) — INTACodeEditorEvents implementation; reacts to file open/save/close, drives PaintLine callbacks
3. **BlameEngine** (`DX.Blame.GitBlame`) — orchestrates repo detection, CreateProcess execution, porcelain parsing into TBlameData records
4. **BlameCache** (`DX.Blame.Cache`) — TDictionary protected by TCriticalSection; per-file storage with path-normalized keys
5. **Renderer** (`DX.Blame.Painting`) — formats blame text, paints on canvas; called only from PaintLine with a guaranteed O(1) cache access
6. **Threading layer** (`TBlameThread` inside `DX.Blame.GitBlame`) — TThread subclass; delivers results to main thread via TThread.ForceQueue
7. **Settings + KeyBinding** (`DX.Blame.Settings`, `DX.Blame.KeyBinding`) — toggle state, display preferences, IOTAKeyboardBinding registration
8. **Utils** (`DX.Blame.Utils`) — git root detection, path normalization with SameFileName-compatible keys

### Critical Pitfalls

1. **Leaked OTA notifiers cause IDE crashes** — every AddNotifier/AddEditorEventsNotifier index must be stored and passed to the corresponding Remove method in the plugin destructor, wrapped in try/except. Test by installing, opening a file, uninstalling — the IDE must not crash.

2. **Blocking the main thread with git blame** — any synchronous CreateProcess on the main thread freezes the IDE for seconds on large files. Thread from day one. File size is unknown at call time, so there is no safe "sync for small files" optimization.

3. **Heavy computation in PaintLine** — PaintLine fires for every visible line on every repaint (scroll, resize, keypress). It must contain only a single TDictionary lookup plus Canvas.TextOut. All formatting, string building, and parsing must be pre-computed in the background thread before results enter the cache.

4. **CreateProcess pipe deadlock on large files** — git blame output exceeds the 4KB pipe buffer on large files. Close the write end of the pipe in the parent process immediately after CreateProcess, then call ReadFile in a loop while the process runs. Never call WaitForSingleObject before ReadFile.

5. **Nil OTA context in PaintLine** — Context, Context.EditView, and Context.EditView.Buffer can all be nil for non-file editor views (start page, diff viewer, binary files). Guard every property access; test by switching rapidly between the IDE start page and a .pas file.

## Implications for Roadmap

The feature dependency chain and architectural layers map directly to a clean 5-phase delivery. Each phase is independently testable before the next begins.

### Phase 1: Package Foundation and OTA Registration

**Rationale:** Everything else depends on a correctly registered, stable plugin. Notifier lifecycle errors cause IDE crashes that make all subsequent development painful. Must be solved first and solved correctly with a centralized notifier manager pattern — not bolted on later.
**Delivers:** Installable BPL that registers with the IDE, appears in splash screen and about box, and cleanly unregisters on unload without IDE crashes.
**Addresses:** Prerequisite for all features; establishes OTA lifecycle patterns the entire codebase will follow.
**Avoids:** Pitfall 1 (leaked notifiers), Pitfall 14 (package naming conflicts).

### Phase 2: Git Blame Data Pipeline

**Rationale:** All visual output depends on blame data. Building and validating the data pipeline in isolation (no rendering) makes debugging far easier. The entire pipeline can be covered by DUnitX unit tests against known git repos without IDE involvement.
**Delivers:** Working async git blame execution, porcelain parser producing TBlameData records, thread-safe cache with normalized path keys, git repo detection, git availability check on startup.
**Uses:** CreateProcess + pipes (Win32), TThread + ForceQueue (RTL), TDictionary + TCriticalSection (RTL).
**Implements:** BlameEngine, BlameParser, BlameCache, Utils, TBlameThread.
**Avoids:** Pitfall 2 (blocking main thread), Pitfall 5 (pipe deadlock), Pitfall 6 (path normalization), Pitfall 7 (git not in PATH), Pitfall 9 (unicode paths).

### Phase 3: Core Visual Output — Inline Blame Rendering

**Rationale:** With cache populated, rendering is the final step to the working MVP. PaintLine implementation must be kept strictly O(1) from the outset. Toggle UX is included here because blame without a way to disable it is not shippable.
**Delivers:** Inline blame annotations visible in the editor after the last code character, showing author and relative time. Toggle via menu and keyboard hotkey.
**Addresses:** All table stakes features — inline rendering, toggle, automatic blame on file open and save.
**Implements:** EditorNotifier (INTACodeEditorEvents), Renderer, KeyBinding, Settings.
**Avoids:** Pitfall 3 (slow PaintLine), Pitfall 4 (nil EditView/Buffer), Pitfall 10 (multiple views of same file), Pitfall 11 (logical vs physical line numbers with code folding), Pitfall 12 (blame text overlapping code), Pitfall 13 (hardcoded colors broken by dark theme).

### Phase 4: Polish — Caching Correctness and Settings

**Rationale:** Phase 3 proves the visual approach works. Phase 4 makes caching robust under real-world conditions (saves, tab switching, concurrent file opens) and adds user-facing configuration that was deferred for speed.
**Delivers:** Robust cache invalidation on save and tab activation, configurable display format, configurable colors with IDE theme awareness, user-accessible settings persistence.
**Addresses:** Differentiator features — configurable format/colors; production-grade cache behavior.
**Avoids:** Pitfall 8 (stale blame data after external git operations), Pitfall 15 (stale cache on branch switch — document as v1 known limitation with a plan for v2).

### Phase 5: Enhanced UX — Tooltip and Commit Detail View

**Rationale:** Core value is proven after Phase 3-4. Phase 5 adds the differentiators that elevate DX.Blame above basic blame viewers, without risking stability of the shipping plugin.
**Delivers:** Hover tooltip showing full commit info (hash, full message, date). Commit detail modal with git show output.
**Addresses:** Differentiator features — tooltip, commit deep-dive.
**Note:** Tooltip implementation mechanism (INTACodeEditorEvents mouse events vs. custom VCL popup window) needs a design spike before this phase is planned.

### Phase Ordering Rationale

- Foundation before features: OTA notifier lifecycle errors cascade across all work that follows; they must be solved once, correctly.
- Data before rendering: The pipeline is fully testable without IDE in the loop; rendering is not.
- Rendering before polish: Visual feedback validates the approach early; cache optimizations are meaningless without working visuals.
- Caching/settings after rendering: Production-grade cache behavior and configuration are quality improvements on a working foundation.
- Tooltip/detail view last: These are differentiators, not table stakes. Ship core value first.

The feature dependency chain (git detection → blame execution → parsing → cache → rendering → toggle) maps directly to phases 2 and 3, confirming this sequence.

### Research Flags

Phases with standard, well-documented patterns (skip additional research):
- **Phase 1:** OTA wizard/notifier registration is thoroughly covered by Embarcadero docs and the DGH OTA Template. No research needed.
- **Phase 2:** CreateProcess pipe patterns and git porcelain format are both fully documented. DUnitX-testable in isolation.
- **Phase 3:** INTACodeEditorEvents PaintLine is documented by Embarcadero. Pitfalls are known and preventable.
- **Phase 4:** Cache and settings patterns are standard Delphi RTL. INTACodeEditorOptions for theme colors needs verification but is low risk.

Phases likely needing deeper research before planning:
- **Phase 5 (Hover tooltip):** The mechanism for tooltip windows tied to editor mouse position is sparsely documented. INTACodeEditorEvents mouse events vs. custom TWinControl overlay approach needs a spike before Phase 5 planning. Flag for `/gsd:research-phase`.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core APIs are Embarcadero-official with full documentation. Git porcelain format is stable and version-independent. Win32 CreateProcess pattern is well-established Delphi practice. No external dependencies introduce uncertainty. |
| Features | HIGH | GitLens provides a mature, battle-tested feature reference. The must-have list is clearly bounded by the dependency chain. Anti-features are explicitly justified to prevent scope creep. |
| Architecture | HIGH | Component boundaries are clear. Data flow is linear and has no cycles. All patterns (TNotifierObject base class, ForceQueue dispatch, TCriticalSection for cache) are standard Delphi RTL/OTA idioms documented by multiple sources. |
| Pitfalls | HIGH | All critical pitfalls are documented by multiple independent sources (Parnassus, David Hoyle, GExperts, Embarcadero, IdeasAwakened). Prevention strategies are specific and directly testable. |

**Overall confidence:** HIGH

### Gaps to Address

- **Hover tooltip mechanism (Phase 5):** The exact API for attaching a tooltip window to an editor view position is not fully documented in official sources. Options include INTACodeEditorEvents mouse events with a custom VCL form, or TWinControl-level tooltip APIs. Needs a spike before Phase 5 planning.
- **INTACodeEditorPaintContext full interface:** The complete property list is not exhaustively documented online. Inspect ToolsAPI.Editor.pas in the Delphi installation during Phase 3 to confirm all available canvas and line rect properties.
- **IDE theme color access:** How to read the current IDE theme's background/foreground colors for adaptive blame text. INTACodeEditorOptions is the likely source but needs verification against a live IDE during Phase 3.
- **Branch-switch detection (v1 limitation):** No OTA event fires on external git branch switches. Accept re-blame-on-tab-activation as sufficient for v1. Evaluate event-based detection (polling git rev-parse HEAD) for v2.
- **Delphi 13 OTA API changes:** No documentation found on OTA changes in Delphi 13 Florence. OTA is additive by convention so breaking changes are unlikely, but verify during Phase 1 setup on Delphi 13.

## Sources

### Primary (HIGH confidence)
- [Embarcadero: ToolsAPI Support for the Code Editor](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) — INTACodeEditorEvents, PaintLine, AllowedEvents, AllowedLineStages
- [Embarcadero: INTACodeEditorEvents.BeginPaint](https://docwiki.embarcadero.com/Libraries/Athens/en/ToolsAPI.Editor.INTACodeEditorEvents.BeginPaint) — method reference
- [Embarcadero: INTACodeEditorEvents.PaintText](https://docwiki.embarcadero.com/Libraries/Athens/en/ToolsAPI.Editor.INTACodeEditorEvents.PaintText) — method reference
- [Embarcadero Blog: Ultimate Open Tools APIs for Decorating Your IDE](https://blogs.embarcadero.com/quickly-learn-about-the-ultimate-open-tools-apis-for-decorating-your-delphi-c-builder-ide/) — OTA painting overview with usage examples
- [Git blame documentation](https://git-scm.com/docs/git-blame) — official porcelain format specification
- [VS Code GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens) — feature reference for user expectations

### Secondary (MEDIUM confidence)
- [Embarcadero OTAPI-Docs (GitHub)](https://github.com/Embarcadero/OTAPI-Docs) — community-maintained OTA reference
- [DGH2112 OTA Template (GitHub)](https://github.com/DGH2112/OTA-Template) — wizard structure and notifier lifecycle reference implementation
- [Dave Hoyle: OTA Blog Series](https://www.davidghoyle.co.uk/WordPress/?page_id=667) — notifier lifecycle, about box, splash screen patterns
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) — common OTA mistakes and solutions
- [IdeasAwakened: CreateProcess with output capture](https://ideasawakened.com/post/use-createprocess-and-capture-the-output-in-windows) — pipe pattern with deadlock avoidance
- [Sebastian Schoener: Win32 Async Redirect](https://blog.s-schoener.com/2024-06-16-stream-redirection-win32/) — pipe buffer overflow documentation
- [Cary Jensen: Editor Key Bindings](http://caryjensen.blogspot.com/2010/06/creating-editor-key-bindings-in-delphi.html) — IOTAKeyboardBinding tutorial

### Tertiary (LOW confidence — historical reference only)
- [Parnassus: Mysteries of IDE Plugins Part 1 & 2](https://parnassus.co/mysteries-of-ide-plugins-painting-in-the-code-editor-part-1/) — documents the pre-11.3 hook approach; useful context but NOT recommended for new code
- [DDetours (GitHub)](https://github.com/MahdiSafsafi/DDetours) — fallback for pre-11.3 support only; last updated 2020, Delphi 13 compatibility unverified; not needed for this project

---
*Research completed: 2026-03-17*
*Ready for roadmap: yes*
