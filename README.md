<p align="center">
  <img src="res/logos/dx-blame-horizontal.svg" alt="DX.Blame" width="400">
</p>

<p align="center">
  <strong>Inline Git &amp; Mercurial Blame for the Delphi IDE</strong>
</p>

<p align="center">
  <a href="https://github.com/omonien/DX.Blame/releases/latest"><img src="https://img.shields.io/github/v/release/omonien/DX.Blame?style=flat-square&color=blue" alt="Latest Release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/omonien/DX.Blame?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/Delphi-12%20%7C%2013-red?style=flat-square" alt="Delphi 12 | 13">
  <img src="https://img.shields.io/badge/VCS-Git%20%7C%20Mercurial-orange?style=flat-square" alt="Git | Mercurial">
  <img src="https://img.shields.io/badge/platform-Windows-lightgrey?style=flat-square" alt="Windows">
</p>

<p align="center">
  <a href="#features">Features</a> &middot;
  <a href="#requirements">Requirements</a> &middot;
  <a href="#installation">Installation</a> &middot;
  <a href="#usage">Usage</a> &middot;
  <a href="#configuration">Configuration</a> &middot;
  <a href="#changelog">Changelog</a> &middot;
  <a href="#license">License</a>
</p>

---

DX.Blame brings GitLens-style blame annotations directly into the Delphi code editor. See who changed a line, when, and why &mdash; without leaving the IDE.

Works with **Git** and **Mercurial** repositories. Auto-detects the VCS in use.

## Features

### Inline Blame Annotations

- Blame annotation at the end of the current line (author, relative time)
- **Caret-anchored positioning** &mdash; annotation follows the caret column, preventing horizontal jumps on lines of varying length
- Theme-aware color that adapts to light and dark IDE themes
- Configurable display: author, date format, max length, summary

### Statusbar Blame

- Current line's blame info displayed in the IDE statusbar
- Click the statusbar panel to open commit details
- Runs independently of inline annotations &mdash; use both, or either

### Commit Details

- Click on an annotation to see full commit info (hash, author, date, message)
- Open a color-coded diff dialog showing exactly what changed
- Navigate to the annotated revision &mdash; opens the historical file version scrolled to the source line

### VCS Support

- **Git** via `git blame --porcelain` and `git show`
- **Mercurial** via `hg annotate` with template-based parsing and `hg cat` / `hg log`
- **TortoiseHg** context menu integration (Annotate, Log)
- Auto-detection of `.git` / `.hg` in the project directory
- Configurable VCS preference when both Git and Hg are present (remembered per project)

### IDE Integration

- Settings page under **Tools &gt; Options &gt; Third Party &gt; DX Blame**
- Toggle blame via **Ctrl+Alt+B** keyboard shortcut
- Toggle blame via editor right-click context menu
- Splash screen and About Box registration
- Asynchronous blame engine &mdash; never blocks the IDE
- Optional **debug logging** to the IDE Messages window (off by default for Release-built packages)

## Requirements

- **Delphi 12 Athens** or **Delphi 13**
- **Git** installed and available in `PATH` (for Git repositories)
- **Mercurial (hg)** installed and available in `PATH` (for Mercurial repositories)
- Windows 10 or later

### Delphi Version Compatibility

DX.Blame compiles from a single codebase on Delphi 12 and 13 using conditional compilation (`{$IF CompilerVersion}`). Delphi 13-specific features (e.g. `INTACodeEditorEvents370` for click-consuming and caret tracking) are enabled automatically when building with Delphi 13. On Delphi 12, the plugin uses the standard `INTACodeEditorEvents` interface &mdash; all core functionality (inline blame, statusbar, commit details, diff dialog) works identically.

## Installation

### From Source

1. Clone the repository:
   ```
   git clone https://github.com/omonien/DX.Blame.git
   ```

2. Open `DX.Blame.groupproj` in the Delphi IDE

3. Build the `DX.Blame.bpl` package (right-click &rarr; Build)

4. Install the package:
   - **Component &gt; Install Packages &gt; Add...**
   - Navigate to `build\Win32\Debug\DX.Blame.bpl` (or `build\Win32\Release\...` if you built **Release**)
   - Click **OK**

5. The plugin is now active. Open a file in a Git or Mercurial repository to see blame annotations.

