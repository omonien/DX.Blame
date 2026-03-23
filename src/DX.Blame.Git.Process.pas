/// <summary>
/// DX.Blame.Git.Process
/// Thin Git-specific subclass of the VCS process wrapper.
/// </summary>
///
/// <remarks>
/// Provides TGitProcess as a convenience subclass of TVCSProcess.
/// All CreateProcess and pipe capture logic lives in the base class.
/// TGitProcess exists to preserve the Git-specific constructor signature
/// and property name (GitPath) used by existing consumer code.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Process;

interface

uses
  Winapi.Windows,
  DX.Blame.VCS.Process;

type
  /// <summary>
  /// Git-specific process wrapper. Inherits all execution logic from
  /// TVCSProcess and adds a GitPath convenience property.
  /// </summary>
  TGitProcess = class(TVCSProcess)
  public
    /// <summary>Creates a process wrapper for the given git executable and working directory.</summary>
    constructor Create(const AGitPath, AWorkDir: string);

    /// <summary>Full path to the git executable.</summary>
    property GitPath: string read FExePath;
  end;

implementation

{ TGitProcess }

constructor TGitProcess.Create(const AGitPath, AWorkDir: string);
begin
  inherited Create(AGitPath, AWorkDir);
end;

end.
