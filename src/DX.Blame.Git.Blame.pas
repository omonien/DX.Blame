/// <summary>
/// DX.Blame.Git.Blame
/// Parser for git blame --line-porcelain output.
/// </summary>
///
/// <remarks>
/// Converts raw porcelain output into an array of TBlameLineInfo records.
/// The parser implements a state machine that scans for commit headers,
/// reads key-value metadata pairs, and stops at the TAB-prefixed content
/// line. Uncommitted lines (all-zero hash) are detected and marked.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Blame;

interface

uses
  DX.Blame.VCS.Types,
  DX.Blame.Git.Types;

/// <summary>
/// Parses git blame --line-porcelain output into an array of TBlameLineInfo.
/// </summary>
procedure ParseBlameOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.Generics.Collections;

/// <summary>
/// Returns True if the line looks like a porcelain header (40+ hex chars).
/// </summary>
function IsHeaderLine(const ALine: string): Boolean;
var
  LCh: Char;
begin
  Result := False;
  if Length(ALine) < 40 then
    Exit;
  for var i := 1 to 40 do
  begin
    LCh := ALine[i];
    if not CharInSet(LCh, ['0'..'9', 'a'..'f']) then
      Exit;
  end;
  Result := True;
end;

procedure ParseBlameOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);
var
  LRawLines: TArray<string>;
  LList: TList<TBlameLineInfo>;
  LIndex: Integer;
  LLine: string;
  LInfo: TBlameLineInfo;
  LParts: TArray<string>;
begin
  ALines := nil;
  if AOutput = '' then
    Exit;

  // Split by LF, trim possible CR from line ends
  LRawLines := AOutput.Split([#10]);

  LList := TList<TBlameLineInfo>.Create;
  try
    LIndex := 0;
    while LIndex < Length(LRawLines) do
    begin
      LLine := LRawLines[LIndex];
      // Trim trailing CR if present
      if (LLine <> '') and (LLine[Length(LLine)] = #13) then
        LLine := Copy(LLine, 1, Length(LLine) - 1);

      if (LLine = '') then
      begin
        Inc(LIndex);
        Continue;
      end;

      // Look for header line
      if not IsHeaderLine(LLine) then
      begin
        Inc(LIndex);
        Continue;
      end;

      // Parse header: hash orig-line final-line [group-count]
      FillChar(LInfo, SizeOf(LInfo), 0);
      LInfo.CommitHash := Copy(LLine, 1, 40);

      LParts := Copy(LLine, 42, Length(LLine)).Split([' ']);
      if Length(LParts) >= 1 then
        LInfo.OriginalLine := StrToIntDef(LParts[0], 0);
      if Length(LParts) >= 2 then
        LInfo.FinalLine := StrToIntDef(LParts[1], 0);

      Inc(LIndex);

      // Read key-value pairs until content line (starts with TAB)
      while LIndex < Length(LRawLines) do
      begin
        LLine := LRawLines[LIndex];
        if (LLine <> '') and (LLine[Length(LLine)] = #13) then
          LLine := Copy(LLine, 1, Length(LLine) - 1);

        // Content line starts with TAB
        if (LLine <> '') and (LLine[1] = #9) then
        begin
          Inc(LIndex);
          Break;
        end;

        // Parse key-value pairs
        if LLine.StartsWith('author-mail ') then
          LInfo.AuthorMail := Copy(LLine, 13, Length(LLine))
        else if LLine.StartsWith('author-time ') then
          LInfo.AuthorTime := UnixToDateTime(StrToInt64Def(Copy(LLine, 13, Length(LLine)), 0), False)
        else if LLine.StartsWith('author ') then
          LInfo.Author := Copy(LLine, 8, Length(LLine))
        else if LLine.StartsWith('summary ') then
          LInfo.Summary := Copy(LLine, 9, Length(LLine));

        Inc(LIndex);
      end;

      // Mark uncommitted lines
      LInfo.IsUncommitted := (LInfo.CommitHash = cUncommittedHash);
      if LInfo.IsUncommitted then
        LInfo.Author := cNotCommittedAuthor;

      LList.Add(LInfo);
    end;

    ALines := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
