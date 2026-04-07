/// <summary>
/// DX.Blame.Popup
/// Borderless popup panel for displaying commit information on annotation click.
/// </summary>
///
/// <remarks>
/// TDXBlamePopup is a borderless form that shows commit hash, author, email,
/// date, and full commit message when the user clicks a blame annotation.
/// The popup dismisses on click-outside (CM_DEACTIVATE) or Escape key.
/// Clicking a different annotation updates the content in-place without
/// flicker. The short commit hash is clickable to copy the full SHA to
/// clipboard with visual feedback. Theme colors adapt to the IDE dark/light
/// setting. Layout is defined in DX.Blame.Popup.dfm for automatic DPI scaling.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Popup;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Winapi.Windows,
  Winapi.Messages,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider,
  DX.Blame.CommitDetail;

type
  /// <summary>
  /// Borderless popup form displaying commit information for a blame annotation.
  /// </summary>
  TDXBlamePopup = class(TForm)
    HashLabel: TLabel;
    AuthorLabel: TLabel;
    DateLabel: TLabel;
    LoadingLabel: TLabel;
    MessageMemo: TMemo;
    ShowDiffButton: TButton;
    CopiedTimer: TTimer;
    procedure DoHashClick(ASender: TObject);
    procedure DoCopiedTimerTick(ASender: TObject);
    procedure DoShowDiffClick(ASender: TObject);
  private
    FFullHash: string;
    FOriginalHashText: string;
    FRepoRoot: string;
    FRelativeFilePath: string;
    FLineInfo: TBlameLineInfo;
    procedure HandleCommitDetailComplete(const ADetail: TCommitDetail);
    procedure ApplyThemeColors;
    function IsDarkTheme: Boolean;
    procedure WMMouseActivate(var AMessage: TWMMouseActivate); message WM_MOUSEACTIVATE;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  public
    /// <summary>
    /// Shows the popup for a commit, populating immediate fields and
    /// launching async fetch for full message.
    /// </summary>
    procedure ShowForCommit(const ALineInfo: TBlameLineInfo;
      const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);

    /// <summary>
    /// Updates popup content in-place when clicking a different annotation
    /// while popup is already visible.
    /// </summary>
    procedure UpdateContent(const ALineInfo: TBlameLineInfo;
      const ARepoRoot, ARelativeFilePath: string);

    /// <summary>
    /// Shows the popup without stealing focus from the editor (for hover mode).
    /// </summary>
    procedure ShowForHover(const ALineInfo: TBlameLineInfo;
      const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);

  end;

implementation

{$R *.dfm}

uses
  Vcl.Clipbrd,
  System.Math,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.Engine,
  DX.Blame.Diff.Form;

const
  // Dark theme colors
  cDarkBackground = $002D2D2D;
  cDarkForeground = $00D4D4D4;
  cDarkMemoBackground = $00252525;

  // Light theme colors
  cLightBackground = clWindow;
  cLightForeground = clWindowText;
  cLightMemoBackground = clWindow;

{ TDXBlamePopup }

procedure TDXBlamePopup.CreateParams(var AParams: TCreateParams);
begin
  inherited CreateParams(AParams);
  AParams.Style := WS_POPUP or WS_BORDER;
  AParams.ExStyle := AParams.ExStyle or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE;
end;

procedure TDXBlamePopup.WMMouseActivate(var AMessage: TWMMouseActivate);
begin
  // Allow mouse clicks on popup controls (buttons, labels) without
  // stealing keyboard focus from the code editor.
  AMessage.Result := MA_NOACTIVATE;
end;

procedure TDXBlamePopup.DoHashClick(ASender: TObject);
begin
  if FFullHash = '' then
    Exit;

  Clipboard.AsText := FFullHash;

  FOriginalHashText := HashLabel.Caption;
  HashLabel.Caption := 'Copied!';
  CopiedTimer.Enabled := False;
  CopiedTimer.Enabled := True;
end;

