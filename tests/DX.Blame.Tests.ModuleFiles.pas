/// <summary>
/// DX.Blame.Tests.ModuleFiles
/// Unit tests for multi-file module blame selection and the one-shot request guard.
/// </summary>
///
/// <remarks>
/// Covers the C++ .cpp/.h case from issue #13 without hosting the IDE.
/// CollectBlameFileNames is the list the open handler requests, the module
/// notifier stores, and close cancels. TBlameRequestGuard is the renderer
/// cache-miss guard owned by TBlameEngine.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.ModuleFiles;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.ModuleFiles;

type
  [TestFixture]
  TModuleFileListTests = class
  public
    [Test]
    procedure TestCppAndHeaderAreBothIncluded;
    [Test]
    procedure TestHppHeaderIsIncluded;
    [Test]
    procedure TestNotifiedFileSurvivesEmptyEditorList;
    [Test]
    procedure TestCaseInsensitiveDuplicateIsDropped;
    [Test]
    procedure TestEmptyEditorNamesAreSkipped;
    [Test]
    procedure TestNotifiedFileAppendedWhenEditorsOmitIt;
    [Test]
    procedure TestBlankInputYieldsNoFiles;
  end;

  [TestFixture]
  TBlameRequestGuardTests = class
  private
    FGuard: TBlameRequestGuard;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestMarkOnceThenContains;
    [Test]
    procedure TestContainsIsCaseInsensitive;
    [Test]
    procedure TestEmptyNameIsIgnored;
    [Test]
    procedure TestRemoveAllowsANewRequest;
    [Test]
    procedure TestClearAllowsANewRequest;
    [Test]
    procedure TestCacheMissRequestsOnlyTheFirstTime;
  end;

implementation

function TwoNames(const A, B: string): TArray<string>;
begin
  SetLength(Result, 2);
  Result[0] := A;
  Result[1] := B;
end;

{ TModuleFileListTests }

procedure TModuleFileListTests.TestCppAndHeaderAreBothIncluded;
var
  LFiles: TArray<string>;
begin
  // ofnFileOpened reports the .cpp. The module editors also include the .h.
  LFiles := CollectBlameFileNames('C:\src\Widget.cpp',
    TwoNames('C:\src\Widget.cpp', 'C:\src\Widget.h'));
  Assert.AreEqual(Integer(2), Integer(Length(LFiles)), 'cpp and header should both be blamed');
  Assert.AreEqual('C:\src\Widget.cpp', LFiles[0]);
  Assert.AreEqual('C:\src\Widget.h', LFiles[1]);
end;

procedure TModuleFileListTests.TestHppHeaderIsIncluded;
var
  LFiles: TArray<string>;
begin
  LFiles := CollectBlameFileNames('C:\src\Widget.cpp',
    TwoNames('C:\src\Widget.cpp', 'C:\src\Widget.hpp'));
  Assert.AreEqual(Integer(2), Integer(Length(LFiles)));
  Assert.AreEqual('C:\src\Widget.hpp', LFiles[1]);
end;

procedure TModuleFileListTests.TestNotifiedFileSurvivesEmptyEditorList;
var
  LFiles: TArray<string>;
begin
  LFiles := CollectBlameFileNames('C:\src\Unit1.pas', nil);
  Assert.AreEqual(Integer(1), Integer(Length(LFiles)));
  Assert.AreEqual('C:\src\Unit1.pas', LFiles[0]);
end;

procedure TModuleFileListTests.TestCaseInsensitiveDuplicateIsDropped;
var
  LFiles: TArray<string>;
begin
  LFiles := CollectBlameFileNames('C:\src\Widget.CPP',
    TwoNames('C:\src\Widget.cpp', 'C:\src\Widget.h'));
  Assert.AreEqual(Integer(2), Integer(Length(LFiles)), 'cpp must not be requested twice');
  Assert.AreEqual('C:\src\Widget.cpp', LFiles[0]);
  Assert.AreEqual('C:\src\Widget.h', LFiles[1]);
end;

procedure TModuleFileListTests.TestEmptyEditorNamesAreSkipped;
var
  LEditors: TArray<string>;
  LFiles: TArray<string>;
