# Phase 9: Mercurial Provider - Research

**Researched:** 2026-03-24
**Domain:** Mercurial CLI (hg annotate, hg log, hg diff, hg cat) integration into IVCSProvider for Delphi IDE plugin
**Confidence:** HIGH

## Summary

Phase 9 replaces the `ENotSupportedException` stubs in `THgProvider` with working implementations of all six IVCSProvider blame operations: `ExecuteBlame`, `ParseBlameOutput`, `GetCommitMessage`, `GetFileDiff`, `GetFullDiff`, and `GetFileAtRevision`. The discovery methods (`FindExecutable`, `FindRepoRoot`, `ClearDiscoveryCache`) already work from Phase 8 and remain unchanged.

The core challenge is `hg annotate -T` with a custom template that produces machine-parseable output mapping to `TBlameLineInfo`. Unlike Git's `--line-porcelain` (a well-defined key-value format), Mercurial's annotate template system is labeled EXPERIMENTAL and requires crafting a delimiter-based output format. The recommended approach uses a custom template with `{lines % ...}` iteration that emits one line per annotation with pipe-delimited fields: `{node}|{user}|{date|hgdate}|{lineno}|{line}`. The remaining operations (`hg log -r`, `hg diff -c`, `hg cat -r`) are straightforward CLI calls that mirror the Git provider's pattern of creating a `TVCSProcess`, executing the command, and returning stdout.

The architecture follows the exact same pattern as `TGitProvider`: a new `DX.Blame.Hg.Process` unit (thin TVCSProcess subclass), a new `DX.Blame.Hg.Blame` unit (template command + parser), and a new `DX.Blame.Hg.Types` unit (Mercurial-specific constants). The existing `THgProvider` gets its stub methods replaced with real implementations delegating to these new units.

**Primary recommendation:** Create three new Hg units (Process, Blame, Types) mirroring the Git unit structure, then replace all six stub methods in THgProvider with delegating implementations. Use `hg annotate -T` with a pipe-delimited custom template for blame output parsing.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HGB-01 | User sees inline blame annotations for Mercurial-tracked files via hg annotate -T | Architecture Patterns: `hg annotate -T "{lines % '{node}\|{user}\|{date\|hgdate}\|{lineno}\|{line}'}"` produces parseable per-line output; parser splits by pipe delimiter and populates TBlameLineInfo |
| HGB-02 | User can click annotation to see commit details via hg log | Architecture Patterns: `hg log -r <hash> -T "{desc}"` retrieves full commit message; matches GetCommitMessage interface |
| HGB-03 | User can view RTF color-coded diff for Mercurial commits via hg diff -c | Architecture Patterns: `hg diff -c <hash> <filepath>` for file diff, `hg diff -c <hash>` for full diff; output is unified diff format compatible with existing RTF colorizer |
| HGB-04 | User can navigate to annotated revision via hg cat -r | Architecture Patterns: `hg cat -r <hash> <filepath>` retrieves file content at revision; matches GetFileAtRevision interface |
| HGB-05 | Mercurial blame uses dedicated template-based parser | Architecture Patterns: DX.Blame.Hg.Blame unit with its own ParseHgAnnotateOutput procedure; completely separate from Git's porcelain parser |
</phase_requirements>

## Standard Stack

### Core (no new libraries -- all Delphi RTL + existing project patterns)

| Feature | Unit | Purpose | Why Standard |
|---------|------|---------|--------------|
| Process execution | DX.Blame.VCS.Process (TVCSProcess) | Execute hg commands, capture stdout | Already used by Hg.Discovery |
| Blame parsing | DX.Blame.Hg.Blame (NEW) | Parse hg annotate template output | Dedicated per HGB-05, mirrors Git.Blame |
| Process wrapper | DX.Blame.Hg.Process (NEW) | Thin TVCSProcess subclass | Mirrors Git.Process pattern |
| Constants | DX.Blame.Hg.Types (NEW) | Hg-specific sentinel values | Mirrors Git.Types pattern |
| String splitting | System.SysUtils | Parse pipe-delimited template output | RTL standard |
| Date conversion | System.DateUtils | UnixToDateTime for hgdate timestamps | Already used in Git.Blame parser |

