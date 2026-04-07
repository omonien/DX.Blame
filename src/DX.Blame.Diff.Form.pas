/// <summary>
/// DX.Blame.Diff.Form
/// Modal dialog for displaying color-coded unified diff output for a commit.
/// </summary>
///
/// <remarks>
/// TFormDXBlameDiff shows the full commit header (hash, author, date, message)
/// and a TRichEdit with color-coded diff lines: green for additions, red for
/// deletions, blue for hunk headers. Supports toggling between current-file
/// and full-commit diff scope. Dialog size persists via BlameSettings INI.
/// Layout is defined in DX.Blame.Diff.Form.dfm for automatic DPI scaling.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Diff.Form;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Winapi.Windows,
  DX.Blame.VCS.Types,
  DX.Blame.CommitDetail;

type
  /// <summary>
  /// Modal diff dialog showing commit header and color-coded unified diff.
  /// </summary>
  TFormDXBlameDiff = class(TForm)
    PanelHeader: TPanel;
    LabelHash: TLabel;
    LabelAuthor: TLabel;
    LabelDate: TLabel;
    MemoMessage: TMemo;
    PanelToolbar: TPanel;
    ButtonToggleScope: TButton;
    LabelLoading: TLabel;
    RichEditDiff: TRichEdit;
    procedure DoToggleScopeClick(ASender: TObject);
  private
    FCommitHash: string;
    FRepoRoot: string;
    FRelativeFilePath: string;
    FShowingFullDiff: Boolean;
    FFileDiff: string;
    FFullDiff: string;

    procedure HandleCommitDetailComplete(const ADetail: TCommitDetail);
    procedure LoadDiffIntoRichEdit(const ADiff: string);
    procedure ApplyThemeColors;
    function IsDarkTheme: Boolean;
  public
    /// <summary>
    /// Shows the diff dialog modally for the given commit.
    /// Creates the form, populates it, shows modal, saves size, and frees.
    /// </summary>
    class procedure ShowDiff(const ACommitHash, ARepoRoot, ARelativeFilePath: string;
      const ALineInfo: TBlameLineInfo);
  end;

implementation

{$R *.dfm}

uses
  System.Math,
  Winapi.Messages,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.VCS.Provider,
  DX.Blame.Engine,
  DX.Blame.Settings,
  DX.Blame.Formatter,
  DX.Blame.Logging;

const
  cMaxDiffLines = 5000;

{ TFormDXBlameDiff }

class procedure TFormDXBlameDiff.ShowDiff(const ACommitHash, ARepoRoot,
  ARelativeFilePath: string; const ALineInfo: TBlameLineInfo);
var
  LForm: TFormDXBlameDiff;
  LDetail: TCommitDetail;
begin
  LForm := TFormDXBlameDiff.Create(nil);
  try
    LForm.Width := BlameSettings.DiffDialogWidth;
    LForm.Height := BlameSettings.DiffDialogHeight;

    LForm.FCommitHash := ACommitHash;
    LForm.FRepoRoot := ARepoRoot;
    LForm.FRelativeFilePath := ARelativeFilePath;
    LForm.FShowingFullDiff := False;

    // Populate header labels
    LForm.LabelHash.Caption := Copy(ACommitHash, 1, 7);
    LForm.LabelAuthor.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';
    LForm.LabelDate.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);

    LForm.ApplyThemeColors;

    // Populate from cache or fetch async
    if CommitDetailCache.TryGet(ACommitHash, LDetail) and LDetail.Fetched then
    begin
      LForm.LabelLoading.Visible := False;
      LForm.MemoMessage.Text := LDetail.FullMessage;
      LForm.FFileDiff := LDetail.FileDiff;
      LForm.FFullDiff := LDetail.FullDiff;
      LForm.LoadDiffIntoRichEdit(LDetail.FileDiff);
    end
    else
    begin
      LForm.LabelLoading.Visible := True;
      FetchCommitDetailAsync(BlameEngine.Provider, ACommitHash, ARepoRoot,
        ARelativeFilePath, LForm.HandleCommitDetailComplete);
    end;

    LForm.ShowModal;

    // Save dialog size on close
    BlameSettings.DiffDialogWidth := LForm.Width;
    BlameSettings.DiffDialogHeight := LForm.Height;
    BlameSettings.Save;
  finally
    LForm.Free;
  end;
end;

procedure TFormDXBlameDiff.HandleCommitDetailComplete(const ADetail: TCommitDetail);
begin
  LabelLoading.Visible := False;

  if ADetail.Fetched then
  begin
    MemoMessage.Text := ADetail.FullMessage;
    FFileDiff := ADetail.FileDiff;
    FFullDiff := ADetail.FullDiff;

    CommitDetailCache.Store(FCommitHash, ADetail);

    if FShowingFullDiff then
      LoadDiffIntoRichEdit(FFullDiff)
    else
      LoadDiffIntoRichEdit(FFileDiff);
    LogDebug('DiffForm', 'Commit diff loaded for ' + Copy(FCommitHash, 1, 7));
  end
  else
  begin
    MemoMessage.Text := '(Failed to fetch commit details)';
    LoadDiffIntoRichEdit('');
    LogWarn('DiffForm', 'Failed to load commit diff for ' + Copy(FCommitHash, 1, 7));
  end;
