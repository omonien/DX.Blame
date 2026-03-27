# Phase 12: Settings Foundation & Annotation Positioning - Research

**Researched:** 2026-03-26
**Domain:** Delphi IDE Plugin — Settings model extension, annotation X-positioning logic, independent display mode toggles
**Confidence:** HIGH (all findings grounded in direct codebase inspection + established OTA patterns from v1.0/v1.1 research)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DISP-03 | Annotation X position can be caret-anchored (follows caret column) instead of end-of-line | New enum `TDXBlameAnnotationPosition`, branching in `PaintLine` X calculation at Renderer.pas line 310-311 |
| DISP-04 | In all-lines mode, only the caret line uses caret-anchored positioning | Conditional in `PaintLine`: test `LLogicalLine = FCurrentLine` before applying caret X |
| DISP-05 | Inline and statusbar display modes are independently toggleable | Two independent `Boolean` settings (`Enabled` + `ShowInline` or just re-using `Enabled` with new `ShowStatusbar`); Phase 12 scope = the settings model and inline guard; Phase 13 delivers statusbar display itself |
</phase_requirements>

---

## Summary

Phase 12 delivers two independent pieces of work: (1) extending the settings model with two new properties and their INI persistence, and (2) modifying the renderer's `PaintLine` to support caret-anchored annotation X positioning. These changes are tightly scoped and low risk — no new OTA interfaces, no new units, no threading changes.

DISP-03 and DISP-04 are purely a renderer change: the `LAnnotationX` calculation at Renderer.pas lines 310-311 gains a branch conditioned on the new `AnnotationPosition` setting. The all-lines edge case (DISP-04) is already covered by the existing `FCurrentLine` tracking — the renderer already knows which line is the caret line.

DISP-05 requires two new settings properties. Phase 12 adds those properties and the guard in `PaintLine` that skips inline painting when `ShowInline = False`. The statusbar display itself is Phase 13's responsibility. This clean split means Phase 12 can be planned and verified independently without any statusbar infrastructure.

The primary implementation risk is the "flicker vs. fixed-column" semantics of caret-anchored positioning — the pitfall research identified that anchoring to the live caret column causes annotations to dance horizontally during navigation. The correct implementation uses the caret column only as a minimum X anchor, not as the sole X determinator.

**Primary recommendation:** Extend `TDXBlameSettings` with `AnnotationPosition: TDXBlameAnnotationPosition` and `ShowInline: Boolean`, persist both to INI under existing sections, modify one calculation block in `PaintLine`, and guard the renderer's main paint path with `ShowInline`. No new units are needed for Phase 12.

---

## Standard Stack

### Core (unchanged from v1.0/v1.1)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ToolsAPI | Delphi 13 (Studio 37.0) | OTA interfaces | IDE integration — no alternative |
| TIniFile | RTL | Settings persistence | Existing pattern throughout codebase |
| INTACodeEditorPaintContext | ToolsAPI | Paint-time data access for caret position | Already used in Renderer |

### No New Libraries

Phase 12 adds no new dependencies. All APIs used are already imported in the existing units.

**Installation:** No new packages required.

---

## Architecture Patterns

### Pattern 1: Settings Property + INI Persistence

**What:** Every new setting follows the existing `TDXBlameSettings` pattern: private field, public property, string-encoded read in `Load`, string-encoded write in `Save`.
**When to use:** Every configurable behavior.

**Existing pattern in `DX.Blame.Settings.pas` (LoadVCSPreference, lines 169-175):**
```pascal
// In Load:
LPrefStr := LIni.ReadString('VCS', 'Preference', 'Auto');
if SameText(LPrefStr, 'Git') then
  FVCSPreference := vpGit
else if SameText(LPrefStr, 'Mercurial') then
  FVCSPreference := vpMercurial
else
  FVCSPreference := vpAuto;

// In Save:
case FVCSPreference of
  vpAuto: LIni.WriteString('VCS', 'Preference', 'Auto');
  vpGit:  LIni.WriteString('VCS', 'Preference', 'Git');
  vpMercurial: LIni.WriteString('VCS', 'Preference', 'Mercurial');
end;
```

**New settings to add:**

