---
phase: 13-statusbar-display-navigation
verified: 2026-03-26T22:30:00Z
status: human_needed
score: 8/8 must-haves verified
re_verification: false
human_verification:
  - test: "Statusbar panel appears and updates on cursor movement"
    expected: "After enabling 'Show in Statusbar' in settings, a panel appears in the IDE statusbar showing author, relative time, and summary for the current caret line; moving the cursor to a different line updates the text"
    why_human: "Requires live IDE with blame-cached file — GOnCaretMoved fires via paint-cycle lag that cannot be simulated statically"
  - test: "Clicking statusbar blame panel opens commit detail popup"
    expected: "Left-clicking the blame panel produces a TDXBlamePopup showing commit details; click outside the panel chains to the original handler"
    why_human: "Panel hit-test arithmetic (summing panel widths) and popup display require runtime VCL layout"
  - test: "Statusbar panel survives editor window close and reopen without access violation"
    expected: "FreeNotification fires correctly, nulling FPanel/FStatusBar/FPanelIndex; no AV on IDE edit window destruction"
    why_human: "FreeNotification lifecycle can only be exercised in a running IDE"
  - test: "ShowStatusbar setting persists across IDE restart"
    expected: "After enabling 'Show in Statusbar', closing and reopening Delphi, the statusbar still shows blame info (setting was persisted to INI under [Display] ShowStatusbar)"
    why_human: "INI round-trip requires actual file write and reload"
  - test: "Context menu shows Enable/Disable Blame with Ctrl+Alt+B hint and correct checkmark"
    expected: "Right-clicking in the editor shows the toggle item with the keyboard hint and a checkmark when blame is enabled; checkmark disappears when blame is disabled"
    why_human: "Requires live IDE editor context menu invocation"
  - test: "Context menu toggle syncs Tools menu checkmark"
    expected: "After toggling blame via context menu, the Tools > DX Blame > Enable Blame checkmark reflects the new state"
    why_human: "GOnContextMenuToggle -> SyncEnableBlameCheckmark requires runtime menu state"
  - test: "Navigating to historical revision scrolls to and centers source line"
    expected: "Right-clicking an annotated line and choosing 'Show revision...' opens the temp file AND the editor is centered on the originating source line, not line 1"
    why_human: "FindModule + SetCursorPos + Center requires live IOTAModuleServices and editor rendering"
  - test: "DetachContextMenu restores OnPopup to nil when no original handler existed"
    expected: "After unloading the BPL, right-clicking in the editor does not invoke DX Blame's OnEditorPopup handler"
    why_human: "Requires BPL unload in live IDE to confirm hook is fully removed"
---

# Phase 13: Statusbar Display and Navigation Verification Report

