/// <summary>
/// DX.Blame.Engine
/// Central orchestrator for the async blame data pipeline.
/// </summary>
///
/// <remarks>
/// Ties together VCS provider dispatch, process execution, porcelain parsing,
/// and caching into a complete async blame lifecycle. TBlameEngine manages
/// background threads for blame execution, debounce timers for
/// save-triggered re-blame, cancellation on file close, retry on transient
/// errors, and full cleanup on project switch. The singleton BlameEngine
/// function provides lazy-initialized global access.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Engine;

interface

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  Vcl.ExtCtrls,
  Winapi.Windows,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider,
  DX.Blame.Cache,
  DX.Blame.ModuleFiles;

type
  TBlameThread = class;

  /// <summary>
  /// Central orchestrator tying VCS provider, process, parser, and cache together.
  /// Manages async blame execution with threading, debounce, cancellation, and retry.
  /// </summary>
  TBlameEngine = class
  private
    FCache: TBlameCache;
    FProvider: IVCSProvider;
    FRepoRoot: string;
    FFileRepoRoots: TDictionary<string, string>;
    FVCSAvailable: Boolean;
    FVCSNotified: Boolean;
    FActiveThreads: TDictionary<string, TBlameThread>;
    FDebounceTimers: TDictionary<string, TTimer>;
    FRetryTimers: TDictionary<string, TTimer>;
    FRetryFailed: TDictionary<string, Boolean>;
    FRequestGuard: TBlameRequestGuard;
    FLock: TCriticalSection;

    procedure HandleBlameComplete(const AFileName: string; AData: TBlameData);
    procedure HandleBlameError(const AFileName: string; const AError: string);
    procedure DoRequestBlame(ASender: TObject);
    procedure DoRetryBlame(ASender: TObject);
    function IsSourceFile(const AFileName: string): Boolean;
    procedure CancelAllThreads;
    procedure ClearAllTimers;
    /// <summary>Removes thread from active dictionary. Called by thread before FreeOnTerminate.</summary>
    procedure UnregisterThread(const AKey: string);
    procedure MarkBlameRequested(const AFileName: string);
    procedure UnmarkBlameRequested(const AFileName: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Detects VCS executable and repository root for the given project path.</summary>
    procedure Initialize(const AProjectPath: string);
    /// <summary>Starts an async blame for the given file.</summary>
    procedure RequestBlame(const AFileName: string);
    /// <summary>Starts a debounced blame request (used after file save).</summary>
    procedure RequestBlameDebounced(const AFileName: string);
    /// <summary>
    /// True after RequestBlame or RequestBlameDebounced has been called for
    /// this file since the last CancelAndRemove or project switch.
    /// The renderer uses this as a one-shot guard: a cache miss for a file
    /// that was never requested calls RequestBlameDebounced once.
    /// </summary>
    function WasBlameRequested(const AFileName: string): Boolean;
    /// <summary>Cancels any pending blame and removes file from cache.</summary>
    procedure CancelAndRemove(const AFileName: string);
    /// <summary>Handles project switch: cancels all, clears cache, re-initializes.</summary>
    procedure OnProjectSwitch(const ANewProjectPath: string);
    /// <summary>
    /// Returns the root of the repository that actually contains AFileName.
    /// For files in a git submodule or nested repository this is the
    /// submodule's own root, otherwise it equals RepoRoot.
    /// </summary>
    function RepoRootForFile(const AFileName: string): string;

    /// <summary>Thread-safe blame data cache.</summary>
    property Cache: TBlameCache read FCache;
    /// <summary>True if VCS executable and repository root were found.</summary>
    property VCSAvailable: Boolean read FVCSAvailable;
    /// <summary>Root directory of the current repository.</summary>
    property RepoRoot: string read FRepoRoot;
    /// <summary>The active VCS provider instance.</summary>
    property Provider: IVCSProvider read FProvider;
  end;

  /// <summary>
  /// Background thread that executes blame via VCS provider and delivers results via TThread.Queue.
  /// </summary>
  TBlameThread = class(TThread)
  private
    FFileName: string;
    FRepoRoot: string;
    FProvider: IVCSProvider;
    FProcessHandle: THandle;
    FEngine: TBlameEngine;
  protected
    procedure Execute; override;
  public
    constructor Create(AEngine: TBlameEngine; AProvider: IVCSProvider;
      const ARepoRoot, AFileName: string);
    procedure Cancel;
  end;

/// <summary>Returns the singleton TBlameEngine instance (lazy-initialized).</summary>
function BlameEngine: TBlameEngine;

implementation

uses
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.VCS.Process,
  DX.Blame.VCS.Discovery,
  DX.Blame.Git.Discovery,
  DX.Blame.Hg.Discovery,
  DX.Blame.CommitDetail,
  DX.Blame.Logging,
  DX.Blame.Settings;

var
  GBlameEngine: TBlameEngine;

function BlameEngine: TBlameEngine;
begin
  if GBlameEngine = nil then
    GBlameEngine := TBlameEngine.Create;
  Result := GBlameEngine;
end;

{ TBlameThread }

constructor TBlameThread.Create(AEngine: TBlameEngine; AProvider: IVCSProvider;
  const ARepoRoot, AFileName: string);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FEngine := AEngine;
  FProvider := AProvider;
  FRepoRoot := ARepoRoot;
  FFileName := AFileName;
  FProcessHandle := 0;
end;

procedure TBlameThread.Execute;
var
  LOutput: string;
  LExitCode: Integer;
  LLines: TArray<TBlameLineInfo>;
  LData: TBlameData;
  LFileName: string;
  LEngine: TBlameEngine;
begin
  LFileName := FFileName;
  LEngine := FEngine;
  try
    LExitCode := FProvider.ExecuteBlame(FRepoRoot, FFileName, LOutput, FProcessHandle);

    if Terminated then
      Exit;

    if LExitCode = 0 then
    begin
      LLines := FProvider.ParseBlameOutput(LOutput);
      LData := TBlameData.Create(LFileName);
      LData.Lines := LLines;
      LData.Timestamp := Now;

      TThread.Queue(nil,
        procedure
        begin
          LEngine.HandleBlameComplete(LFileName, LData);
        end);
    end
    else
    begin
      TThread.Queue(nil,
        procedure
        begin
          LEngine.HandleBlameError(LFileName, LOutput);
        end);
    end;
  finally
    // Always unregister — prevents dangling pointer in FActiveThreads when
    // Execute exits via exception, Terminated check, or normal completion.
    // Safe to call even if CancelAndRemove already removed the entry.
    LEngine.UnregisterThread(LowerCase(LFileName));
  end;
end;

procedure TBlameThread.Cancel;
begin
  Terminate;
  TVCSProcess.CancelProcess(FProcessHandle);
end;

{ TBlameEngine }

constructor TBlameEngine.Create;
begin
  inherited Create;
  FCache := TBlameCache.Create;
  FActiveThreads := TDictionary<string, TBlameThread>.Create;
  FDebounceTimers := TDictionary<string, TTimer>.Create;
  FRetryTimers := TDictionary<string, TTimer>.Create;
  FRetryFailed := TDictionary<string, Boolean>.Create;
  FRequestGuard := TBlameRequestGuard.Create;
  FFileRepoRoots := TDictionary<string, string>.Create;
  FLock := TCriticalSection.Create;
  FVCSAvailable := False;
  FVCSNotified := False;
end;

destructor TBlameEngine.Destroy;
begin
  CancelAllThreads;
  ClearAllTimers;
  FRetryFailed.Free;
  FFileRepoRoots.Free;
  FRetryTimers.Free;
  FDebounceTimers.Free;
  FActiveThreads.Free;
  FRequestGuard.Free;
  FCache.Free;
  FLock.Free;
  inherited;
end;

procedure TBlameEngine.Initialize(const AProjectPath: string);
begin
  FProvider := TVCSDiscovery.DetectProvider(AProjectPath, FRepoRoot);

  if FProvider = nil then
  begin
    FVCSAvailable := False;
    if not FVCSNotified then
    begin
      FVCSNotified := True;
      LogWarn('Engine', 'No VCS repository detected. Blame features disabled.');
    end;
    Exit;
  end;

  FVCSAvailable := True;
  if not BlameSettings.Enabled then
  begin
    BlameSettings.Enabled := True;
    BlameSettings.Save;
    LogInfo('Engine', 'Auto-enabled DX.Blame for detected repository');
  end;
  LogInfo('Engine', FProvider.GetDisplayName + ' repository detected at ' + FRepoRoot);
end;

procedure TBlameEngine.MarkBlameRequested(const AFileName: string);
begin
  if (AFileName = '') or (FRequestGuard = nil) then
    Exit;
  FLock.Enter;
  try
    FRequestGuard.Mark(AFileName);
  finally
    FLock.Leave;
  end;
end;

procedure TBlameEngine.UnmarkBlameRequested(const AFileName: string);
begin
  if (AFileName = '') or (FRequestGuard = nil) then
    Exit;
  FLock.Enter;
  try
    FRequestGuard.Remove(AFileName);
  finally
    FLock.Leave;
  end;
end;

function TBlameEngine.WasBlameRequested(const AFileName: string): Boolean;
begin
  Result := False;
  if (AFileName = '') or (FRequestGuard = nil) then
    Exit;
  FLock.Enter;
  try
    Result := FRequestGuard.Contains(AFileName);
  finally
    FLock.Leave;
  end;
end;

procedure TBlameEngine.RequestBlame(const AFileName: string);
var
  LKey: string;
  LThread: TBlameThread;
  LExisting: TBlameThread;
begin
  // Record the request before any early exit. The renderer paint loop checks
  // WasBlameRequested on a cache miss and must not call back on every line.
  MarkBlameRequested(AFileName);

  // Lazy initialization: during IDE startup, Register may be called before
  // any project is active, leaving FVCSAvailable = False. Try from file path.
  if not FVCSAvailable and (FRepoRoot = '') then
    Initialize(ExtractFileDir(AFileName));

  if not FVCSAvailable then
  begin
    LogDebug('Engine', 'Skip blame (VCS not available) ' + ExtractFileName(AFileName));
    Exit;
  end;

  if not IsSourceFile(AFileName) then
  begin
    LogDebug('Engine', 'Skip blame (not source/out of repo) ' + ExtractFileName(AFileName));
    Exit;
  end;

  LogDebug('Engine', 'Requesting blame for ' + ExtractFileName(AFileName));

  LKey := LowerCase(AFileName);

  FLock.Enter;
  try
    if FActiveThreads.TryGetValue(LKey, LExisting) then
    begin
      LExisting.Cancel;
      FActiveThreads.Remove(LKey);
    end;
  finally
    FLock.Leave;
  end;

  LThread := TBlameThread.Create(Self, FProvider, RepoRootForFile(AFileName), AFileName);

  FLock.Enter;
  try
    FActiveThreads.AddOrSetValue(LKey, LThread);
  finally
    FLock.Leave;
  end;

  LThread.Start;
end;

procedure TBlameEngine.RequestBlameDebounced(const AFileName: string);
var
  LKey: string;
  LTimer: TTimer;
begin
  // Mark before the VCS check so a cache-miss paint calls this only once,
  // even when blame cannot start yet.
  MarkBlameRequested(AFileName);

  if not FVCSAvailable then
    Exit;

  LKey := LowerCase(AFileName);

  FLock.Enter;
  try
    if FDebounceTimers.TryGetValue(LKey, LTimer) then
    begin
      LTimer.Enabled := False;
      LTimer.Enabled := True;
    end
    else
    begin
      LTimer := TTimer.Create(nil);
      LTimer.Interval := cDefaultDebounceMs;
      LTimer.OnTimer := DoRequestBlame;
      LTimer.Enabled := True;
      FDebounceTimers.AddOrSetValue(LKey, LTimer);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TBlameEngine.DoRequestBlame(ASender: TObject);
var
  LTimer: TTimer;
  LKey: string;
  LPair: TPair<string, TTimer>;
begin
  LTimer := ASender as TTimer;
  LTimer.Enabled := False;

  LKey := '';
  FLock.Enter;
  try
    for LPair in FDebounceTimers do
    begin
      if LPair.Value = LTimer then
      begin
        LKey := LPair.Key;
        Break;
      end;
    end;

    if LKey <> '' then
      FDebounceTimers.Remove(LKey);
  finally
    FLock.Leave;
  end;

  LTimer.Free;

  if LKey <> '' then
    RequestBlame(LKey);
end;

procedure TBlameEngine.CancelAndRemove(const AFileName: string);
var
  LKey: string;
  LThread: TBlameThread;
  LTimer: TTimer;
begin
  LKey := LowerCase(AFileName);

  FLock.Enter;
  try
    if FActiveThreads.TryGetValue(LKey, LThread) then
    begin
      LThread.Cancel;
      FActiveThreads.Remove(LKey);
    end;

    if FDebounceTimers.TryGetValue(LKey, LTimer) then
    begin
      LTimer.Enabled := False;
      LTimer.Free;
      FDebounceTimers.Remove(LKey);
    end;
  finally
    FLock.Leave;
  end;

  FCache.Invalidate(AFileName);
  UnmarkBlameRequested(AFileName);
end;

procedure TBlameEngine.OnProjectSwitch(const ANewProjectPath: string);
begin
  CancelAllThreads;
  ClearAllTimers;
  FCache.Clear;
  CommitDetailCache.Clear;
  FRetryFailed.Clear;
  FLock.Enter;
  try
    FFileRepoRoots.Clear;
    if FRequestGuard <> nil then
      FRequestGuard.Clear;
  finally
    FLock.Leave;
  end;
  FProvider := nil;
  // Clear both discovery caches to ensure fresh detection on project switch
  DX.Blame.Git.Discovery.ClearDiscoveryCache;
  DX.Blame.Hg.Discovery.ClearHgDiscoveryCache;
  FVCSNotified := False;
  Initialize(ANewProjectPath);
end;

procedure TBlameEngine.UnregisterThread(const AKey: string);
begin
  FLock.Enter;
  try
    FActiveThreads.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TBlameEngine.HandleBlameComplete(const AFileName: string; AData: TBlameData);
var
  LKey: string;
  LEditorServices: INTACodeEditorServices;
begin
  LKey := LowerCase(AFileName);

  LogDebug('Engine', 'Blame complete for ' + ExtractFileName(AFileName) +
    ' (' + IntToStr(Length(AData.Lines)) + ' lines)');

  FLock.Enter;
  try
    FRetryFailed.Remove(LKey);
  finally
    FLock.Leave;
  end;

  FCache.Store(AFileName, AData);

  // Trigger editor repaint so renderer picks up new blame data
  LEditorServices := nil;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LEditorServices) then
    LEditorServices.InvalidateTopEditor;