```pascal
// In type section (before TDXBlameSettings):
TDXBlameAnnotationPosition = (apEndOfLine, apCaretColumn);

// In TDXBlameSettings private:
FAnnotationPosition: TDXBlameAnnotationPosition;
FShowInline: Boolean;

// Public properties:
property AnnotationPosition: TDXBlameAnnotationPosition
  read FAnnotationPosition write FAnnotationPosition;
property ShowInline: Boolean read FShowInline write FShowInline;

// Constructor defaults:
FAnnotationPosition := apEndOfLine;  // backward-compatible default
FShowInline := True;                 // backward-compatible default

// In Load (under 'Display' section):
LPosStr := LIni.ReadString('Display', 'AnnotationPosition', 'EndOfLine');
if SameText(LPosStr, 'CaretColumn') then
  FAnnotationPosition := apCaretColumn
else
  FAnnotationPosition := apEndOfLine;

FShowInline := LIni.ReadBool('Display', 'ShowInline', True);

// In Save:
case FAnnotationPosition of
  apEndOfLine:   LIni.WriteString('Display', 'AnnotationPosition', 'EndOfLine');
  apCaretColumn: LIni.WriteString('Display', 'AnnotationPosition', 'CaretColumn');
end;
LIni.WriteBool('Display', 'ShowInline', FShowInline);
```

### Pattern 2: PaintLine Guard for Inline Disable

**What:** When `ShowInline = False`, `PaintLine` exits early before drawing — same pattern as the existing `BlameSettings.Enabled` check.
**When to use:** Whenever a settings flag can completely suppress a rendering path.

**Integration point:** Renderer.pas line 234 (after `Stage <> plsEndPaint` check):
```pascal
if not BlameSettings.Enabled then
  Exit;

// NEW: short-circuit when inline display is disabled
if not BlameSettings.ShowInline then
  Exit;
```

Note: `BlameSettings.Enabled` is the master switch. `ShowInline` only needs to be checked when `Enabled = True` (inline display is individually suppressed but blame is globally on).

### Pattern 3: Caret-Anchored X Position in PaintLine

**What:** When `AnnotationPosition = apCaretColumn`, compute X from caret column rather than end-of-line — but use the maximum of the two to prevent annotation from obscuring code.
**When to use:** Current line only in all-lines mode (DISP-04); all painted lines in current-line mode.

**Current code (Renderer.pas line 310-311):**
```pascal
LAnnotationX := Context.LineState.VisibleTextRect.Right +
  (Context.CellSize.cx * 3);
```

**New code:**
```pascal
// Default: end-of-line + 3-char padding
LAnnotationX := Context.LineState.VisibleTextRect.Right +
  (Context.CellSize.cx * 3);

// Caret-anchored: only for caret line, only when setting is active
if (BlameSettings.AnnotationPosition = apCaretColumn) and
   (LLogicalLine = FCurrentLine) then
begin
  // Compute caret column X. VisibleTextRect.Left accounts for gutter offset.
  // CursorPos.Col is 1-based. Subtract 1 for 0-based pixel math.
  LCaretX := (Context.EditView.CursorPos.Col - 1) * Context.CellSize.cx +
    Context.LineState.VisibleTextRect.Left;
  // Apply padding and enforce minimum = end-of-line
  LAnnotationX := Max(LCaretX + (Context.CellSize.cx * 3), LAnnotationX);
end;
```

**Key insight from Pitfall 6:** Do NOT anchor to raw caret column. The `Max(...)` ensures the annotation never moves left of end-of-line, preventing horizontal jumping when the caret is in the middle of a long line.

**DISP-04 rule:** In `dsAllLines` mode, when `apCaretColumn` is active, the caret-anchored X applies only to the caret line (already handled by the `LLogicalLine = FCurrentLine` condition above). Other lines always use end-of-line X. This is already correct in the pattern shown — no additional branching needed.

### Recommended Project Structure (unchanged)

```
src/
├── DX.Blame.Settings.pas      # +2 properties: AnnotationPosition, ShowInline
├── DX.Blame.Renderer.pas      # +1 guard, +1 X-position branch in PaintLine
├── DX.Blame.Settings.Form.pas # +controls for new settings (UI only)
└── DX.Blame.Settings.Form.dfm # +UI layout additions
```

No new units. No package changes. No new DFM files.

### Anti-Patterns to Avoid

