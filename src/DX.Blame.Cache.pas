/// <summary>
/// DX.Blame.Cache
/// Thread-safe per-file blame data cache.
/// </summary>
///
/// <remarks>
/// Stores TBlameData instances keyed by lowercase file path. All public
/// methods are guarded by a critical section for thread safety. The cache
/// owns stored TBlameData instances and frees them on removal, clear, or
/// destruction via TObjectDictionary with doOwnsValues.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Cache;

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  DX.Blame.VCS.Types;

type
  /// <summary>
  /// Thread-safe cache for blame data, keyed by normalized file path.
  /// </summary>
  TBlameCache = class
  private
    FLock: TCriticalSection;
    FData: TObjectDictionary<string, TBlameData>;
    /// <summary>Normalizes a file path to lowercase for consistent lookup.</summary>
    function NormalizePath(const APath: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Stores blame data for a file, replacing any existing entry.</summary>
    procedure Store(const AFileName: string; AData: TBlameData);
    /// <summary>Retrieves blame data for a file. Returns True if found.</summary>
    function TryGet(const AFileName: string; out AData: TBlameData): Boolean;
    /// <summary>Removes blame data for a specific file.</summary>
    procedure Invalidate(const AFileName: string);
    /// <summary>Removes all cached blame data.</summary>
    procedure Clear;
    /// <summary>Returns True if blame data exists for the given file.</summary>
    function Contains(const AFileName: string): Boolean;
  end;

implementation

uses
  System.SysUtils;

{ TBlameCache }

constructor TBlameCache.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FData := TObjectDictionary<string, TBlameData>.Create([doOwnsValues]);
end;

destructor TBlameCache.Destroy;
begin
  FData.Free;
  FLock.Free;
  inherited;
end;

function TBlameCache.NormalizePath(const APath: string): string;
begin
  Result := LowerCase(APath);
end;

procedure TBlameCache.Store(const AFileName: string; AData: TBlameData);
begin
  FLock.Enter;
  try
    FData.AddOrSetValue(NormalizePath(AFileName), AData);
  finally
    FLock.Leave;
  end;
end;

function TBlameCache.TryGet(const AFileName: string; out AData: TBlameData): Boolean;
begin
  FLock.Enter;
  try
    Result := FData.TryGetValue(NormalizePath(AFileName), AData);
  finally
    FLock.Leave;
  end;
end;

procedure TBlameCache.Invalidate(const AFileName: string);
begin
  FLock.Enter;
  try
    FData.Remove(NormalizePath(AFileName));
  finally
    FLock.Leave;
  end;
end;

procedure TBlameCache.Clear;
begin
  FLock.Enter;
  try
    FData.Clear;
  finally
    FLock.Leave;
  end;
end;

function TBlameCache.Contains(const AFileName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FData.ContainsKey(NormalizePath(AFileName));
  finally
    FLock.Leave;
  end;
end;

end.
