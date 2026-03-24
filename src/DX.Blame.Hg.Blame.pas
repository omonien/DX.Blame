/// <summary>
/// DX.Blame.Hg.Blame
/// Dedicated template-based parser for hg annotate output.
/// </summary>
///
/// <remarks>
/// Provides ParseHgAnnotateOutput which parses pipe-delimited template
/// output from hg annotate -T into TBlameLineInfo records. This parser
/// is completely independent from the Git porcelain parser in
/// DX.Blame.Git.Blame. The template uses positional field extraction
/// rather than Split to handle pipes in source code line content.
/// Also provides BuildAnnotateArgs to construct the hg annotate command.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Hg.Blame;

interface

uses
  DX.Blame.VCS.Types,
  DX.Blame.Hg.Types;

/// <summary>
/// Parses hg annotate -T template output into an array of TBlameLineInfo.
/// The input must be pipe-delimited format: node|user|hgdate|lineno|desc|line
/// </summary>
procedure ParseHgAnnotateOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);

/// <summary>
/// Builds the hg annotate command arguments with the template string.
/// </summary>
function BuildAnnotateArgs(const ARelPath: string): string;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections;

const
  /// <summary>Template for hg annotate -T that produces pipe-delimited per-line output.</summary>
  cHgAnnotateTemplate =
    '{lines % ''{node}|{user}|{date|hgdate}|{lineno}|{desc|firstline}|{line}''}';

function BuildAnnotateArgs(const ARelPath: string): string;
begin
  Result := 'annotate -T "' + cHgAnnotateTemplate + '" "' + ARelPath + '"';
end;

procedure ParseHgAnnotateOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);
var
  LRawLines: TArray<string>;
  LList: TList<TBlameLineInfo>;
  LRawLine: string;
  LInfo: TBlameLineInfo;
  LPos1, LPos2, LPos3, LPos4, LPos5: Integer;
  LDateStr: string;
  LTimestamp: Int64;
  LUser: string;
  LAngleBracket: Integer;
  LSpacePos: Integer;
begin
  ALines := nil;
  if AOutput = '' then
    Exit;

  LRawLines := AOutput.Split([#10]);
  LList := TList<TBlameLineInfo>.Create;
  try
    for LRawLine in LRawLines do
    begin
      // Trim trailing CR if present
      if (LRawLine <> '') and (LRawLine[Length(LRawLine)] = #13) then
        LRawLine := Copy(LRawLine, 1, Length(LRawLine) - 1);

      // Skip lines shorter than minimum (40 chars hash + 1 pipe)
      if Length(LRawLine) < 42 then
        Continue;

      // Field 1: node hash at positions 1..40, pipe expected at position 41
      LPos1 := 41;
      if LRawLine[LPos1] <> '|' then
        Continue; // Malformed line

      FillChar(LInfo, SizeOf(LInfo), 0);
      LInfo.CommitHash := Copy(LRawLine, 1, 40);

      // Field 2: user (from pos 42 to next '|')
      LPos2 := Pos('|', LRawLine, LPos1 + 1);
      if LPos2 = 0 then
        Continue;
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
      if LPos3 = 0 then
        Continue;
      LDateStr := Copy(LRawLine, LPos2 + 1, LPos3 - LPos2 - 1);
      // hgdate format: "1679000000 -18000" -- first token is Unix timestamp
      LSpacePos := Pos(' ', LDateStr);
      if LSpacePos > 0 then
        LTimestamp := StrToInt64Def(Copy(LDateStr, 1, LSpacePos - 1), 0)
      else
        LTimestamp := StrToInt64Def(LDateStr, 0);
      LInfo.AuthorTime := UnixToDateTime(LTimestamp, False);

      // Field 4: lineno (from pos after third '|' to next '|')
      LPos4 := Pos('|', LRawLine, LPos3 + 1);
      if LPos4 = 0 then
        Continue;
      LInfo.FinalLine := StrToIntDef(
        Copy(LRawLine, LPos3 + 1, LPos4 - LPos3 - 1), 0);
      LInfo.OriginalLine := LInfo.FinalLine; // Hg does not distinguish

      // Field 5: desc|firstline (from pos after fourth '|' to next '|')
      LPos5 := Pos('|', LRawLine, LPos4 + 1);
      if LPos5 > 0 then
        LInfo.Summary := Copy(LRawLine, LPos4 + 1, LPos5 - LPos4 - 1)
      else
        LInfo.Summary := ''; // No summary field found

      // Remainder after 5th '|' is line content (not stored)

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

end.