procedure TDXBlamePopup.DoCopiedTimerTick(ASender: TObject);
begin
  CopiedTimer.Enabled := False;
  HashLabel.Caption := FOriginalHashText;
end;

procedure TDXBlamePopup.DoShowDiffClick(ASender: TObject);
begin
  if FFullHash = '' then
    Exit;

  Hide;
  TFormDXBlameDiff.ShowDiff(FFullHash, FRepoRoot, FRelativeFilePath, FLineInfo);
end;

procedure TDXBlamePopup.HandleCommitDetailComplete(const ADetail: TCommitDetail);
begin
  LoadingLabel.Visible := False;
  MessageMemo.Visible := True;

  if ADetail.Fetched then
  begin
    MessageMemo.Text := ADetail.FullMessage;
    CommitDetailCache.Store(FFullHash, ADetail);
  end
  else
    MessageMemo.Text := '(Failed to fetch commit details)';
end;

procedure TDXBlamePopup.ShowForCommit(const ALineInfo: TBlameLineInfo;
  const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);
var
  LDetail: TCommitDetail;
  LScreenRect: TRect;
  LLeft, LTop: Integer;
begin
  ApplyThemeColors;

  FRepoRoot := ARepoRoot;
  FRelativeFilePath := ARelativeFilePath;
  FLineInfo := ALineInfo;

  if ALineInfo.IsUncommitted then
  begin
    FFullHash := '';
    HashLabel.Caption := '';
    HashLabel.Visible := False;
    if BlameEngine.Provider <> nil then
      AuthorLabel.Caption := BlameEngine.Provider.GetUncommittedAuthor
    else
      AuthorLabel.Caption := 'Not Committed';
    DateLabel.Caption := '';
    DateLabel.Visible := False;
    MessageMemo.Text := 'This line has not been committed yet.';
    MessageMemo.Visible := True;
    LoadingLabel.Visible := False;
    ShowDiffButton.Visible := False;

    // Compact layout for uncommitted
    AuthorLabel.Top := HashLabel.Top;
    MessageMemo.Top := AuthorLabel.Top + AuthorLabel.Height + 8;
    MessageMemo.Height := 32;
    Height := MessageMemo.Top + MessageMemo.Height + 10;
  end
  else
  begin
    FFullHash := ALineInfo.CommitHash;
    HashLabel.Caption := Copy(ALineInfo.CommitHash, 1, 7);
    HashLabel.Visible := True;
    AuthorLabel.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';
    DateLabel.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);
    DateLabel.Visible := True;
    ShowDiffButton.Visible := True;

    // Recalculate layout from DFM base positions
    AuthorLabel.Top := HashLabel.Top + HashLabel.Height + 6;
    DateLabel.Top := AuthorLabel.Top + AuthorLabel.Height + 4;
    LoadingLabel.Top := DateLabel.Top + DateLabel.Height + 8;
    MessageMemo.Top := DateLabel.Top + DateLabel.Height + 8;
    MessageMemo.Height := 64;

    if CommitDetailCache.TryGet(ALineInfo.CommitHash, LDetail) and LDetail.Fetched then
    begin
      LoadingLabel.Visible := False;
      MessageMemo.Visible := True;
      MessageMemo.Text := LDetail.FullMessage;
    end
    else
    begin
      LoadingLabel.Visible := True;
      MessageMemo.Visible := False;
      MessageMemo.Text := '';
      FetchCommitDetailAsync(BlameEngine.Provider, ALineInfo.CommitHash, ARepoRoot,
        ARelativeFilePath, HandleCommitDetailComplete);
    end;

    ShowDiffButton.Top := MessageMemo.Top + MessageMemo.Height + 8;
    Height := Min(400, Max(200,
      ShowDiffButton.Top + ShowDiffButton.Height + 10));
  end;

  // Position popup near click, keeping within screen bounds
  LScreenRect := Screen.MonitorFromPoint(AScreenPos).WorkareaRect;
  LLeft := AScreenPos.X;
  LTop := AScreenPos.Y + 20;

  if LLeft + Width > LScreenRect.Right then
    LLeft := LScreenRect.Right - Width;
  if LTop + Height > LScreenRect.Bottom then
    LTop := AScreenPos.Y - Height - 4;
  if LLeft < LScreenRect.Left then
    LLeft := LScreenRect.Left;
  if LTop < LScreenRect.Top then
    LTop := LScreenRect.Top;

  Left := LLeft;
  Top := LTop;

  // Use SW_SHOWNOACTIVATE to avoid stealing keyboard focus from the editor.
  // VCL's Show uses SW_SHOWNORMAL which activates the window despite
  // WS_EX_NOACTIVATE in CreateParams.
  Visible := True;
  ShowWindow(Handle, SW_SHOWNOACTIVATE);
