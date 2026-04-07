# =============================================================================
# Sync-DXBlameVersion.ps1
# =============================================================================
# Reads major/minor/release/build from src\DX.Blame.Version.pas and writes the
# same values into Win32 version metadata in:
#   - src\DX.Blame.dproj
#   - tests\DX.Blame.Tests.dproj
#
# The Pascal unit is the single source of truth for version numbers; the IDE
# stores duplicate strings in .dproj (FileVersion, ProductVersion, VerInfo_*).
#
# USAGE (from repo root):
#   .\build\Sync-DXBlameVersion.ps1
#   .\build\Sync-DXBlameVersion.ps1 -WhatIf
# =============================================================================

param(
    [string]$RepoRoot = "",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host $Message -ForegroundColor Cyan }

if ([string]::IsNullOrEmpty($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$versionPas = Join-Path $RepoRoot "src\DX.Blame.Version.pas"
if (-not (Test-Path $versionPas)) {
    throw "Version unit not found: $versionPas"
}

$raw = Get-Content $versionPas -Raw -Encoding UTF8

function Get-IntConst([string]$Name) {
    if ($raw -match "$([regex]::Escape($Name))\s*=\s*(\d+)\s*;") {
        return [int]$Matches[1]
    }
    throw "Constant not found or invalid: $Name"
}

$major = Get-IntConst "cDXBlameMajorVersion"
$minor = Get-IntConst "cDXBlameMinorVersion"
$release = Get-IntConst "cDXBlameRelease"
$build = Get-IntConst "cDXBlameBuild"
$ver = "$major.$minor.$release.$build"

Write-Info "DX.Blame version from DX.Blame.Version.pas: $ver ($major.$minor.$release.$build)"

function Update-DprojFile([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "File not found: $Path"
    }
    $c = Get-Content $Path -Raw -Encoding UTF8
    $orig = $c

    $c = $c -replace '(<VersionInfo Name="MajorVer">)\d+(</VersionInfo>)', "`${1}$major`${2}"
    $c = $c -replace '(<VersionInfo Name="MinorVer">)\d+(</VersionInfo>)', "`${1}$minor`${2}"
    $c = $c -replace '(<VersionInfo Name="Release">)\d+(</VersionInfo>)', "`${1}$release`${2}"
    $c = $c -replace '(<VersionInfo Name="Build">)\d+(</VersionInfo>)', "`${1}$build`${2}"
    $c = $c -replace '(<VersionInfoKeys Name="FileVersion">)[^<]*(</VersionInfoKeys>)', "`${1}$ver`${2}"
    $c = $c -replace '(<VersionInfoKeys Name="ProductVersion">)[^<]*(</VersionInfoKeys>)', "`${1}$ver`${2}"
    $c = $c -replace '(<VerInfo_Keys>FileVersion=)\d+\.\d+\.\d+\.\d+(</VerInfo_Keys>)', "`${1}$ver`${2}"

    if ($c -eq $orig) {
        Write-Host "  No changes: $Path" -ForegroundColor DarkGray
        return
    }

    if ($WhatIf) {
        Write-Host "  [WhatIf] Would update: $Path" -ForegroundColor Yellow
        return
    }

    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $c, $utf8Bom)
    Write-Host "  Updated: $Path" -ForegroundColor Green
}

Update-DprojFile (Join-Path $RepoRoot "src\DX.Blame.dproj")
Update-DprojFile (Join-Path $RepoRoot "tests\DX.Blame.Tests.dproj")

Write-Info "Done."
