/// <summary>
/// DX.Blame.Version
/// Version constants and plugin metadata for DX.Blame.
/// </summary>
///
/// <remarks>
/// Provides centralized version information used by the OTA registration
/// unit for splash screen, about box, and IDE integration.
///
/// After changing the numeric parts below, run build\Sync-DXBlameVersion.ps1 so
/// Win32 version resources in the .dproj files match (see README).
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Version;

interface

const
  cDXBlameMajorVersion = 1;
  cDXBlameMinorVersion = 4;
  cDXBlameRelease = 0;
  cDXBlameBuild = 0;
  cDXBlameName = 'DX.Blame';
  cDXBlameDescription = 'VCS Blame for Delphi';
  cDXBlameCopyright = 'Copyright (c) 2026 Olaf Monien';

/// <summary> Same string as the Win32 FileVersion / ProductVersion in the package .dproj. </summary>
function DXBlameVersionString: string;

implementation

uses
  System.SysUtils;

function DXBlameVersionString: string;
begin
  Result := Format('%d.%d.%d.%d', [cDXBlameMajorVersion, cDXBlameMinorVersion, cDXBlameRelease, cDXBlameBuild]);
end;

end.