### No New Dependencies

This phase adds zero new package dependencies. All work uses RTL and existing project units.

## Architecture Patterns

### New Unit Structure

```
src/
  DX.Blame.Hg.Types.pas       # NEW: cHgUncommittedHash, cHgNotCommittedAuthor (MOVE from Hg.Provider impl)
  DX.Blame.Hg.Process.pas     # NEW: THgProcess subclass of TVCSProcess
  DX.Blame.Hg.Blame.pas       # NEW: ParseHgAnnotateOutput (template-based parser)
  DX.Blame.Hg.Provider.pas    # MODIFIED: Replace all 6 stubs with real implementations
  DX.Blame.Hg.Discovery.pas   # UNCHANGED: Already functional from Phase 8
```

### Pattern 1: Mercurial Annotate with Custom Template (HGB-01, HGB-05)

**What:** Execute `hg annotate` with a `-T` template that produces machine-parseable output.
**When to use:** Called by THgProvider.ExecuteBlame.

Mercurial's `hg annotate -T` (EXPERIMENTAL) accepts template strings with a `{lines % '...'}` iteration syntax. Each line entry provides sub-keywords: `{node}` (40 hex), `{user}`, `{date}`, `{rev}`, `{lineno}`, `{line}`, `{path}`.

**Template design:**
```
hg annotate -T "{lines % '{node}|{user}|{date|hgdate}|{lineno}|{line}'}" <filepath>
```

This produces output like:
```
a1b2c3d4e5f6...40chars...|John Doe <john@example.com>|1679000000 -18000|1|first line of code
a1b2c3d4e5f6...40chars...|John Doe <john@example.com>|1679000000 -18000|2|second line of code
```

**Key design decisions:**
- Use pipe `|` as delimiter because it rarely appears in author names or email addresses
- Use `{date|hgdate}` filter which outputs Unix timestamp + timezone offset (e.g., `1679000000 -18000`), directly convertible via `UnixToDateTime`
- Use `{node}` for the full 40-char hash (not `{node|short}`) to match TBlameLineInfo.CommitHash field width
- The `{line}` keyword includes the trailing newline, so the template does NOT need an explicit `\n`
- Empty lines still produce annotation output (node/user/date with empty content after last pipe)

**Fallback concern:** The `-T` template option is marked EXPERIMENTAL in Mercurial docs. If a user's Mercurial version does not support it, the command will fail with a non-zero exit code. The existing retry mechanism in TBlameEngine handles this gracefully -- after one retry failure, it logs the error. No special fallback parser is needed; the user simply sees no annotations (same as if hg.exe is missing).

```pascal
// DX.Blame.Hg.Blame.pas -- Template command and parser
const
  cHgAnnotateTemplate =
    '{lines % ''{node}|{user}|{date|hgdate}|{lineno}|{line}''}';

// Called by THgProvider.ExecuteBlame
function BuildAnnotateArgs(const ARelPath: string): string;
begin
  Result := 'annotate -T "' + cHgAnnotateTemplate + '" "' + ARelPath + '"';
end;
```

### Pattern 2: Parsing Hg Annotate Template Output (HGB-05)

**What:** Parse the pipe-delimited template output into TArray<TBlameLineInfo>.
**When to use:** Called by THgProvider.ParseBlameOutput.

```pascal
procedure ParseHgAnnotateOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);
// For each line in AOutput:
//   1. Find first '|' -> extract 40-char node hash
//   2. Find second '|' -> extract user (author name, may include email)
//   3. Find third '|' -> extract hgdate (Unix timestamp + offset)
//   4. Find fourth '|' -> extract lineno
//   5. Remainder is line content (ignored for blame purposes)
//   6. Check if node = cHgUncommittedHash -> mark IsUncommitted
//   7. Parse user: extract name before '<' if email present
//   8. Parse hgdate: split by space, first token is Unix timestamp
```