### Build Script

Alternatively, build from the command line using the included PowerShell script:

```powershell
.\build\DelphiBuildDPROJ.ps1 -ProjectFile .\src\DX.Blame.dproj
```

This automatically detects the newest Delphi version on the system (defaults: **Debug**, **Win32**). For a Release build: add `-Config Release`. To build the test runner: use `-ProjectFile .\tests\DX.Blame.Tests.dproj`.

### Running tests

After building the test project, run DUnitX from the output folder (same **Config** / **Platform** as the build):

```powershell
.\build\Win32\Release\DX.Blame.Tests.exe -exit:Continue -consolemode:Quiet
```

For a **Debug** build, use `.\build\Win32\Debug\DX.Blame.Tests.exe` instead. All tests should pass before tagging a release.

### Where the package (.bpl) is written

The design-time package is linked into the IDE’s **Bpl** directory (see `DCC_BplOutput` in `DX.Blame.dproj`), not under `build\`. For example, with **Delphi 13 (37.0)** on Win32 you will typically get:

`%PUBLIC%\Documents\Embarcadero\Studio\37.0\Bpl\DX.Blame370.bpl`

Use that file when installing the package in the IDE or when attaching a binary to a GitHub release.

## Usage

### Viewing Blame

Open any source file in a Git or Mercurial repository. Blame annotations appear automatically at the end of each line showing the author and relative time.

### Keyboard Shortcut

Press **Ctrl+Alt+B** to toggle blame annotations on and off.

### Context Menu

Right-click in the editor to access:
- **Enable/Disable Blame (Ctrl+Alt+B)** &mdash; quick toggle with checkmark
- **Show revision...** &mdash; open the historical file version at the annotated commit, scrolled to the current line

### Commit Details

Click on a blame annotation (or the statusbar panel) to see full commit details including hash, author, date, and message. From there, open the **Diff** dialog to see color-coded changes.

## Configuration

Access settings via **Tools &gt; Options &gt; Third Party &gt; DX Blame**.

| Setting | Description | Default |
|---------|-------------|---------|
| Show Author | Display author name in annotations | On |
| Date Format | Relative ("3 days ago") or absolute | Relative |
| Show Commit Summary | Include commit subject in the annotation text | Off |
| Max Length | Maximum length of the annotation string (20&ndash;200) | 80 |
| Annotation Color | Auto (theme-derived) or custom color | Auto |
| Annotation Position | Caret-anchored or right-aligned in editor | Caret-anchored |
| Popup Trigger | Hover over annotation or click on hash link | Hover |
| Show Inline | Enable/disable inline annotations | On |
| Show in Statusbar | Enable/disable statusbar blame | On |
| VCS Preference | Auto / Git / Mercurial | Auto |
| Hotkey | Keyboard shortcut for toggle | Ctrl+Alt+B |
| Enable debug logging | Write diagnostic lines to IDE Messages | On in **Debug** builds, off in **Release** builds |

Settings are stored in `%APPDATA%\DX.Blame\settings.ini`.

## Changelog

Release notes and version history: [CHANGELOG.md](CHANGELOG.md).

### Versioning

Version numbers are defined only in `src/DX.Blame.Version.pas` (`cDXBlameMajorVersion` … `cDXBlameBuild`). The string shown in the IDE (splash, about) comes from `DXBlameVersionString`, which is derived from those four values.

The Delphi project files duplicate Win32 version metadata (`FileVersion` / `ProductVersion` in the `.dproj` files). After changing the numeric constants, run **`build/Sync-DXBlameVersion.ps1`** so the package and test projects stay aligned. Use `-WhatIf` to preview changes.

## Project Structure

```
DX.Blame/
  src/               Source code (33 units in the design-time package)
    DX.Blame.dpk     Design-time package
    DX.Blame.dproj   Project file
  res/               Resources (splash icon, logos)
  build/             Build output, DelphiBuildDPROJ.ps1, Sync-DXBlameVersion.ps1
  tests/             DUnitX test project
  docs/              Documentation
  libs/              External dependencies (Git submodules)
  CHANGELOG.md       Release notes
```

## License

[MIT License](LICENSE) &mdash; Copyright &copy; 2026 Olaf Monien
