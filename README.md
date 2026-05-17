# yabai-space-marker

`yabai-space-marker` is a macOS floating side panel built with SwiftUI and AppKit. It shows your current `yabai` spaces and lets you jump to any space with one click.

The current UI uses a compact liquid-glass style with expand/collapse behavior, focused-space emphasis, spring-based transitions, and automatic light/dark mode support.

<video src="https://private-user-images.githubusercontent.com/3580943/593658768-f90eadd8-57f3-4f1e-b409-4a3865676e63.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Nzg5OTcxOTYsIm5iZiI6MTc3ODk5Njg5NiwicGF0aCI6Ii8zNTgwOTQzLzU5MzY1ODc2OC1mOTBlYWRkOC01N2YzLTRmMWUtYjQwOS00YTM4NjU2NzZlNjMubXA0P1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDUxNyUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA1MTdUMDU0ODE2WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9NWEyNTY1YTc3OGEwYmJiNWQ3ZDFhODk4MjlhNmVmNTBlMDAyZmVjOTM5MTBhZDYxODZhMzZmZjEyMTE0ZDk2NSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPXZpZGVvJTJGbXA0In0.iSAvSeK27oNOmLHjutfsiWrNccVQDHeO518OKs2sBxg" controls width="800"></video>

## Features

- Floating panel anchored on the left or right side of the screen
- Shows the current display's spaces
- Highlights the currently focused space
- Click any space to focus it immediately
- Expands on space changes, then auto-collapses
- Compact liquid-glass UI
- Supports system / light / dark appearance modes
- Adaptive refresh scheduling to reduce idle CPU usage while keeping interactions responsive
- Hover-aware interactive refresh: high-frequency polling is only used while the panel is expanded or actively hovered
- Command timeout protection for `yabai` queries/focus calls to avoid stuck subprocesses consuming resources
- Silent background refreshes to avoid unnecessary loading-state redraws during steady-state polling
- Refresh loop pauses automatically while displays are asleep and resumes on wake
- `yabai` subprocess timeout waiting uses event-driven completion instead of a spin/sleep polling loop
- Coalesced window/layout updates for smoother animations and less redundant work
- Right-click menu with Refresh and Quit actions
- Footer controls for Settings, Refresh, and Quit
- Built-in settings page for appearance mode, panel position, auto-collapse timeout, and launch at login

## How it works

The app does not manage spaces directly. It shells out to the `yabai` CLI:

- Query spaces: `yabai -m query --spaces`
- Focus a space: `yabai -m space --focus <index>`

The app refreshes space state with adaptive scheduling instead of a constant high-frequency polling loop. It only uses high-frequency refresh while the panel is expanded or the pointer is actively hovering over it, and it adds timeout protection around `yabai` subprocesses so hung commands do not keep consuming resources.

### Panel position

The panel supports two positions:

- `left` (default)
- `right`

You can configure it in any of these ways:

```bash
# launch argument
open build-signed/Build/Products/Debug/yabai-space-marker.app --args --position right

# or environment variable
export YABAI_SPACE_MARKER_POSITION=right
```

You can also persist the setting with macOS defaults:

```bash
defaults write com.nicocolab.yabai-space-marker position -string right
```

If no position is configured, the panel stays on the left.

### Settings page

Open the app settings to configure:

- appearance mode (`system` / `light` / `dark`)
- panel position (`left` / `right`)
- auto-collapse timeout
- launch at login
- quit the app

The panel temporarily expands in these cases:

- On startup
- On manual refresh
- When the active macOS space changes
- When you click a space to focus it

## Requirements

You need a working `yabai` setup before running this app.

### Required

- macOS
- `yabai` installed
- `yabai` can run successfully from Terminal
- Your `yabai` configuration and permissions already allow querying spaces and focusing spaces

### `yabai` executable lookup order

The app resolves `yabai` in this order:

1. `YABAI_BIN`
2. `yabai` found in the current `PATH`
3. Fixed fallback paths:
   - `/opt/homebrew/bin/yabai`
   - `/opt/homebrew/sbin/yabai`
   - `/usr/local/bin/yabai`
   - `/usr/local/sbin/yabai`

If you installed `yabai` somewhere else, set the path explicitly:

```bash
export YABAI_BIN="/your/path/to/yabai"
```

## Build and run

### Xcode

1. Open `yabai-space-marker.xcodeproj`
2. Select your signing team
3. Run the `yabai-space-marker` scheme

### Command line

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project yabai-space-marker.xcodeproj \
  -scheme yabai-space-marker \
  -configuration Debug \
  -derivedDataPath build-signed \
  build
```

The default app bundle path is:

```text
build-signed/Build/Products/Debug/yabai-space-marker.app
```

## Project structure

```text
.
├── yabai-space-marker/
│   ├── ContentView.swift
│   ├── yabai_space_markerApp.swift
│   └── Assets.xcassets/
└── yabai-space-marker.xcodeproj/
```

### Key files

- `yabai-space-marker/ContentView.swift`
  - Panel UI
  - Liquid-glass surface components
  - Expand/collapse transitions
  - `YabaiSpacesMonitor` data and interaction logic

- `yabai-space-marker/yabai_space_markerApp.swift`
  - App entry point
  - `NSPanel` creation and layout
  - Panel positioning and resizing when the screen or active space changes

## Appearance

The panel supports three appearance modes:

- **System**: follows the current macOS appearance automatically
- **Light mode**: bright frosted-glass surface with subtle blue accents
- **Dark mode**: darker glass treatment with elevated contrast, softer borders, and tuned glow/shadow balance

You can switch appearance directly from the settings page.

## UI model

The panel has two presentation states:

- **Collapsed**: low-obstruction compact state with core status only
- **Expanded**: full header, space list, footer copy, and controls

The focused space is emphasized with a stronger tone, outline, shadow, and active state treatment.

## Troubleshooting

### `yabai` could not be found

Check the following:

- `yabai -m query --spaces` works in Terminal
- `yabai` is in `PATH`, or `YABAI_BIN` is set
- Your install path is one of the supported lookup locations

### Spaces are visible, but switching fails

This is usually a `yabai` permissions or configuration issue, not a UI issue. Confirm that:

- `yabai -m space --focus <index>` works in Terminal
- Your `yabai` permissions, configuration, and scripting addition setup are correct for your environment

### Code signing fails during build

The project uses Xcode automatic signing by default. On your machine, select your own team in Xcode or adjust signing settings to match your local setup.

## Implementation notes

- Uses real `yabai` data only; there is no runtime mock path
- App Sandbox is disabled so the app can execute the external `yabai` binary
- Runs as an accessory app instead of a normal Dock app

## Possible next improvements

- Richer hover and pointer feedback
- Configurable auto-collapse duration
- More precise positioning behavior for multi-display setups
- A proper preferences screen
