/// <summary>
/// DX.Blame.Logging
/// Centralized runtime-configurable logging for DX.Blame.
/// </summary>
///
/// <remarks>
/// Provides a single logging API for lifecycle and debug messages. Output is
/// routed to the IDE message view via IOTAMessageServices when available.
/// Debug logs are controlled at runtime through BlameSettings.EnableDebugLogging.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Logging;

interface

procedure LogDebug(const ACategory, AMessage: string);
procedure LogInfo(const ACategory, AMessage: string);
procedure LogWarn(const ACategory, AMessage: string);
procedure LogError(const ACategory, AMessage: string);

implementation

uses
  System.SysUtils,
  ToolsAPI,
  DX.Blame.Settings;

procedure LogToIDE(const ALevel, ACategory, AMessage: string; AIsDebug: Boolean);
var
  LMsgServices: IOTAMessageServices;
  LLine: string;
begin
  if AIsDebug and (not BlameSettings.EnableDebugLogging) then
    Exit;

  if not Supports(BorlandIDEServices, IOTAMessageServices, LMsgServices) then
    Exit;

  if ACategory <> '' then
    LLine := Format('DX.Blame [%s] [%s] %s', [ALevel, ACategory, AMessage])
  else
    LLine := Format('DX.Blame [%s] %s', [ALevel, AMessage]);

  LMsgServices.AddTitleMessage(LLine);
end;

procedure LogDebug(const ACategory, AMessage: string);
begin
  LogToIDE('DEBUG', ACategory, AMessage, True);
end;

procedure LogInfo(const ACategory, AMessage: string);
begin
  LogToIDE('INFO', ACategory, AMessage, False);
end;

procedure LogWarn(const ACategory, AMessage: string);
begin
  LogToIDE('WARN', ACategory, AMessage, False);
end;

procedure LogError(const ACategory, AMessage: string);
begin
  LogToIDE('ERROR', ACategory, AMessage, False);
end;

end.