**Uncommitted detection:** Mercurial uses `ffffffffffff` (12 f's) as the short form for uncommitted. The full 40-char node for uncommitted working directory changes is `ffffffffffffffffffffffffffffffffffffffff` (40 f's). The parser must check for this sentinel value.

**Author parsing:** Mercurial's `{user}` returns the full "Name <email>" format. For TBlameLineInfo, split into Author (name part) and AuthorMail (email part). If no email angle brackets present, use the full string as Author.

### Pattern 3: Commit Message Retrieval (HGB-02)

**What:** Retrieve the full commit message for a specific changeset.
**When to use:** Called by THgProvider.GetCommitMessage.

```pascal
// hg log -r <hash> -T "{desc}"
function THgProvider.GetCommitMessage(const ARepoRoot, ACommitHash: string;
  out AMessage: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('log -r ' + ACommitHash + ' -T "{desc}"', LOutput) = 0;
    if Result then
      AMessage := Trim(LOutput);
  finally
    LProcess.Free;
  end;
end;
```

**Note:** `{desc}` returns the full multi-line commit message. `{desc|firstline}` would return only the first line. We want the full message for the popup detail view.

### Pattern 4: Diff Retrieval (HGB-03)

**What:** Retrieve unified diff output for a changeset.
**When to use:** Called by THgProvider.GetFileDiff and GetFullDiff.

```pascal
// File-specific diff: hg diff -c <hash> <filepath>
function THgProvider.GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
  out ADiff: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('diff -c ' + ACommitHash + ' "' + ARelativePath + '"',
      LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;

// Full diff: hg diff -c <hash>
function THgProvider.GetFullDiff(const ARepoRoot, ACommitHash: string;
  out ADiff: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('diff -c ' + ACommitHash, LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;
```

**Key difference from Git:** Git uses `git show <hash> -- <path>` which outputs commit metadata + diff. Mercurial's `hg diff -c <hash>` outputs only the unified diff (no commit header). The existing RTF diff colorizer in DX.Blame.Diff.Form processes unified diff format, so this difference is transparent -- both Git and Hg produce `---`/`+++`/`@@`/`+`/`-` lines.

### Pattern 5: File at Revision (HGB-04)

**What:** Retrieve file content at a specific changeset.
**When to use:** Called by THgProvider.GetFileAtRevision.

```pascal
// hg cat -r <hash> <filepath>
function THgProvider.GetFileAtRevision(const ARepoRoot, ACommitHash,
  ARelativePath: string; out AContent: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('cat -r ' + ACommitHash + ' "' + ARelativePath + '"',
      LOutput) = 0;
    if Result then
      AContent := LOutput;
  finally
    LProcess.Free;
  end;
end;
```

### Pattern 6: THgProcess Subclass

**What:** Thin TVCSProcess subclass for Mercurial, mirroring TGitProcess.
**When to use:** All THgProvider methods that execute hg commands.

```pascal
// DX.Blame.Hg.Process.pas
type
  THgProcess = class(TVCSProcess)
  public
    constructor Create(const AHgPath, AWorkDir: string);
    property HgPath: string read FExePath;
  end;
```

### Pattern 7: Hg Types Constants

**What:** Mercurial-specific sentinel constants, extracted from Hg.Provider implementation section.
**When to use:** By Hg.Blame parser for uncommitted detection.

```pascal
// DX.Blame.Hg.Types.pas
const
  cHgUncommittedHash = 'ffffffffffffffffffffffffffffffffffffffff'; // 40 f's
  cHgNotCommittedAuthor = 'Not Committed';
```