**Phase Goal:** Users can see blame info in the statusbar and toggle blame from the context menu, with historical revision navigation scrolling to the source line
**Verified:** 2026-03-26T22:30:00Z
**Status:** human_needed (all automated checks passed)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Statusbar panel shows author + relative time + summary for current caret line | VERIFIED | `UpdateForLine` calls `FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings)` and assigns to `FPanel.Text` (Statusbar.pas:208-209) |
| 2 | Statusbar text updates when cursor moves to a different line | VERIFIED | `GOnCaretMoved` called in `EditorSetCaretPos` after `InvalidateAllEditors` (Renderer.pas:188-189); wired to `OnCaretMovedHandler` -> `GStatusbar.UpdateForLine` in Registration.pas:312 |
| 3 | Statusbar panel is empty when no blame data is available | VERIFIED | `UpdateForLine` clears `FPanel.Text` and sets `FHasBlameData := False` on all guard exits: nil panel, ShowStatusbar=False, empty filename, cache miss, out-of-range line (Statusbar.pas:175-205) |
| 4 | Clicking the statusbar blame panel opens the commit detail popup | VERIFIED | `HandleStatusBarMouseDown` hit-tests panel bounds, creates/reuses `TDXBlamePopup(FPopup)`, calls `ShowForCommit` or `UpdateContent` on left-click hit (Statusbar.pas:234-262) |
| 5 | Statusbar panel survives editor window destruction without AV | VERIFIED | `Notification` override handles `opRemove` for `FStatusBar`, nils all references (Statusbar.pas:107-119); `FreeNotification` registered in `AttachToStatusBar` (Statusbar.pas:131) |
| 6 | ShowStatusbar setting defaults to False and persists to INI | VERIFIED | `FShowStatusbar := False` in constructor (Settings.pas:132); `ReadBool('Display', 'ShowStatusbar', False)` in Load (Settings.pas:199); `WriteBool('Display', 'ShowStatusbar', FShowStatusbar)` in Save (Settings.pas:252) |
| 7 | Context menu shows Enable/Disable Blame toggle with Ctrl+Alt+B hint and checkmark reflecting state | VERIFIED | `OnEditorPopup` creates `GEnableBlameItem` with `'Enable Blame'#9'Ctrl+Alt+B'` / `'Disable Blame'#9'Ctrl+Alt+B'` caption and `Checked := BlameSettings.Enabled` (Navigation.pas:361-368); `OnToggleBlameClick` fires `GOnContextMenuToggle` and `InvalidateAllEditors` (Navigation.pas:320-327) |
| 8 | Navigating to a historical revision scrolls the opened temp file to the source line and centers it | VERIFIED | `NavigateToRevision` has `ALineNumber: Integer = 0` param; scroll block calls `FindModule`, `SetCursorPos`, `Center`, `Paint` when `ALineNumber > 0` (Navigation.pas:186-212); `OnRevisionClick` passes `LLineInfo.FinalLine` (Navigation.pas:266-267) |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/DX.Blame.Statusbar.pas` | TDXBlameStatusbar with panel lifecycle, FreeNotification, UpdateForLine, HandlePanelClick | VERIFIED | 271 lines; all required methods implemented and substantive |
| `src/DX.Blame.Settings.pas` | FShowStatusbar field, ShowStatusbar property, INI persistence in [Display] section | VERIFIED | Field at line 58, property at line 90, default False at line 132, Load at line 199, Save at line 252 |
| `src/DX.Blame.Renderer.pas` | GOnCaretMoved procedure variable, call from EditorSetCaretPos | VERIFIED | Variable declared at line 110 (interface section); called at lines 188-189 in EditorSetCaretPos |
| `src/DX.Blame.Registration.pas` | Statusbar init/wiring/cleanup in Register and finalization | VERIFIED | GStatusbar var at line 51; init/attach at lines 302-308; GOnCaretMoved wired at line 312; cleanup at lines 344-348 |
| `src/DX.Blame.Navigation.pas` | GEnableBlameItem, OnToggleBlameClick, GOnContextMenuToggle callback, NavigateToRevision ALineNumber param, auto-scroll | VERIFIED | GEnableBlameItem at line 97; OnToggleBlameClick at line 320; GOnContextMenuToggle interface var at line 56; NavigateToRevision signature with ALineNumber=0 at line 30/134; scroll block at lines 186-212 |
| `src/DX.Blame.dpk` | Contains DX.Blame.Statusbar | VERIFIED | Line 62: `DX.Blame.Statusbar in 'DX.Blame.Statusbar.pas'` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DX.Blame.Renderer.pas` | `DX.Blame.Statusbar.pas` | `GOnCaretMoved` callback wired in Registration.pas | WIRED | `GOnCaretMoved` declared in Renderer interface; `OnCaretMovedHandler` wrapper in Registration.pas assigned at line 312; wrapper calls `GStatusbar.UpdateForLine` |
| `DX.Blame.Statusbar.pas` | `DX.Blame.Popup.pas` | `HandleStatusBarMouseDown` calls `ShowForCommit` | WIRED | `LPopup.ShowForCommit(LLineInfo, LScreenPos, LRepoRoot, LRelPath)` at Statusbar.pas:260 |
| `DX.Blame.Statusbar.pas` | `DX.Blame.Formatter.pas` | `FormatBlameAnnotation` for statusbar text | WIRED | `FormatBlameAnnotation(LBlameData.Lines[LLineIndex], BlameSettings)` at Statusbar.pas:208 |
| `DX.Blame.Navigation.pas` | `DX.Blame.Registration.pas` | `GOnContextMenuToggle` callback (avoids circular dependency) | WIRED | `GOnContextMenuToggle: TProc` in Navigation.pas interface; assigned `DX.Blame.Navigation.GOnContextMenuToggle := SyncEnableBlameCheckmark` in Registration.pas:296; invoked in `OnToggleBlameClick` at Navigation.pas:324 |
| `DX.Blame.Navigation.pas OnRevisionClick` | `NavigateToRevision` | `LLineInfo.FinalLine` passed as `ALineNumber` | WIRED | Two-line call at Navigation.pas:266-267: `NavigateToRevision(LFileName, LLineInfo.CommitHash, BlameEngine.RepoRoot, LLineInfo.FinalLine)` |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| DISP-01 | 13-01 | Statusbar shows current line's blame info (author, relative time, summary) updating on cursor movement | SATISFIED | `TDXBlameStatusbar.UpdateForLine` formats via `FormatBlameAnnotation` and updates panel on every `GOnCaretMoved` callback; verified in Settings.pas (ShowStatusbar), Renderer.pas (callback), Statusbar.pas (panel update) |
| DISP-02 | 13-01 | Clicking statusbar blame opens commit detail popup | SATISFIED | `HandleStatusBarMouseDown` performs panel hit-test, creates/reuses `TDXBlamePopup`, calls `ShowForCommit` on left-click hit with valid blame data |
| NAV-01 | 13-02 | Editor context menu has "Enable/Disable Blame (Ctrl+Alt+B)" toggle with checkmark | SATISFIED | `GEnableBlameItem` injected in `OnEditorPopup` with tab-separated hint and `Checked := BlameSettings.Enabled`; `OnToggleBlameClick` toggles state, saves, fires `GOnContextMenuToggle`, invalidates editors |
| NAV-02 | 13-02 | Navigating to historical revision scrolls to and centers the source line | SATISFIED | `NavigateToRevision` extended with `ALineNumber: Integer = 0`; scroll block uses `FindModule + SetCursorPos + Center`; `OnRevisionClick` passes `LLineInfo.FinalLine` |

