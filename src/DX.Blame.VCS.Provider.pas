/// <summary>
/// DX.Blame.VCS.Provider
/// VCS-neutral provider interface for blame, commit detail, and discovery operations.
/// </summary>
///
/// <remarks>
/// Defines IVCSProvider, the single interface that every VCS backend must
/// implement. Consumers depend only on this interface, enabling transparent
/// switching between Git, Mercurial, and future VCS backends without code
/// changes in the blame engine or UI layers.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.VCS.Provider;

interface

uses
  Winapi.Windows,
  DX.Blame.VCS.Types;

type
  /// <summary>
  /// Unified provider interface for VCS blame, commit detail, diff,
  /// revision navigation, and executable discovery operations.
  /// </summary>
  IVCSProvider = interface
    ['{A3F7E2B1-4C89-4D6A-B5E0-7F1234ABCDEF}']

    /// <summary>
    /// Executes a blame command for the given file and captures raw output.
    /// Returns the process exit code. AProcessHandle is set for cancellation support.
    /// </summary>
    function ExecuteBlame(const ARepoRoot, AFilePath: string;
      out AOutput: string; var AProcessHandle: THandle): Integer;

    /// <summary>
    /// Parses raw blame output into an array of per-line blame metadata records.
    /// </summary>
    function ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;

    /// <summary>
    /// Retrieves the full commit message for the given commit hash.
    /// Returns True on success.
    /// </summary>
    function GetCommitMessage(const ARepoRoot, ACommitHash: string;
      out AMessage: string): Boolean;

    /// <summary>
    /// Retrieves the diff for a single file within a specific commit.
    /// Returns True on success.
    /// </summary>
    function GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
      out ADiff: string): Boolean;

    /// <summary>
    /// Retrieves the full diff for all files in a specific commit.
    /// Returns True on success.
    /// </summary>
    function GetFullDiff(const ARepoRoot, ACommitHash: string;
      out ADiff: string): Boolean;

    /// <summary>
    /// Retrieves the content of a file at a specific revision.
    /// Returns True on success.
    /// </summary>
    function GetFileAtRevision(const ARepoRoot, ACommitHash, ARelativePath: string;
      out AContent: string): Boolean;

    /// <summary>
    /// Finds the VCS executable on the system. Returns an empty string if not found.
    /// </summary>
    function FindExecutable: string;

    /// <summary>
    /// Finds the repository root for the given path.
    /// Returns an empty string if the path is not inside a repository.
    /// </summary>
    function FindRepoRoot(const APath: string): string;

    /// <summary>
    /// Resets cached discovery results. Call on project switch.
    /// </summary>
    procedure ClearDiscoveryCache;

    /// <summary>
    /// Returns the human-readable name of this VCS provider (e.g. 'Git', 'Mercurial').
    /// </summary>
    function GetDisplayName: string;

    /// <summary>
    /// Returns the sentinel hash value used for uncommitted lines.
    /// </summary>
    function GetUncommittedHash: string;

    /// <summary>
    /// Returns the display author name used for uncommitted lines.
    /// </summary>
    function GetUncommittedAuthor: string;
  end;

implementation

end.
