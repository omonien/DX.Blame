# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- C++ header files that share an editor tab with the `.cpp` now get blame annotations. Opening a module requests blame for every module source file, save re-blames each of those files, and a one-shot renderer fallback covers a header the IDE did not name on open (fixes #13). Header enumeration uses `IOTAModule.ModuleFileCount` and `ModuleFileEditors`, which exist in Delphi 12 and Delphi 13. The Delphi 13-only renderer (`INTACodeEditorEvents370`) is unchanged.

## [1.4.0] - 2026-04-07

### Added

- Central logging infrastructure (`DX.Blame.Logging`) with an **Enable debug logging** option in IDE settings (on by default in Debug builds, off by default in Release).

### Changed

- Initialization and activation: more reliable behavior in Git and Mercurial projects without unnecessary hotkey toggling.
- Renderer and status bar: caret, ghost line, and line info stay consistent after edits (e.g. pressing Enter).
- Commit detail view: more robust loading and error handling so “Loading…” does not stick indefinitely.
- Status bar hover popup: more reliable closing when the mouse leaves both the panel and the popup.
- Settings: wider layout, adjusted grouping, and clearer guidance on hotkeys and key mappings (English, consistent with the rest of the UI).

### Fixed

- Version tests derive the expected package version from central constants (no hard-coded version string).

## [1.2.3] and earlier

Older releases can be traced via Git tags and commit history; this changelog is maintained from 1.4.0 onward.