end;

procedure TBlameEngine.HandleBlameError(const AFileName: string; const AError: string);
var
  LKey: string;
  LAlreadyRetried: Boolean;
  LRetryTimer: TTimer;
begin
  LKey := LowerCase(AFileName);

  LogDebug('Engine', 'Blame error for ' + ExtractFileName(AFileName) + ': ' + Copy(AError, 1, 200));

  FLock.Enter;
  try
    LAlreadyRetried := FRetryFailed.ContainsKey(LKey);
  finally
    FLock.Leave;
  end;

  if not LAlreadyRetried then
  begin
    FLock.Enter;
    try
      FRetryFailed.AddOrSetValue(LKey, True);
    finally
      FLock.Leave;
    end;

    LRetryTimer := TTimer.Create(nil);
    LRetryTimer.Interval := cDefaultRetryDelayMs;
    LRetryTimer.OnTimer := DoRetryBlame;
    LRetryTimer.Enabled := True;

    FLock.Enter;
    try
      FRetryTimers.AddOrSetValue(LKey, LRetryTimer);
    finally
      FLock.Leave;
    end;
  end
  else
  begin
    LogError('Engine', 'Blame failed for ' + AFileName + ': ' + AError);
  end;
end;

procedure TBlameEngine.DoRetryBlame(ASender: TObject);
var
  LTimer: TTimer;
  LKey: string;
  LPair: TPair<string, Boolean>;
  LTimerPair: TPair<string, TTimer>;