- **Mutually exclusive inline/statusbar modes:** Do NOT create a mode enum `dmInline/dmStatusbar/dmBoth`. Use two independent Booleans. Phase 12 adds `ShowInline`; Phase 13 adds `ShowStatusbar`. They are orthogonal.
- **Anchoring to live caret column without a floor:** Do NOT use raw `CaretColumn * CellWidth` as the X position. Always apply `Max(caretX, endOfLineX)`. Otherwise, the annotation jumps left when the caret is before the end of a long line.
- **Applying caret-anchoring to all lines in dsAllLines mode:** Only the caret line gets caret-anchored. Other lines stay end-of-line. The `LLogicalLine = FCurrentLine` guard handles this.
- **Adding a 'Display' INI section for the first time without checking existing keys:** The `DisplayScope` key already lives in `'General'` section. New display keys (`AnnotationPosition`, `ShowInline`) should go in a new `'Display'` INI section to keep things tidy without conflicting with existing keys.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| X position clamping | Custom min/max logic | `System.Math.Max` | Already in RTL, already used in project |
| INI persistence | Custom file format | `System.IniFiles.TIniFile` | Existing established pattern in Settings.pas |
| Settings UI controls | Custom drawn controls | Standard VCL TCheckBox, TComboBox, TRadioButton | DFM already uses these; TFrame inherits the same approach |

---

## Common Pitfalls

### Pitfall 1: Caret Column X Causes Annotation Flicker (Pitfall 6 from PITFALLS.md)

**What goes wrong:** Anchoring annotation X strictly to the caret column makes annotations dance left/right as the user navigates. Each `InvalidateAllEditors` call redraws with the new caret column.
**Why it happens:** `EditorSetCaretPos` fires on every cursor movement and calls `InvalidateAllEditors`. If X = caret column, every arrow key press visibly shifts the annotation.
**How to avoid:** Use `Max(caretX + padding, endOfLineX)`. The annotation only moves further right than end-of-line when the caret is beyond the text end. For normal navigation within code, the annotation stays at end-of-line position.
**Warning signs:** Annotation appears to "jump" horizontally when pressing Up/Down in a file with varying line lengths.

### Pitfall 2: AnnotationPosition Applied to Wrong Lines in dsAllLines (DISP-04)

**What goes wrong:** Caret-anchored X is applied to ALL lines when `dsAllLines` is active, causing every line's annotation to snap to the caret column position simultaneously.
**Why it happens:** Missing the `LLogicalLine = FCurrentLine` guard in the caret-anchoring branch.
**How to avoid:** The `Max(...)` caret-anchor branch MUST be guarded by `LLogicalLine = FCurrentLine`. This is already shown in the Pattern 3 code above.
**Warning signs:** In all-lines mode, all annotations align to the same X column (the caret column) instead of their respective end-of-line positions.

### Pitfall 3: ShowInline Guard Placed After Cache Lookup

**What goes wrong:** The `ShowInline = False` guard is placed after the blame data cache lookup and string formatting, wasting work on every paint cycle when inline is disabled.
**Why it happens:** Guard added as an afterthought at the end of `PaintLine`.
**How to avoid:** Place the `ShowInline` check immediately after the `Enabled` check (lines 234-235 of Renderer.pas), before any cache lookups or string operations.

### Pitfall 4: New Settings Not Loaded in Constructor Default Path

**What goes wrong:** New settings fields (`FAnnotationPosition`, `FShowInline`) are set in the constructor but `Load` is called at the end of the constructor. If `Load` doesn't include the new keys, the constructor defaults persist correctly — but if the INI file exists without the new keys, the `ReadString`/`ReadBool` with defaults handles it. This is fine. However, if `Load` is called before the fields are initialized in the constructor, there is no crash because `TIniFile.ReadString` with a default value always returns the default for missing keys.
**How to avoid:** Always set field defaults in the constructor BEFORE `Load` is called (constructor already calls `Load` at end, so set defaults in constructor body). This is the existing pattern.
**Warning signs:** Settings reset to wrong values after first save-reload cycle.

### Pitfall 5: 'Display' Section Conflicts with Existing 'General' Section Keys

**What goes wrong:** Existing `DisplayScope` setting lives in `'General'` section (Renderer.pas L144). If new keys are mistakenly put in a `'General'` section, they may shadow or be confused with existing keys in a future merge.
**How to avoid:** New `AnnotationPosition` and `ShowInline` keys go in a new `'Display'` INI section (separate from `'General'`). The existing `DisplayScope` stays in `'General'` for backward compatibility — do NOT move it.

---

## Code Examples

