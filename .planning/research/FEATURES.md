# Feature Landscape

**Domain:** Delphi IDE Plugin -- Git Blame Integration
**Researched:** 2026-03-17

## Table Stakes

Features users expect from a git blame IDE integration. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Inline blame at end of current line | Core value proposition -- like GitLens in VS Code | High | Requires INTACodeEditorEvents.PaintLine, cursor tracking, blame cache lookup |
| Author name + relative time display | Minimum useful info per line | Low | Format: "John Doe, 3 months ago" |
| Automatic blame on file open | Users expect it to just work | Medium | Trigger blame on IOTAEditorNotifier.ViewActivated, run async |
| Toggle on/off | Must be able to disable without uninstalling | Low | Menu item + IOTAKeyboardBinding hotkey |
| Git repo detection | Only activate for git-managed projects | Low | Walk parent dirs looking for .git folder |
| Cache invalidation on save | Blame data must reflect saved state | Medium | Re-run blame on IOTAEditorNotifier file save notification |
| Non-blocking execution | Blame must not freeze the IDE | High | TThread + CreateProcess in background, marshal via ForceQueue |
| Delphi 11.3+ / 12 / 13 support | Broad user base | Medium | INTACodeEditorEvents available in all target versions |

## Differentiators

Features that set DX.Blame apart. Not expected but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Hover tooltip with full commit info | See commit hash, full message, date without leaving editor | Medium | Requires mouse event handling via INTACodeEditorEvents mouse events or tooltip control |
| Commit detail view (diff) from tooltip | Deep-dive into changes directly | High | Show modal form with `git show <hash>` output, syntax highlighted |
| Configurable display format | Users can customize what they see | Low | Settings: show/hide author, date format (relative/absolute), max length |
| Configurable blame text color | Match IDE theme | Low | Allow color picker or auto-detect from IDE theme |
| Blame for selection range | Blame only selected lines for focused analysis | Medium | Use `git blame -L <start>,<end>` |
| Navigate to previous revision | "Time travel" through file history | High | `git blame <parent-hash> -- <file>` recursively |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| libgit2 native bindings | Massive complexity, DLL distribution, version mismatch risk | Use git CLI -- simpler, always matches user's installed git |
| Full git history browser | Scope creep, many tools already do this well | Focus on blame only, link out to external tools for history |
| Blame for unsaved changes | Technically impossible (git only knows committed state), confusing UX | Only blame saved/committed content, show "unsaved changes" indicator |
| Gutter column for blame | Invasive, takes horizontal space, conflicts with other plugins using gutter | Inline at end of line -- less invasive, familiar GitLens pattern |
| SVN/Mercurial support | Fragmenting effort, tiny user base for these VCS in Delphi community | Git only. Clear scope. |
| Real-time blame (on every keystroke) | Performance killer, meaningless (uncommitted changes have no blame) | Blame on file open + re-blame on save |
| Custom blame algorithm | Reinventing the wheel | Trust git's blame implementation |

## Feature Dependencies

```
Git Repo Detection --> Blame Execution --> Blame Parsing --> Blame Cache
                                                                |
Toggle On/Off --------------------------------------------> Blame Rendering (PaintLine)
                                                                |
                                                          Cursor Tracking --> Show blame for current line
                                                                |
                                                          Hover Tooltip --> Commit Detail View
```

Key dependency chain:
- Blame Rendering requires working Blame Cache
- Blame Cache requires working Blame Parsing
- Blame Parsing requires working Git CLI execution
- Git CLI execution requires Git Repo Detection
- Everything visual requires the INTACodeEditorEvents notifier registration

## MVP Recommendation

Prioritize (Phase 1):
1. **Git repo detection** -- foundation for everything
2. **Async git blame execution + porcelain parsing** -- core data pipeline
3. **In-memory blame cache per file** -- performance requirement
4. **Inline blame rendering via PaintLine** -- core visual output
5. **Toggle via menu and hotkey** -- essential UX control

Defer (Phase 2+):
- **Hover tooltip**: Requires additional complexity (mouse event handling or custom tooltip window). Ship inline blame first.
- **Commit detail view**: Depends on tooltip. Ship separately.
- **Configurable format/colors**: Nice-to-have. Hardcode sensible defaults first.
- **Navigate to previous revision**: Advanced feature, ship after core is solid.

## Sources

- [VS Code GitLens](https://marketplace.visualstudio.com/items?itemName=eamodio.gitlens) -- Feature reference for what users expect from git blame integration.
- [Git blame documentation](https://git-scm.com/docs/git-blame) -- Official feature set of git blame.
- [Embarcadero: ToolsAPI Support for the Code Editor](https://docwiki.embarcadero.com/RADStudio/Athens/en/ToolsAPI_Support_for_the_Code_Editor) -- Available painting and event APIs.