begin
  LTimer := ASender as TTimer;
  LTimer.Enabled := False;

  FLock.Enter;
  try
    for LTimerPair in FRetryTimers do
    begin
      if LTimerPair.Value = LTimer then
      begin
        FRetryTimers.Remove(LTimerPair.Key);
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;

  LTimer.Free;

  LKey := '';
  FLock.Enter;
  try
    for LPair in FRetryFailed do
    begin
      if not FActiveThreads.ContainsKey(LPair.Key) then
      begin
        LKey := LPair.Key;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;

  if LKey <> '' then
    RequestBlame(LKey);
end;

function TBlameEngine.RepoRootForFile(const AFileName: string): string;
var
  LDir: string;
  LKey: string;
begin
  Result := FRepoRoot;
  if (FProvider = nil) or (AFileName = '') then
    Exit;

  LDir := ExtractFileDir(AFileName);
  if LDir = '' then
    Exit;
  LKey := LowerCase(LDir);

  FLock.Enter;
  try
    if FFileRepoRoots.TryGetValue(LKey, Result) then
      Exit;
  finally
    FLock.Leave;
  end;

  // Resolve the innermost repository containing the file's directory,
  // e.g. a git submodule (issue #14). Fall back to the project root.
  Result := FProvider.FindRepoRoot(LDir);
  if Result = '' then
    Result := FRepoRoot
  else if not SameText(ExcludeTrailingPathDelimiter(Result),
    ExcludeTrailingPathDelimiter(FRepoRoot)) then
    LogDebug('Engine', 'Using nested repository root ' + Result + ' for ' +
      ExtractFileName(AFileName));

  FLock.Enter;
  try
    FFileRepoRoots.AddOrSetValue(LKey, Result);
  finally
    FLock.Leave;
  end;