end;

procedure TDXBlamePopup.UpdateContent(const ALineInfo: TBlameLineInfo;
  const ARepoRoot, ARelativeFilePath: string);
var
  LDetail: TCommitDetail;
begin
  ApplyThemeColors;

  FRepoRoot := ARepoRoot;
  FRelativeFilePath := ARelativeFilePath;
  FLineInfo := ALineInfo;

  if ALineInfo.IsUncommitted then
  begin
    FFullHash := '';
    HashLabel.Caption := '';
    HashLabel.Visible := False;
    if BlameEngine.Provider <> nil then
      AuthorLabel.Caption := BlameEngine.Provider.GetUncommittedAuthor
    else
      AuthorLabel.Caption := 'Not Committed';
    DateLabel.Caption := '';
    DateLabel.Visible := False;
    MessageMemo.Text := 'This line has not been committed yet.';
    MessageMemo.Visible := True;
    LoadingLabel.Visible := False;
    ShowDiffButton.Visible := False;
  end
  else
  begin
    FFullHash := ALineInfo.CommitHash;
    HashLabel.Caption := Copy(ALineInfo.CommitHash, 1, 7);
    HashLabel.Visible := True;
    AuthorLabel.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';
    DateLabel.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);
    DateLabel.Visible := True;
    ShowDiffButton.Visible := True;

    if CommitDetailCache.TryGet(ALineInfo.CommitHash, LDetail) and LDetail.Fetched then
    begin
      LoadingLabel.Visible := False;
      MessageMemo.Visible := True;
      MessageMemo.Text := LDetail.FullMessage;
    end
    else
    begin
      LoadingLabel.Visible := True;
      MessageMemo.Visible := False;
      MessageMemo.Text := '';
      FetchCommitDetailAsync(BlameEngine.Provider, ALineInfo.CommitHash, ARepoRoot,
        ARelativeFilePath, HandleCommitDetailComplete);
    end;
  end;
end;

procedure TDXBlamePopup.ShowForHover(const ALineInfo: TBlameLineInfo;
  const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);
begin
  ShowForCommit(ALineInfo, AScreenPos, ARepoRoot, ARelativeFilePath);
end;

procedure TDXBlamePopup.ApplyThemeColors;
begin
  if IsDarkTheme then
  begin
    Color := cDarkBackground;
    Font.Color := cDarkForeground;
    HashLabel.Font.Color := $00569CD6;
    AuthorLabel.Font.Color := cDarkForeground;
    DateLabel.Font.Color := $00808080;
    MessageMemo.Color := cDarkMemoBackground;
    MessageMemo.Font.Color := cDarkForeground;
    LoadingLabel.Font.Color := $00808080;
  end
  else
  begin
    Color := cLightBackground;
    Font.Color := cLightForeground;
    HashLabel.Font.Color := clBlue;
    AuthorLabel.Font.Color := cLightForeground;
    DateLabel.Font.Color := clGray;
    MessageMemo.Color := cLightMemoBackground;
    MessageMemo.Font.Color := cLightForeground;
    LoadingLabel.Font.Color := clGray;
  end;
end;

function TDXBlamePopup.IsDarkTheme: Boolean;
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
