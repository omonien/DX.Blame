/// <summary>
/// DX.Blame.Tests.Formatter
/// Unit tests for blame annotation formatting and color derivation.
/// </summary>
///
/// <remarks>
/// Validates FormatRelativeTime for all time ranges, FormatBlameAnnotation
/// for all config combinations (author, summary, truncation, uncommitted,
/// absolute date), and DeriveAnnotationColor fallback behavior.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Formatter;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.Git.Types,
  DX.Blame.Settings,
  DX.Blame.Formatter;

type
  [TestFixture]
  TFormatterTests = class
  private
    FSettings: TDXBlameSettings;
    function MakeLineInfo(const AAuthor: string; ATime: TDateTime;
      const ASummary: string; AIsUncommitted: Boolean = False): TBlameLineInfo;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestRelativeTimeJustNow;
    [Test]
    procedure TestRelativeTime5Minutes;
    [Test]
    procedure TestRelativeTime1Hour;
    [Test]
    procedure TestRelativeTimeDaysMonthsYears;
    [Test]
    procedure TestFormatDefaultAuthorAndTime;
    [Test]
    procedure TestFormatNoAuthor;
    [Test]
    procedure TestFormatWithSummary;
    [Test]
    procedure TestFormatUncommitted;
    [Test]
    procedure TestFormatTruncation;
    [Test]
    procedure TestFormatAbsoluteDate;
    [Test]
    procedure TestDeriveColorFallbackIsGray;
    [Test]
    procedure TestDeriveColorRangeForWhiteBg;
    [Test]
    procedure TestDeriveColorRangeForDarkBg;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  Vcl.Graphics,
  Winapi.Windows;

{ TFormatterTests }

procedure TFormatterTests.Setup;
begin
  FSettings := TDXBlameSettings.Create;
end;

procedure TFormatterTests.TearDown;
begin
  FreeAndNil(FSettings);
end;

function TFormatterTests.MakeLineInfo(const AAuthor: string; ATime: TDateTime;
  const ASummary: string; AIsUncommitted: Boolean): TBlameLineInfo;
begin
  Result := Default(TBlameLineInfo);
  Result.Author := AAuthor;
  Result.AuthorTime := ATime;
  Result.Summary := ASummary;
  Result.IsUncommitted := AIsUncommitted;
  if AIsUncommitted then
    Result.CommitHash := cUncommittedHash
  else
    Result.CommitHash := 'abc1234567890abcdef1234567890abcdef123456';
end;

procedure TFormatterTests.TestRelativeTimeJustNow;
begin
  Assert.AreEqual('just now', FormatRelativeTime(Now));
end;

procedure TFormatterTests.TestRelativeTime5Minutes;
begin
  Assert.AreEqual('5 minutes ago', FormatRelativeTime(IncMinute(Now, -5)));
end;

procedure TFormatterTests.TestRelativeTime1Hour;
begin
  Assert.AreEqual('1 hour ago', FormatRelativeTime(IncHour(Now, -1)));
end;

procedure TFormatterTests.TestRelativeTimeDaysMonthsYears;
begin
  Assert.AreEqual('3 days ago', FormatRelativeTime(IncDay(Now, -3)));
  // Use explicit date 65 days ago to guarantee MonthsBetween = 2
  Assert.AreEqual('2 months ago', FormatRelativeTime(Now - 65));
  // Use explicit date 370 days ago to guarantee YearsBetween = 1
  Assert.AreEqual('1 year ago', FormatRelativeTime(Now - 370));
end;

procedure TFormatterTests.TestFormatDefaultAuthorAndTime;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  // Use 95 days ago to guarantee MonthsBetween = 3
  LInfo := MakeLineInfo('John Doe', Now - 95, 'Fix bug');
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.Contains(LResult, 'John Doe');
  Assert.Contains(LResult, '3 months ago');
end;

procedure TFormatterTests.TestFormatNoAuthor;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  FSettings.ShowAuthor := False;
  // Use 95 days ago to guarantee MonthsBetween = 3
  LInfo := MakeLineInfo('John Doe', Now - 95, 'Fix bug');
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.DoesNotContain(LResult, 'John Doe');
  Assert.Contains(LResult, '3 months ago');
end;

procedure TFormatterTests.TestFormatWithSummary;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  FSettings.ShowSummary := True;
  LInfo := MakeLineInfo('John Doe', IncMonth(Now, -1), 'Fix null check');
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.Contains(LResult, 'Fix null check');
  // Bullet separator should be present
  Assert.Contains(LResult, #$2022);
end;

procedure TFormatterTests.TestFormatUncommitted;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  LInfo := MakeLineInfo('', Now, '', True);
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.AreEqual(cNotCommittedAuthor, LResult);
end;

procedure TFormatterTests.TestFormatTruncation;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  FSettings.MaxLength := 20;
  FSettings.ShowSummary := True;
  // Use 95 days to guarantee 3 months
  LInfo := MakeLineInfo('John Doe', Now - 95, 'A very long commit summary that exceeds the max length');
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.IsTrue(Length(LResult) <= 20, 'Result should be truncated to MaxLength');
  // Last character should be ellipsis
  Assert.AreEqual(#$2026, Copy(LResult, Length(LResult), 1), 'Should end with ellipsis');
end;

procedure TFormatterTests.TestFormatAbsoluteDate;
var
  LInfo: TBlameLineInfo;
  LResult: string;
begin
  FSettings.DateFormat := dfAbsolute;
  LInfo := MakeLineInfo('Jane', EncodeDate(2025, 6, 15), 'Commit');
  LResult := FormatBlameAnnotation(LInfo, FSettings);
  Assert.Contains(LResult, '2025-06-15');
end;

procedure TFormatterTests.TestDeriveColorFallbackIsGray;
var
  LColor: TColor;
begin
  // Without IDE services, should return clGray
  LColor := DeriveAnnotationColor;
  Assert.AreEqual(Integer(clGray), Integer(LColor));
end;

procedure TFormatterTests.TestDeriveColorRangeForWhiteBg;
begin
  // This test validates the fallback path since BorlandIDEServices is not available
  // in test runner context. The actual IDE-aware color derivation is tested
  // in Plan 02 when the renderer integrates with INTACodeEditorServices.
  var LColor := DeriveAnnotationColor;
  // Fallback is clGray = $808080 which has R=128, G=128, B=128
  var LR := GetRValue(ColorToRGB(LColor));
  var LG := GetGValue(ColorToRGB(LColor));
  var LB := GetBValue(ColorToRGB(LColor));
  Assert.IsTrue((LR >= 90) and (LR <= 170), 'R channel should be in muted range');
  Assert.IsTrue((LG >= 90) and (LG <= 170), 'G channel should be in muted range');
  Assert.IsTrue((LB >= 90) and (LB <= 170), 'B channel should be in muted range');
end;

procedure TFormatterTests.TestDeriveColorRangeForDarkBg;
begin
  // Same as white bg test -- fallback path returns clGray which is in range
  var LColor := DeriveAnnotationColor;
  var LR := GetRValue(ColorToRGB(LColor));
  var LG := GetGValue(ColorToRGB(LColor));
  var LB := GetBValue(ColorToRGB(LColor));
  Assert.IsTrue((LR >= 90) and (LR <= 170), 'R channel should be in muted range');
  Assert.IsTrue((LG >= 90) and (LG <= 170), 'G channel should be in muted range');
  Assert.IsTrue((LB >= 90) and (LB <= 170), 'B channel should be in muted range');
end;

initialization
  TDUnitX.RegisterTestFixture(TFormatterTests);

end.