end;

function TBlameEngine.IsSourceFile(const AFileName: string): Boolean;
var
  LFileLower: string;
  LRootLower: string;
begin
  Result := ExtractFileExt(AFileName) <> '';

  // Only blame files inside the repository
  if Result and (FRepoRoot <> '') then
  begin
    LFileLower := LowerCase(AFileName);
    LRootLower := LowerCase(IncludeTrailingPathDelimiter(FRepoRoot));
    Result := LFileLower.StartsWith(LRootLower);
  end;
end;

procedure TBlameEngine.CancelAllThreads;
var
  LPair: TPair<string, TBlameThread>;
begin
  FLock.Enter;
  try
    for LPair in FActiveThreads do
      LPair.Value.Cancel;
    FActiveThreads.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TBlameEngine.ClearAllTimers;
var
  LPair: TPair<string, TTimer>;
begin
  FLock.Enter;
  try
    for LPair in FDebounceTimers do
    begin
      LPair.Value.Enabled := False;
      LPair.Value.Free;
    end;
    FDebounceTimers.Clear;

    for LPair in FRetryTimers do
    begin
      LPair.Value.Enabled := False;
      LPair.Value.Free;
    end;
    FRetryTimers.Clear;
  finally
    FLock.Leave;
  end;
end;

initialization

finalization
  FreeAndNil(GBlameEngine);

end.