**Important:** The current Hg.Provider uses `ffffffffffff` (12 f's) for GetUncommittedHash. This is the short form. The annotate parser will receive the full 40-char node from `{node}`. Two options:
1. Change GetUncommittedHash to return the 40-char version
2. Have the parser check for both 12-char and 40-char forms

**Recommendation:** Change `GetUncommittedHash` to return the full 40-char hash `ffffffffffffffffffffffffffffffffffffffff`. The consumer code (`IsRevisionAvailable` in Navigation.pas) compares against `GetUncommittedHash`, and `TBlameLineInfo.CommitHash` will contain the 40-char hash from the parser. The 12-char short form was set in Phase 8 as a placeholder; now that we know the parser will produce 40-char hashes, update accordingly.

### Anti-Patterns to Avoid

- **Reusing Git's porcelain parser:** HGB-05 explicitly requires a dedicated parser. The Git parser's state machine (header detection, key-value pairs, TAB-prefixed content) has zero applicability to the pipe-delimited template format.
- **Using `hg annotate` without `-T`:** The default output format is designed for human consumption and varies by locale. The template approach gives full control over field order and delimiters.
- **Pipe delimiter in line content:** The template `{line}` is the LAST field, so pipes within source code lines are harmless -- we only split on the first N pipes.
- **Forgetting to handle empty {user}:** Some Mercurial repos may have commits with empty or malformed user fields. The parser must handle this gracefully.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process execution | Custom CreateProcess for hg | TVCSProcess (inherited) | Already handles pipes, handles, timeouts |
| Unified diff output | Custom diff format conversion | `hg diff -c` (native unified diff) | Compatible with existing RTF colorizer |
| Date parsing | Custom date format parser | `hgdate` filter + `UnixToDateTime` | hgdate gives Unix timestamp directly |
| Relative path computation | Manual string manipulation | `ExtractRelativePath` + `StringReplace(\, /)` | Same pattern as Git provider |

## Common Pitfalls

### Pitfall 1: Template Quoting on Windows Command Line
**What goes wrong:** The template string contains single quotes, double quotes, curly braces, and pipes -- all of which have special meaning in Windows cmd.exe.
**Why it happens:** `TVCSProcess` passes the command line through `CreateProcess` which does NOT use cmd.exe shell interpretation. The string is passed directly to the hg.exe process.
**How to avoid:** Since `TVCSProcess` uses `CreateProcess` (not `cmd.exe`), shell metacharacters are not interpreted. The template string just needs correct Mercurial template escaping. Wrap the template in double quotes in the argument string. Test with a real hg repo to validate.
**Warning signs:** Works in `cmd.exe` testing but fails when executed via CreateProcess, or vice versa.

### Pitfall 2: {line} Includes Trailing Newline
**What goes wrong:** Each `{line}` value from hg annotate includes the trailing `\n` (or `\r\n` on Windows). If the template also adds `\n`, output has double line breaks.
**Why it happens:** Mercurial's `{line}` keyword preserves the original line ending.
**How to avoid:** Do NOT add `\n` to the template. The `{line}` keyword's trailing newline serves as the record separator. The parser should trim trailing CR/LF from each parsed line.

### Pitfall 3: Author Field Contains Pipe Characters
**What goes wrong:** If a Mercurial user has configured their username with a pipe character (unlikely but possible), the parser splits incorrectly.
**Why it happens:** Pipe `|` is used as the field delimiter.
**How to avoid:** Parse left-to-right with a fixed field count. The node hash is always exactly 40 chars, so find the first `|` at position 41. Then find the next `|` for user, next for date, next for lineno. Everything after the fourth `|` is line content. This positional approach is more robust than a naive `Split('|')`.

### Pitfall 4: Uncommitted Hash Length Mismatch
**What goes wrong:** The Phase 8 stub uses 12-char `ffffffffffff` for GetUncommittedHash, but the parser produces 40-char hashes from `{node}`.
**Why it happens:** Mercurial conventionally displays 12-char short hashes, but the template `{node}` always outputs the full 40-char hash.
**How to avoid:** Update `GetUncommittedHash` to return 40 f's. Update `cHgUncommittedHash` constant accordingly.

### Pitfall 5: Mercurial Encoding Issues on Non-UTF8 Systems
**What goes wrong:** Author names with non-ASCII characters (umlauts, CJK, etc.) may be garbled.
**Why it happens:** Mercurial stores author names in the encoding configured at commit time. TVCSProcess reads stdout as UTF-8.
**How to avoid:** Modern Mercurial defaults to UTF-8. The existing TVCSProcess UTF-8 decoding handles this correctly for the vast majority of repos. Edge case: very old repos with legacy encodings. Accept as known limitation.

### Pitfall 6: hg diff -c for Initial Commit
**What goes wrong:** `hg diff -c 0` (the initial commit) may return empty diff because there is no parent to diff against.
**Why it happens:** The first commit in a Mercurial repository has no parent revision.
**How to avoid:** Mercurial handles this correctly -- `hg diff -c 0` shows all files as added (same behavior as Git's first commit diff). No special handling needed.

## Code Examples

### Complete Annotate Template Command

```pascal
// Source: Mercurial official docs (repo.mercurial-scm.org/hg/help/annotate)
const
  // Template iterates over annotated lines, emitting pipe-delimited fields.
  // {line} includes trailing newline, so no explicit \n needed.
  cHgAnnotateTemplate =
    '{lines % ''{node}|{user}|{date|hgdate}|{lineno}|{line}''}';

function BuildAnnotateArgs(const ARelPath: string): string;
begin
  // -T passes the template; file path in double quotes for spaces
  Result := 'annotate -T "' + cHgAnnotateTemplate + '" "' + ARelPath + '"';
end;
```

### Annotate Output Parser

```pascal
// Source: Designed from Mercurial template keyword documentation
procedure ParseHgAnnotateOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);
var
  LRawLines: TArray<string>;
  LList: TList<TBlameLineInfo>;
  LRawLine: string;
  LInfo: TBlameLineInfo;
  LPos1, LPos2, LPos3, LPos4: Integer;
  LDateStr: string;
  LTimestamp: Int64;
  LUser: string;
  LAngleBracket: Integer;
begin
  ALines := nil;
  if AOutput = '' then
    Exit;

  LRawLines := AOutput.Split([#10]);
  LList := TList<TBlameLineInfo>.Create;
  try
    for LRawLine in LRawLines do
    begin
      // Skip empty lines (e.g., trailing newline)
      if Length(LRawLine) < 42 then // 40 chars hash + at least 1 pipe
        Continue;

      FillChar(LInfo, SizeOf(LInfo), 0);

      // Field 1: node hash (positions 1..40)
      LPos1 := 41; // Expected position of first '|'
      if (LPos1 > Length(LRawLine)) or (LRawLine[LPos1] <> '|') then
        Continue; // Malformed line

      LInfo.CommitHash := Copy(LRawLine, 1, 40);

      // Field 2: user (from pos 42 to next '|')
      LPos2 := Pos('|', LRawLine, LPos1 + 1);
      if LPos2 = 0 then Continue;
      LUser := Copy(LRawLine, LPos1 + 1, LPos2 - LPos1 - 1);

      // Split "Name <email>" into Author and AuthorMail
      LAngleBracket := Pos('<', LUser);
      if LAngleBracket > 0 then
      begin
        LInfo.Author := Trim(Copy(LUser, 1, LAngleBracket - 1));
        LInfo.AuthorMail := Copy(LUser, LAngleBracket, Length(LUser) - LAngleBracket + 1);
      end
      else
        LInfo.Author := Trim(LUser);

      // Field 3: hgdate "timestamp offset" (from pos after second '|' to next '|')
      LPos3 := Pos('|', LRawLine, LPos2 + 1);
      if LPos3 = 0 then Continue;
      LDateStr := Copy(LRawLine, LPos2 + 1, LPos3 - LPos2 - 1);
      // hgdate format: "1679000000 -18000" -- first token is Unix timestamp
      LTimestamp := StrToInt64Def(Copy(LDateStr, 1, Pos(' ', LDateStr) - 1), 0);
      LInfo.AuthorTime := UnixToDateTime(LTimestamp, False);

      // Field 4: lineno (from pos after third '|' to next '|')
      LPos4 := Pos('|', LRawLine, LPos3 + 1);
      if LPos4 = 0 then Continue;
      LInfo.FinalLine := StrToIntDef(
        Copy(LRawLine, LPos3 + 1, LPos4 - LPos3 - 1), 0);
      LInfo.OriginalLine := LInfo.FinalLine; // Hg annotate does not distinguish

      // Remainder after fourth '|' is line content (not stored in TBlameLineInfo)

      // Detect uncommitted
      LInfo.IsUncommitted := (LInfo.CommitHash = cHgUncommittedHash);
      if LInfo.IsUncommitted then
        LInfo.Author := cHgNotCommittedAuthor;

      LList.Add(LInfo);
    end;

    ALines := LList.ToArray;
  finally
    LList.Free;
  end;
end;
```

### Commit Message via hg log

```pascal
// Source: Mercurial official docs (repo.mercurial-scm.org/hg/help/log)
// hg log -r <hash> -T "{desc}" returns full multi-line commit message
function THgProvider.GetCommitMessage(const ARepoRoot, ACommitHash: string;
  out AMessage: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('log -r ' + ACommitHash + ' -T "{desc}"', LOutput) = 0;
    if Result then
      AMessage := Trim(LOutput);
  finally
    LProcess.Free;
  end;
end;
```

### File Diff via hg diff -c

```pascal
// Source: Mercurial official docs (mercurial-scm.org/help/commands/diff)
// -c/--change shows changes in the specified changeset relative to its parent
function THgProvider.GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
  out ADiff: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('diff -c ' + ACommitHash + ' "' + ARelativePath + '"',
      LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;
```

### File at Revision via hg cat -r

```pascal
// Source: Mercurial official docs (mercurial-scm.org/help/commands/cat)
// hg cat -r <hash> <filepath> outputs file content at that revision
function THgProvider.GetFileAtRevision(const ARepoRoot, ACommitHash,
  ARelativePath: string; out AContent: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('cat -r ' + ACommitHash + ' "' + ARelativePath + '"',
      LOutput) = 0;
    if Result then
      AContent := LOutput;
  finally
    LProcess.Free;
  end;
end;
```

## State of the Art

| Old Approach (Phase 8 stub) | New Approach (Phase 9) | Impact |
|------------------------------|------------------------|--------|
| All blame methods raise ENotSupportedException | Full implementation delegating to Hg.Blame/Process | Users get blame for Hg repos |
| No annotate parsing | Template-based parser with pipe-delimited fields | HGB-01, HGB-05 satisfied |
| No commit detail fetch | `hg log -r -T "{desc}"` | HGB-02 satisfied |
| No diff retrieval | `hg diff -c` (file and full) | HGB-03 satisfied |
| No revision navigation | `hg cat -r` | HGB-04 satisfied |
| cHgUncommittedHash = 12 f's | cHgUncommittedHash = 40 f's | Correct uncommitted detection |

**Mercurial-specific behavioral differences from Git (accepted, not bugs):**
- `hg annotate` only reflects committed state; uncommitted lines are not annotated (vs Git which can show uncommitted)
- Mercurial short hash is 12 chars (vs Git's 7 chars); UI uses provider's GetUncommittedHash for detection
- `hg diff -c` outputs only the diff (no commit header), while `git show` includes commit metadata before the diff

## Open Questions

1. **Template quoting correctness**
   - What we know: CreateProcess does not invoke cmd.exe shell, so shell metacharacters should not be an issue. The template string has nested single/double quotes.
   - What's unclear: Whether Mercurial's argument parser handles the specific quoting pattern correctly on Windows.
   - Recommendation: The first implementation task should include a manual test against a real Mercurial repo to validate the exact command string works. If quoting issues arise, try escaping strategies or writing the template to a temp file and using `--template "$(cat tempfile)"` equivalent.

2. **Summary field population**
   - What we know: TBlameLineInfo has a `Summary` field populated by Git parser from the `summary` key. The hg annotate template does not naturally include the commit summary.
   - What's unclear: Whether to add `{desc|firstline}` to the template (makes the template longer, adds one more field to parse) or leave Summary empty.
   - Recommendation: Add `{desc|firstline}` as a fifth field before `{line}`. This populates the Summary field used in tooltip/popup display. The template becomes: `{node}|{user}|{date|hgdate}|{lineno}|{desc|firstline}|{line}`. Minor additional complexity, significant UX benefit.

3. **OriginalLine vs FinalLine**
   - What we know: Git blame provides both original-line and final-line numbers. Mercurial's `{lineno}` provides the line number at the annotated revision, which maps to FinalLine.
   - What's unclear: Whether OriginalLine (the line number in the original commit) is available from hg annotate.
   - Recommendation: Set OriginalLine = FinalLine. This is sufficient because OriginalLine is not prominently used in the UI; it is a metadata field. If needed in the future, `hg log -r <hash> -T "{file_adds}"` could provide more detail, but this is out of scope.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (Git submodule under /libs) |
| Config file | tests/ directory (project structure standard) |
| Quick run command | Build package via DelphiBuildDPROJ.ps1 |
| Full suite command | Build package + manual IDE test with Hg repo |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HGB-01 | Inline blame annotations for Hg files | integration | Requires real Hg repo -- manual test | manual-only |
| HGB-02 | Commit detail popup via hg log | integration | Requires real Hg repo -- manual test | manual-only |
| HGB-03 | RTF diff for Hg commits | integration | Requires real Hg repo -- manual test | manual-only |
| HGB-04 | Revision navigation via hg cat | integration | Requires real Hg repo -- manual test | manual-only |
| HGB-05 | Dedicated template-based parser | unit | Test ParseHgAnnotateOutput with synthetic input | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Build DX.Blame package with DelphiBuildDPROJ.ps1 (compilation check)
- **Per wave merge:** Full package build + manual IDE load with Mercurial repository
- **Phase gate:** Package compiles, Hg blame annotations display correctly, commit detail/diff/navigation work

### Wave 0 Gaps
- [ ] Unit test for ParseHgAnnotateOutput with sample template output (can be done with synthetic strings, no hg.exe required)
- [ ] Compilation verification is the primary automated gate
- [ ] Manual testing with real Hg repo required for HGB-01 through HGB-04

## Sources

### Primary (HIGH confidence)
- Existing codebase: `DX.Blame.Git.Provider.pas` -- reference implementation for all IVCSProvider methods
- Existing codebase: `DX.Blame.Git.Blame.pas` -- parser pattern (state machine for porcelain output)
- Existing codebase: `DX.Blame.Git.Process.pas` -- thin subclass pattern for TVCSProcess
- Existing codebase: `DX.Blame.Hg.Provider.pas` -- stub to be replaced (Phase 8 output)
- Existing codebase: `DX.Blame.VCS.Process.pas` -- base process wrapper with CreateProcess
- [Mercurial annotate help](https://repo.mercurial-scm.org/hg/help/annotate) -- template keywords: lines, node, user, date, lineno, line
- [Mercurial templates help](https://repo.mercurial-scm.org/hg/help/templates) -- hgdate filter, json filter, template keyword docs

### Secondary (MEDIUM confidence)
- [Mercurial Book -- Customizing Output](https://book.mercurial-scm.org/read/template.html) -- template syntax examples
- [Mercurial ChangeSetID wiki](https://www.mercurial-scm.org/wiki/ChangeSetID) -- node hash is 40 hex chars, short form is 12
- [Mercurial diff help](https://mercurial-scm.org/help/commands/diff) -- `-c/--change` option for changeset diff

### Tertiary (LOW confidence)
- Template `-T` option for `hg annotate` is marked EXPERIMENTAL -- may have edge cases in older Mercurial versions. Minimum Mercurial version supporting `annotate -T` is ~4.2 (2017). TortoiseHg 6.x bundles Mercurial 6.x which supports it.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new libraries, exact mirror of Git provider pattern
- Architecture: HIGH -- all IVCSProvider methods map 1:1 to well-documented hg CLI commands
- Annotate template: MEDIUM -- template syntax verified via official docs, but `-T` is EXPERIMENTAL and requires real-repo validation
- Pitfalls: HIGH -- identified from direct codebase analysis and Mercurial CLI behavior

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable domain, Mercurial CLI is mature and slow-moving)
