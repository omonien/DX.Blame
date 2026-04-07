/// <summary>
/// DX.Blame.Tests.Version
/// Unit tests for DX.Blame version constants.
/// </summary>
///
/// <remarks>
/// Validates all version constants from DX.Blame.Version using DUnitX.
/// Ensures version string format consistency and metadata correctness.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Version;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.Version;

type
  [TestFixture]
  TVersionTests = class
  public
    [Test]
    procedure TestVersionStringValue;
    [Test]
    procedure TestVersionStringFormat;
    [Test]
    procedure TestNameValue;
    [Test]
    procedure TestDescriptionNotEmpty;
    [Test]
    procedure TestCopyrightContainsAuthor;
    [Test]
    procedure TestMajorVersionNonNegative;
    [Test]
    procedure TestMinorVersionNonNegative;
    [Test]
    procedure TestReleaseNonNegative;
    [Test]
    procedure TestBuildNonNegative;
  end;

implementation

uses
  System.SysUtils;

{ TVersionTests }

procedure TVersionTests.TestVersionStringValue;
begin
  Assert.AreEqual(
    Format('%d.%d.%d.%d', [cDXBlameMajorVersion, cDXBlameMinorVersion, cDXBlameRelease, cDXBlameBuild]),
    DXBlameVersionString,
    'DXBlameVersionString must match the numeric version parts');
end;

procedure TVersionTests.TestVersionStringFormat;
var
  LParts: TArray<string>;
  LPart: string;
  LValue: Integer;
begin
  LParts := DXBlameVersionString.Split(['.']);
  Assert.AreEqual(Integer(4), Integer(Length(LParts)), 'Version must have four dot-separated parts');
  for LPart in LParts do
    Assert.IsTrue(TryStrToInt(LPart, LValue), 'Each part must be a valid integer: ' + LPart);
end;

procedure TVersionTests.TestNameValue;
begin
  Assert.AreEqual('DX.Blame', cDXBlameName);
end;

procedure TVersionTests.TestDescriptionNotEmpty;
begin
  Assert.IsNotEmpty(cDXBlameDescription);
end;

procedure TVersionTests.TestCopyrightContainsAuthor;
begin
  Assert.Contains(cDXBlameCopyright, 'Olaf Monien');
end;

procedure TVersionTests.TestMajorVersionNonNegative;
begin
  Assert.IsTrue(cDXBlameMajorVersion >= 0, 'Major version must be non-negative');
end;

procedure TVersionTests.TestMinorVersionNonNegative;
begin
  Assert.IsTrue(cDXBlameMinorVersion >= 0, 'Minor version must be non-negative');
end;

procedure TVersionTests.TestReleaseNonNegative;
begin
  Assert.IsTrue(cDXBlameRelease >= 0, 'Release must be non-negative');
end;

procedure TVersionTests.TestBuildNonNegative;
begin
  Assert.IsTrue(cDXBlameBuild >= 0, 'Build must be non-negative');
end;

initialization
  TDUnitX.RegisterTestFixture(TVersionTests);

end.