end;

procedure TFormDXBlameDiff.DoToggleScopeClick(ASender: TObject);
var
  LDetail: TCommitDetail;
begin
  FShowingFullDiff := not FShowingFullDiff;

  if FShowingFullDiff then
  begin
    ButtonToggleScope.Caption := 'Show Current File Only';
    if FFullDiff <> '' then
      LoadDiffIntoRichEdit(FFullDiff)
    else
    begin
      LabelLoading.Visible := True;
      if CommitDetailCache.TryGet(FCommitHash, LDetail) and LDetail.Fetched then
      begin
        FFullDiff := LDetail.FullDiff;
        LabelLoading.Visible := False;
        LoadDiffIntoRichEdit(FFullDiff);
      end
      else
        FetchCommitDetailAsync(BlameEngine.Provider, FCommitHash, FRepoRoot,
          FRelativeFilePath, HandleCommitDetailComplete);
    end;
  end
  else
  begin
    ButtonToggleScope.Caption := 'Show Full Commit Diff';
    LoadDiffIntoRichEdit(FFileDiff);
  end;
end;

procedure TFormDXBlameDiff.LoadDiffIntoRichEdit(const ADiff: string);
var
  LLines: TArray<string>;
  LLine: string;
  LColor: TColor;
  LDark: Boolean;
  LDefaultColor: TColor;
  i, LCount: Integer;
begin
  LDark := IsDarkTheme;
  if LDark then
    LDefaultColor := $00D4D4D4
  else
    LDefaultColor := clBlack;

  RichEditDiff.Lines.BeginUpdate;
  try
    RichEditDiff.Clear;
    if ADiff = '' then
    begin
      RichEditDiff.Text := '(No diff available)';
      Exit;
    end;

    LLines := ADiff.Split([#10]);
    LCount := Length(LLines);
    if LCount > cMaxDiffLines then
      LCount := cMaxDiffLines;

    for i := 0 to LCount - 1 do
    begin
      LLine := LLines[i].TrimRight([#13]);
      LColor := GetDiffLineColor(LLine, LDark, LDefaultColor);

      RichEditDiff.SelStart := RichEditDiff.GetTextLen;
      RichEditDiff.SelLength := 0;
      RichEditDiff.SelAttributes.Color := LColor;

      if i < LCount - 1 then
        RichEditDiff.SelText := LLine + #13#10
      else
        RichEditDiff.SelText := LLine;
    end;

    if Length(LLines) > cMaxDiffLines then
    begin
      RichEditDiff.SelStart := RichEditDiff.GetTextLen;
      RichEditDiff.SelLength := 0;
      RichEditDiff.SelAttributes.Color := clYellow;
      RichEditDiff.SelText := #13#10 + '[Showing first ' + IntToStr(cMaxDiffLines) + ' lines]';
    end;
  finally
    RichEditDiff.Lines.EndUpdate;
  end;

  // Scroll to top
  RichEditDiff.SelStart := 0;
  RichEditDiff.SelLength := 0;
  SendMessage(RichEditDiff.Handle, WM_VSCROLL, SB_TOP, 0);
end;

procedure TFormDXBlameDiff.ApplyThemeColors;
begin
  if IsDarkTheme then
  begin
    Color := $002D2D2D;
    Font.Color := $00D4D4D4;
    PanelHeader.Color := $002D2D2D;
    PanelHeader.Font.Color := $00D4D4D4;
    PanelToolbar.Color := $002D2D2D;
    LabelHash.Font.Color := $00569CD6;
    LabelAuthor.Font.Color := $00D4D4D4;
    LabelDate.Font.Color := $00808080;
    MemoMessage.Color := $00252525;
    MemoMessage.Font.Color := $00D4D4D4;
    LabelLoading.Font.Color := $00808080;
    RichEditDiff.Color := $00252525;
    RichEditDiff.Font.Color := $00D4D4D4;
  end
  else
  begin
    Color := clWindow;
    Font.Color := clWindowText;
    PanelHeader.Color := clWindow;
    PanelHeader.Font.Color := clWindowText;
    PanelToolbar.Color := clWindow;
    LabelHash.Font.Color := clNavy;
    LabelAuthor.Font.Color := clWindowText;
    LabelDate.Font.Color := clGray;
    MemoMessage.Color := clWindow;
    MemoMessage.Font.Color := clWindowText;
    LabelLoading.Font.Color := clGray;
    RichEditDiff.Color := clWindow;
    RichEditDiff.Font.Color := clWindowText;
  end;
end;

function TFormDXBlameDiff.IsDarkTheme: Boolean;
var
  LServices: INTACodeEditorServices;
  LBgColor: TColor;
  LR, LG, LB: Byte;
begin
  Result := False;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
  begin
    LBgColor := ColorToRGB(LServices.Options.BackgroundColor[atWhiteSpace]);
    LR := GetRValue(LBgColor);
    LG := GetGValue(LBgColor);
    LB := GetBValue(LBgColor);
    Result := ((Integer(LR) + Integer(LG) + Integer(LB)) div 3) < 128;
  end;
end;

end.
