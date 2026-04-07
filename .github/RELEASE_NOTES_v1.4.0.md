## DX.Blame 1.4.0

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

### Binary

- **DX.Blame370.bpl** — design-time package built with **Delphi 13 (37.0), Win32**. Install via **Component → Install Packages → Add** and select this `.bpl` file. Requires Git and/or Mercurial on `PATH` as described in the [README](https://github.com/omonien/DX.Blame/blob/master/README.md).

Full history: [CHANGELOG.md](https://github.com/omonien/DX.Blame/blob/master/CHANGELOG.md).