### Settings Model Extension (verified from Settings.pas direct inspection)

```pascal
// DX.Blame.Settings.pas — type declarations to add before TDXBlameSettings
TDXBlameAnnotationPosition = (apEndOfLine, apCaretColumn);

// Private fields to add to TDXBlameSettings:
FAnnotationPosition: TDXBlameAnnotationPosition;
FShowInline: Boolean;

// Constructor defaults (add to constructor body, before Load call):
FAnnotationPosition := apEndOfLine;
FShowInline := True;

// Load method additions (new 'Display' section):
LPosStr := LIni.ReadString('Display', 'AnnotationPosition', 'EndOfLine');
if SameText(LPosStr, 'CaretColumn') then
  FAnnotationPosition := apCaretColumn
else
  FAnnotationPosition := apEndOfLine;
FShowInline := LIni.ReadBool('Display', 'ShowInline', True);

// Save method additions:
case FAnnotationPosition of
  apEndOfLine:   LIni.WriteString('Display', 'AnnotationPosition', 'EndOfLine');
  apCaretColumn: LIni.WriteString('Display', 'AnnotationPosition', 'CaretColumn');
end;
LIni.WriteBool('Display', 'ShowInline', FShowInline);
```

### PaintLine Modification (verified from Renderer.pas direct inspection)

```pascal
// After existing Enabled check (Renderer.pas ~line 234):
if not BlameSettings.Enabled then
  Exit;
// NEW:
if not BlameSettings.ShowInline then
  Exit;

// Replace lines 310-311 in PaintLine (the LAnnotationX calculation):
// BEFORE:
//   LAnnotationX := Context.LineState.VisibleTextRect.Right + (Context.CellSize.cx * 3);
// AFTER:
LAnnotationX := Context.LineState.VisibleTextRect.Right + (Context.CellSize.cx * 3);
if (BlameSettings.AnnotationPosition = apCaretColumn) and
   (LLogicalLine = FCurrentLine) and
   (Context.EditView <> nil) then
begin
  LCaretX := (Context.EditView.CursorPos.Col - 1) * Context.CellSize.cx +
    Context.LineState.VisibleTextRect.Left;
  LAnnotationX := Max(LCaretX + (Context.CellSize.cx * 3), LAnnotationX);
end;
```

Note: `System.Math` must be added to Renderer.pas `uses` for `Max`. Check if already present.

### Settings Form UI Controls (for Settings.Form.pas / DFM)

Two new controls needed in the GroupBoxDisplay group:
1. A `TComboBox` for AnnotationPosition with items: `'End of line (default)'`, `'Caret-anchored'`
2. A `TCheckBox` for ShowInline: `'Show inline annotations'`

The existing `GroupBoxDisplay` group (DFM lines 135-160) contains only the DisplayScope radio buttons. Both new controls can be added to this group, expanding the group height from 65px to ~110px.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| End-of-line only annotation X | Caret-anchored option (DISP-03) | Phase 12 | Reduces horizontal jumping for users who hate long lines |
| Single display mode (inline only) | Independent inline + statusbar toggles | Phase 12 adds model; Phase 13 adds statusbar | Users can suppress inline when statusbar is enabled |

**No deprecated APIs involved in Phase 12.**

---

## Open Questions

1. **`System.Math` import in Renderer.pas**
   - What we know: `Max` is in `System.Math`. Current Renderer.pas imports (`System.Classes`, `System.SysUtils`, `System.Types`, `Vcl.Controls`, `Vcl.Graphics`, `Winapi.Windows`, `ToolsAPI`, `ToolsAPI.Editor`) do not include it.
   - What's unclear: Whether `Max` for integers is available via another already-imported unit.
   - Recommendation: Add `System.Math` to Renderer.pas implementation uses clause. No risk.

2. **`Context.EditView.CursorPos.Col` availability in paint thread context**
   - What we know: `PaintLine` is called synchronously during the paint cycle. `FCurrentLine` is already read from `Context.EditView.CursorPos.Line` at Renderer.pas line 245. `CursorPos.Col` is the same interface property.
   - What's unclear: Whether `CursorPos.Col` is always valid (non-zero) when called during `PaintLine`.
   - Recommendation: Guard with `Context.EditView.CursorPos.Col > 0` before computing `LCaretX`. If zero or nil, fall back to end-of-line. Confidence HIGH — same pattern already used for `.Line`.

