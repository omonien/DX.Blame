/// <summary>
/// DX.Blame.Tests.Git.Discovery
/// Integration tests for git executable discovery and repo root detection.
/// </summary>
///
/// <remarks>
/// Validates FindGitExecutable, FindGitRepoRoot, and ClearDiscoveryCache
/// against the actual system. Requires git to be installed and tests to
/// run from within or near the DX.Blame git repository.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Git.Discovery;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TGitDiscoveryTests = class
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure TestFindGitExecutable;
    [Test]
    procedure TestGitExecutableIsGitExe;
    [Test]
    procedure TestFindRepoRootFromProjectDir;
    [Test]
    procedure TestFindRepoRootFromNonRepo;
    [Test]
    procedure TestFindRepoRootInSubmodule;
    [Test]
    procedure TestClearDiscoveryCacheResets;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  DX.Blame.Git.Discovery;

{ TGitDiscoveryTests }

procedure TGitDiscoveryTests.Setup;
begin
  // Ensure clean state before each test
  ClearDiscoveryCache;
end;

procedure TGitDiscoveryTests.TestFindGitExecutable;
var
  LPath: string;
begin
  LPath := FindGitExecutable;
  Assert.IsNotEmpty(LPath, 'Git executable should be found on this system');
end;

procedure TGitDiscoveryTests.TestGitExecutableIsGitExe;
var
  LPath: string;
begin
  LPath := FindGitExecutable;
  Assert.IsNotEmpty(LPath);
  Assert.IsTrue(LowerCase(LPath).EndsWith('git.exe'),
    'Git path should end with git.exe, got: ' + LPath);
end;

procedure TGitDiscoveryTests.TestFindRepoRootFromProjectDir;
var
  LBase: string;
  LRepo: string;
  LProjectDir: string;
  LRoot: string;
begin
  // Build a temporary repo layout instead of relying on the test exe being
  // located inside the source repository (it may be built elsewhere).
  LBase := TPath.Combine(TPath.GetTempPath, 'DXBlameTest_' + TPath.GetGUIDFileName);
  LRepo := TPath.Combine(LBase, 'repo');
  LProjectDir := TPath.Combine(TPath.Combine(TPath.Combine(LRepo, 'build'), 'Win64'), 'Debug');
  TDirectory.CreateDirectory(TPath.Combine(LRepo, '.git'));
  TDirectory.CreateDirectory(LProjectDir);
  try
    LRoot := FindGitRepoRoot(LProjectDir);
    Assert.AreEqual(LRepo, ExcludeTrailingPathDelimiter(LRoot),
      'Should find repo root from nested project directory: ' + LProjectDir);
  finally
    TDirectory.Delete(LBase, True);
  end;
end;

procedure TGitDiscoveryTests.TestFindRepoRootFromNonRepo;
var
  LRoot: string;
begin
  LRoot := FindGitRepoRoot('C:\Windows');
  Assert.IsEmpty(LRoot, 'C:\Windows should not be inside a git repo');
end;

procedure TGitDiscoveryTests.TestFindRepoRootInSubmodule;
var
  LBase: string;
  LOuter: string;
  LSub: string;
  LSubSrc: string;
  LRoot: string;
begin
  // Issue #14: a submodule has a .git FILE, not a folder. A file inside the
  // submodule must resolve to the submodule root, not to the superproject.
  LBase := TPath.Combine(TPath.GetTempPath, 'DXBlameTest_' + TPath.GetGUIDFileName);
  LOuter := TPath.Combine(LBase, 'outer');
  LSub := TPath.Combine(LOuter, 'sub');
  LSubSrc := TPath.Combine(LSub, 'src');
  TDirectory.CreateDirectory(TPath.Combine(LOuter, '.git'));
  TDirectory.CreateDirectory(LSubSrc);
  TFile.WriteAllText(TPath.Combine(LSub, '.git'), 'gitdir: ../.git/modules/sub');
  try
    LRoot := FindGitRepoRoot(TPath.Combine(LSubSrc, 'Unit1.pas'));
    Assert.AreEqual(LSub, ExcludeTrailingPathDelimiter(LRoot),
      'File in submodule should resolve to the submodule root');

    ClearDiscoveryCache;
    LRoot := FindGitRepoRoot(LOuter);
    Assert.AreEqual(LOuter, ExcludeTrailingPathDelimiter(LRoot),
      'Superproject should still resolve to its own root');
  finally
    TDirectory.Delete(LBase, True);
  end;
end;

procedure TGitDiscoveryTests.TestClearDiscoveryCacheResets;
var
  LPath1: string;
  LPath2: string;
begin
  LPath1 := FindGitExecutable;
  ClearDiscoveryCache;
  LPath2 := FindGitExecutable;
  Assert.AreEqual(LPath1, LPath2,
    'After cache clear, re-detection should return the same valid path');
end;

initialization
  TDUnitX.RegisterTestFixture(TGitDiscoveryTests);

end.
