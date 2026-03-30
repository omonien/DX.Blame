/// <summary>
/// DX.Blame.Settings.Options
/// INTAAddInOptions adapter that embeds TFrameDXBlameSettings into the IDE Options dialog.
/// </summary>
///
/// <remarks>
/// TDXBlameAddInOptions implements the 8-method INTAAddInOptions interface, bridging
/// the IDE Options dialog lifecycle to TFrameDXBlameSettings. The frame is populated
/// in FrameCreated and saved (or discarded) in DialogClosed.
///
/// Critical: FFrame is set to nil at the end of DialogClosed because the IDE destroys
/// the frame immediately after that callback returns. Any dangling FFrame reference
/// would cause an AV when the Options dialog is opened a second time.
///
/// Registration: this class is instantiated and registered via
/// INTAEnvironmentOptionsServices in DX.Blame.Registration.Register.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Settings.Options;

interface

uses
  ToolsAPI,
  Vcl.Forms,
  DX.Blame.Settings.Frame;

type
  /// <summary>
  /// INTAAddInOptions adapter that embeds TFrameDXBlameSettings in the IDE Options
  /// dialog under Third Party > DX Blame.
  /// </summary>
  TDXBlameAddInOptions = class(TInterfacedObject, INTAAddInOptions)
  private
    FFrame: TFrameDXBlameSettings;
  public
    { INTAAddInOptions }

    /// <summary>Returns empty string to appear under the standard Third Party node.</summary>
    function GetArea: string;

    /// <summary>Returns the caption shown in the Options tree: 'DX Blame'.</summary>
    function GetCaption: string;

    /// <summary>Returns TFrameDXBlameSettings so the IDE can create the frame.</summary>
    function GetFrameClass: TCustomFrameClass;

    /// <summary>Stores the frame reference and populates controls from settings.</summary>
    procedure FrameCreated(AFrame: TCustomFrame);

    /// <summary>
    /// Saves settings if accepted. Always nils FFrame — the IDE destroys the frame
    /// immediately after this callback (Pitfall 1 prevention).
    /// </summary>
    procedure DialogClosed(Accepted: Boolean);

    /// <summary>Always returns True — all inputs are bounded (UpDown range, drop-down lists).</summary>
    function ValidateContents: Boolean;

    /// <summary>Returns 0 — no Help topic assigned.</summary>
    function GetHelpContext: Integer;

    /// <summary>Returns True so DX Blame settings are searchable via IDE Insight.</summary>
    function IncludeInIDEInsight: Boolean;
  end;

implementation

{ TDXBlameAddInOptions }

function TDXBlameAddInOptions.GetArea: string;
begin
  // Empty string = Third Party node per ToolsAPI.pas comments (Pitfall 3 prevention)
  Result := '';
end;

function TDXBlameAddInOptions.GetCaption: string;
begin
  Result := 'DX.Blame';
end;

function TDXBlameAddInOptions.GetFrameClass: TCustomFrameClass;
begin
  Result := TFrameDXBlameSettings;
end;

procedure TDXBlameAddInOptions.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := TFrameDXBlameSettings(AFrame);
  FFrame.LoadFromSettings;
end;

procedure TDXBlameAddInOptions.DialogClosed(Accepted: Boolean);
begin
  if Accepted then
    FFrame.SaveToSettings;
  // CRITICAL: nil the reference — the IDE destroys the frame after this callback
  FFrame := nil;
end;

function TDXBlameAddInOptions.ValidateContents: Boolean;
begin
  Result := True;
end;

function TDXBlameAddInOptions.GetHelpContext: Integer;
begin
  Result := 0;
end;

function TDXBlameAddInOptions.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

end.