3. **Settings Form: which plan owns the UI controls?**
   - What we know: Phase 12 has two plans: 12-01 (Settings properties + annotation positioning) and 12-02 (Independent display mode toggles).
   - Recommendation: Plan 12-01 adds `TDXBlameAnnotationPosition` property + Renderer change + UI control for annotation position. Plan 12-02 adds `ShowInline`/`ShowStatusbar` properties + Renderer guard + UI controls for both toggles. The Settings Form UI updates ship with their respective plans so each plan is independently verifiable.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | DUnitX (confirmed from REQUIREMENTS.md rule 7, project structure) |
| Config file | `tests/` directory — none detected yet in this repo (see Wave 0 Gaps) |
| Quick run command | `dcc32 DX.Blame.Tests.dpr && DX.Blame.Tests.exe` (once test project exists) |
| Full suite command | same |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Notes |
|--------|----------|-----------|-------|
| DISP-03 | `AnnotationPosition = apCaretColumn` setting persists to INI and loads back correctly | Unit | `TDXBlameSettings.Save` + `Load` round-trip |
| DISP-03 | `LAnnotationX` is >= end-of-line X when caret-anchored | Unit | Renderer logic test with mock context |
| DISP-04 | Non-caret lines keep end-of-line X when `apCaretColumn` active in `dsAllLines` mode | Unit | Renderer test: paint two lines, verify only caret line gets adjusted X |
| DISP-05 | `ShowInline = False` causes `PaintLine` to exit before drawing | Unit | Renderer test: mock canvas should receive no TextOut calls |
| DISP-05 | `ShowInline` setting persists to INI correctly | Unit | Settings round-trip test |

**Note on testability:** The renderer's `PaintLine` method takes `INTACodeEditorPaintContext` which is an OTA interface. These tests are most practical as integration-level tests verifiable by visual inspection during IDE execution, not pure unit tests. The settings model (DISP-03, DISP-05 persistence) is fully unit-testable without OTA.

### Sampling Rate

- **Per task commit:** Visual verification in IDE: activate caret-anchored mode, navigate through lines of varying length, confirm annotation behavior
- **Per wave merge:** Full settings round-trip: change both new settings, close IDE, reopen, verify settings restored
- **Phase gate:** All visual behaviors match DISP-03/04/05 success criteria before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/DX.Blame.Settings.Tests.pas` — covers Settings model round-trip for DISP-03, DISP-05
- [ ] DUnitX test project (`tests/DX.Blame.Tests.dpr`) — not yet present in repository

*(If tests infrastructure is not set up by Phase 12, visual IDE verification is the gate. The settings unit tests are straightforward and worth adding.)*

---

## Sources

### Primary (HIGH confidence)

- `src/DX.Blame.Renderer.pas` (direct inspection) — PaintLine logic, existing X calculation at lines 310-311, FCurrentLine tracking at line 245, Enabled guard at line 234
- `src/DX.Blame.Settings.pas` (direct inspection) — existing INI pattern, VCSPreference as canonical example, constructor defaults, Load/Save structure
- `src/DX.Blame.Settings.Form.pas` + `.dfm` (direct inspection) — current UI controls and LoadFromSettings/SaveToSettings patterns to extend
- `src/DX.Blame.Registration.pas` (direct inspection) — finalization order (8 steps), no INTAAddInOptions in Phase 12 scope
- `.planning/research/FEATURES.md` — feature analysis, caret-anchored implementation notes
- `.planning/research/ARCHITECTURE.md` — build order, modified units list, pattern examples
- `.planning/research/PITFALLS.md` — Pitfall 6 (flicker), Pitfall 9 (settings dual state)

### Secondary (MEDIUM confidence)

- `.planning/research/PITFALLS.md` — Pitfall 14 (X position overflow) — annotation should not exceed client width; handled by `Max` pattern
- `.planning/REQUIREMENTS.md` — DISP-03, DISP-04, DISP-05 definitions

### Tertiary (LOW confidence)

- None — all findings are from direct source inspection. No speculative claims.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — no new libraries; all existing, inspected code
- Architecture: HIGH — both modified units inspected; changes are surgical (one function, a few properties)
- Pitfalls: HIGH — grounded in direct code path analysis (the Renderer.pas paint cycle is read in full)

**Research date:** 2026-03-26
**Valid until:** 2026-04-30 (stable codebase, no external dependencies)
