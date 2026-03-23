/// <summary>
/// DX.Blame.Git.Types
/// Git-specific sentinel constants for uncommitted line detection.
/// </summary>
///
/// <remarks>
/// Contains only Git-specific constants that do not belong in the
/// VCS-neutral type layer. All shared types (TBlameLineInfo, TBlameData)
/// and timing constants have moved to DX.Blame.VCS.Types.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Types;

interface

uses
  DX.Blame.VCS.Types;

const
  /// <summary>SHA-1 hash sentinel for lines not yet committed.</summary>
  cUncommittedHash = '0000000000000000000000000000000000000000';

  /// <summary>Display author name for uncommitted lines.</summary>
  cNotCommittedAuthor = 'Not committed yet';

implementation

end.