begin
  SetLength(LEditors, 4);
  LEditors[0] := '';
  LEditors[1] := 'C:\src\Widget.cpp';
  LEditors[2] := '';
  LEditors[3] := 'C:\src\Widget.h';
  LFiles := CollectBlameFileNames('C:\src\Widget.cpp', LEditors);
  Assert.AreEqual(Integer(2), Integer(Length(LFiles)));
  Assert.AreEqual('C:\src\Widget.h', LFiles[1]);
end;

procedure TModuleFileListTests.TestNotifiedFileAppendedWhenEditorsOmitIt;
var
  LEditors: TArray<string>;
  LFiles: TArray<string>;
begin
  SetLength(LEditors, 1);
  LEditors[0] := 'C:\src\Widget.h';
  LFiles := CollectBlameFileNames('C:\src\Widget.cpp', LEditors);
  Assert.AreEqual(Integer(2), Integer(Length(LFiles)));
  Assert.AreEqual('C:\src\Widget.h', LFiles[0]);
  Assert.AreEqual('C:\src\Widget.cpp', LFiles[1]);
end;

procedure TModuleFileListTests.TestBlankInputYieldsNoFiles;
var
  LEditors: TArray<string>;
  LFiles: TArray<string>;
begin
  SetLength(LEditors, 2);
  LEditors[0] := '';
  LEditors[1] := '';
  LFiles := CollectBlameFileNames('', LEditors);
  Assert.AreEqual(Integer(0), Integer(Length(LFiles)));
end;

{ TBlameRequestGuardTests }

procedure TBlameRequestGuardTests.Setup;
begin
  FGuard := TBlameRequestGuard.Create;
end;

procedure TBlameRequestGuardTests.TearDown;
begin
  FGuard.Free;
  FGuard := nil;
end;

procedure TBlameRequestGuardTests.TestMarkOnceThenContains;
begin
  Assert.IsFalse(FGuard.Contains('C:\src\Widget.h'));
  FGuard.Mark('C:\src\Widget.h');
  FGuard.Mark('C:\src\Widget.h');
  Assert.IsTrue(FGuard.Contains('C:\src\Widget.h'));
end;

procedure TBlameRequestGuardTests.TestContainsIsCaseInsensitive;
begin
  FGuard.Mark('C:\src\Widget.h');
  Assert.IsTrue(FGuard.Contains('c:\src\widget.H'));
end;

procedure TBlameRequestGuardTests.TestEmptyNameIsIgnored;
begin
  FGuard.Mark('');
  Assert.IsFalse(FGuard.Contains(''));
  FGuard.Remove('');
  Assert.IsFalse(FGuard.Contains('C:\src\Widget.h'));
end;

procedure TBlameRequestGuardTests.TestRemoveAllowsANewRequest;
begin
  FGuard.Mark('C:\src\Widget.h');
  FGuard.Mark('C:\src\Widget.cpp');
  FGuard.Remove('C:\src\Widget.h');
  Assert.IsFalse(FGuard.Contains('C:\src\Widget.h'));
  Assert.IsTrue(FGuard.Contains('C:\src\Widget.cpp'));
end;

procedure TBlameRequestGuardTests.TestClearAllowsANewRequest;
begin
  FGuard.Mark('C:\src\Widget.h');
  FGuard.Clear;
  Assert.IsFalse(FGuard.Contains('C:\src\Widget.h'));
end;

procedure TBlameRequestGuardTests.TestCacheMissRequestsOnlyTheFirstTime;
const
  cHeader = 'C:\src\Widget.h';
var
  LRequestCount: Integer;
begin
  // Same decision as TDXBlameRenderer.PaintLine: call RequestBlameDebounced
  // only while the guard does not yet contain the buffer file name.
  LRequestCount := 0;

  if not FGuard.Contains(cHeader) then
  begin
    FGuard.Mark(cHeader);
    Inc(LRequestCount);
  end;
  if not FGuard.Contains(cHeader) then
  begin
    FGuard.Mark(cHeader);
    Inc(LRequestCount);
  end;

  Assert.AreEqual(Integer(1), Integer(LRequestCount), 'a cache miss must request blame only once');
  Assert.IsTrue(FGuard.Contains(cHeader));
end;

end.
