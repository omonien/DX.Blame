# Phase 7: Engine VCS Dispatch - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Route all VCS operations through IVCSProvider — eliminate every direct Git call from engine, commit detail, navigation, and popup units. After this phase, no consumer unit imports Git-specific units directly. All existing Git blame functionality works unchanged through the abstraction layer.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All gray areas in this phase are purely architectural — the user delegated these to Claude, consistent with Phase 6 context:

- **Provider ownership & lifecycle** — Where IVCSProvider is created, stored, and how it's made available to Engine, CommitDetail, Navigation, and Popup. Must account for Phase 8 (VCS Discovery) needing to swap providers later.
- **CommitDetail threading** — How TCommitDetailThread transitions from direct TGitProcess/FindGitExecutable calls to provider-based dispatch. Thread-safety considerations for the provider reference.
- **Sentinel constant migration** — Whether cUncommittedHash/cNotCommittedAuthor move to VCS.Types as shared defaults or are always queried via provider methods (provider already has GetUncommittedHash/GetUncommittedAuthor from Phase 6).
- **Uses clause cleanup** — Which Git-specific unit references to remove from consumer units, and how to handle any remaining Git.Types references (e.g., cUncommittedHash in Popup, Navigation).

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User confirmed all decisions are Claude's discretion for this pure refactoring phase.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- IVCSProvider (src/DX.Blame.VCS.Provider.pas): Full interface with ExecuteBlame, ParseBlameOutput, GetCommitMessage, GetFileDiff, GetFullDiff, GetFileAtRevision, FindExecutable, FindRepoRoot, ClearDiscoveryCache, GetUncommittedHash, GetUncommittedAuthor
- TGitProvider (src/DX.Blame.Git.Provider.pas): Complete IVCSProvider implementation delegating to existing Git units
- TBlameLineInfo, TBlameData (src/DX.Blame.VCS.Types.pas): Already VCS-neutral from Phase 6

### Units Requiring Refactoring
- **DX.Blame.Engine** (lines 108-114): uses Git.Discovery, Git.Process, Git.Blame in implementation. TBlameThread creates TGitProcess directly (line 154). Initialize calls FindGitExecutable/FindGitRepoRoot (lines 231-243). Properties named FGitPath, FGitAvailable, FGitNotified.
- **DX.Blame.CommitDetail** (lines 97-99): uses Git.Discovery, Git.Process in implementation. TCommitDetailThread calls FindGitExecutable and creates TGitProcess (lines 180-186).
- **DX.Blame.Navigation** (lines 57-59): uses Git.Types, Git.Discovery, Git.Process in implementation. GetFileAtCommit creates TGitProcess directly (lines 86-103). OnRevisionClick checks BlameEngine.GitAvailable (line 212).
- **DX.Blame.Popup** (line 38): uses Git.Types for cNotCommittedAuthor sentinel constant (line 194).

### Established Patterns
- Singleton pattern: BlameEngine and CommitDetailCache are lazy-initialized globals
- Async thread pattern: TBlameThread and TCommitDetailThread both create process objects, execute, Queue results to main thread
- TGitProvider delegates to existing Git units — no logic duplication

### Integration Points
- Engine.Initialize is called from IDE.Notifier on project open — entry point for provider creation
- Engine.OnProjectSwitch calls ClearDiscoveryCache — must route through provider
- CommitDetailCache.Clear called from Engine.OnProjectSwitch — coupling point
- Navigation.OnRevisionClick and Popup.ShowForCommit both need access to the active provider

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-engine-vcs-dispatch*
*Context gathered: 2026-03-23*