All four requirements mapped to Phase 13 are implemented. No orphaned requirements found (DISP-03, DISP-04, DISP-05 belong to Phase 12; SETT-01-03 belong to Phase 14).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/DX.Blame.Registration.pas` | 66, 125, 274 | "placeholder" in comments | Info | Legacy Phase 1 wizard comment; not new Phase 13 code; no implementation impact |

No blocker or warning anti-patterns in Phase 13 code. The "placeholder" occurrences are in pre-existing comments about the Phase 1 wizard `Execute` no-op, not in any Phase 13 implementation.

### Human Verification Required

#### 1. Statusbar Panel Attaches and Updates in Live IDE

**Test:** Install the BPL in Delphi 13, enable "Show in Statusbar" in Tools > DX Blame > Settings, open a blamed source file, move the cursor between lines.
**Expected:** A panel appears in the IDE statusbar showing "Author, N hours ago, commit summary" text that changes as the cursor moves to lines with different blame data.
**Why human:** `GOnCaretMoved` fires with `FCurrentLine` from the previous paint cycle — the one-cycle lag and panel attachment to the live `TopEditWindow.StatusBar` require IDE execution to confirm.

#### 2. Statusbar Panel Click Opens Popup

**Test:** With blame data loaded and "Show in Statusbar" enabled, left-click the blame text in the statusbar.
**Expected:** A commit detail popup appears showing commit hash, author, date, and summary.
**Why human:** Panel hit-test arithmetic sums `Panels[0..FPanelIndex-1].Width` values — actual IDE panel widths may differ from design-time assumptions.

#### 3. Statusbar Survives Edit Window Close/Reopen

**Test:** With the plugin loaded and statusbar panel active, close all editor tabs (destroying the edit window form) and reopen a source file.
**Expected:** No access violation; panel may not re-attach (known limitation: single TopEditWindow), but no crash.
**Why human:** `FreeNotification` -> `Notification(opRemove)` path requires live VCL object destruction.

#### 4. ShowStatusbar Setting Persists Across IDE Restart

**Test:** Enable "Show in Statusbar", click OK, close and reopen Delphi 13.
**Expected:** The setting is still enabled after restart (INI file under `%APPDATA%\DX.Blame\settings.ini` has `ShowStatusbar=True` in `[Display]` section).
**Why human:** Requires actual INI write and `TDXBlameSettings.Load` on IDE startup.

#### 5. Context Menu Toggle Correct Caption and Checkmark

**Test:** Right-click in an editor with blame enabled. Observe the context menu. Then toggle blame off, right-click again.
**Expected:** When blame is enabled: "Disable Blame    Ctrl+Alt+B" with checkmark. When blame is disabled: "Enable Blame    Ctrl+Alt+B" without checkmark.
**Why human:** Caption switching and checkmark rendering require live VCL context menu display.

#### 6. Context Menu Toggle Syncs Tools Menu Checkmark

**Test:** After toggling blame via the context menu, open Tools > DX Blame.
**Expected:** The "Enable Blame" item checkmark matches the new blame state.
**Why human:** `GOnContextMenuToggle -> SyncEnableBlameCheckmark -> GEnableBlameItem.Checked` requires runtime menu state propagation.

#### 7. Revision Navigation Scrolls to Source Line

**Test:** Open a blamed file, right-click on an annotated line, click "Show revision [time]".
**Expected:** The temp file opens and the editor scrolls to and centers the originating line (not line 1).
**Why human:** `FindModule` may return nil if `OpenFile` is asynchronous (documented risk); `SetCursorPos + Center` requires live `IOTAEditView`.

#### 8. DetachContextMenu Cleanly Removes Hook After BPL Unload

**Test:** Unload DX.Blame from Component > Install Packages > Remove. Right-click in the editor.
**Expected:** No DX Blame items appear in the context menu; no AV during unload.
**Why human:** `DetachContextMenu` Pitfall 3 fix (`GHookedPopup.OnPopup := GOriginalOnPopup` unconditionally) requires live BPL unload to exercise the nil-restore path.

### Gaps Summary

No gaps found. All automated verification checks passed:
- All 8 observable truths confirmed by source code inspection
- All 6 artifacts exist, are substantive (not stubs), and are wired
- All 5 key links verified via grep (wiring confirmed)
- All 4 requirements (DISP-01, DISP-02, NAV-01, NAV-02) satisfied
- No blocker or warning anti-patterns in Phase 13 code
- Both commit hashes from summaries (`bc21822`, `4688ba8`) confirmed in git log

Phase goal is conditionally achieved pending human verification of 8 IDE runtime behaviors. The automated evidence is strong — the remaining items are inherently runtime-only (live IDE, VCL layout, BPL lifecycle).

---

_Verified: 2026-03-26T22:30:00Z_
_Verifier: Claude (gsd-verifier)_
