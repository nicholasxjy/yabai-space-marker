# yabai-space-marker

`yabai-space-marker` is a small macOS notch panel built with SwiftUI and AppKit. It stays attached to the top center of the current screen and shows the currently focused `yabai` space.

The UI uses a fixed liquid-glass panel with focused-space emphasis, numeric text transitions, a brief accent glow, and a jelly-style scale response whenever the active space changes.

<video src="https://private-user-images.githubusercontent.com/3580943/593658768-f90eadd8-57f3-4f1e-b409-4a3865676e63.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Nzg5OTcxOTYsIm5iZiI6MTc3ODk5Njg5NiwicGF0aCI6Ii8zNTgwOTQzLzU5MzY1ODc2OC1mOTBlYWRkOC01N2YzLTRmMWUtYjQwOS00YTM4NjU2NzZlNjMubXA0P1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDUxNyUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA1MTdUMDU0ODE2WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9NWEyNTY1YTc3OGEwYmJiNWQ3ZDFhODk4MjlhNmVmNTBlMDAyZmVjOTM5MTBhZDYxODZhMzZmZjEyMTE0ZDk2NSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPXZpZGVvJTJGbXA0In0.iSAvSeK27oNOmLHjutfsiWrNccVQDHeO518OKs2sBxg" controls width="800"></video>

## Features

- Fixed top-center notch panel on the current screen
- Shows only the active space number, label or `Space N`, display, and sync/error state
- Numeric transition for space number changes
- Accent glow pulse and subtle jelly animation on space changes
- Compact liquid-glass UI
- Supports system / light / dark appearance modes
- Adaptive refresh scheduling to reduce idle CPU usage while keeping hover/manual updates responsive
- Command timeout protection for `yabai` queries/focus calls to avoid stuck subprocesses consuming resources
- Silent background refreshes to avoid unnecessary loading-state redraws during steady-state polling
- Refresh loop pauses automatically while displays are asleep and resumes on wake
- `yabai` subprocess timeout waiting uses event-driven completion instead of a spin/sleep polling loop
- Coalesced window/layout updates for smoother animations and less redundant work
- Inline total-space count, Settings, and Quit controls on the notch
- Right-click menu with Settings, Refresh, and Quit actions
- Built-in settings page for appearance mode, launch at login, and quit

## How it works

The app does not manage spaces directly. It shells out to the `yabai` CLI:

- Query spaces: `yabai -m query --spaces`
- Focus a space: `yabai -m space --focus <index>`

The app refreshes space state with adaptive scheduling instead of a constant high-frequency polling loop. It uses a faster refresh cadence while the pointer is over the panel and adds timeout protection around `yabai` subprocesses so hung commands do not keep consuming resources.

When macOS reports an active-space change, or when a focus request completes, the app refreshes `yabai` state and updates the notch content to the actual focused space.

### Settings page

Open the app settings to configure:

- appearance mode (`system` / `light` / `dark`)
- launch at login
- quit the app

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
  - Notch panel UI
  - Liquid-glass surface components
  - Space-change glow and jelly animation
  - `YabaiSpacesMonitor` data and interaction logic

- `yabai-space-marker/yabai_space_markerApp.swift`
  - App entry point
  - `NSPanel` creation and layout
  - Fixed top-center panel placement when the screen or active space changes

## Appearance

The panel supports three appearance modes:

- **System**: follows the current macOS appearance automatically
- **Light mode**: bright frosted-glass surface with subtle blue accents
- **Dark mode**: darker glass treatment with elevated contrast, softer borders, and tuned glow/shadow balance

You can switch appearance directly from the settings page.

## UI model

The app uses one fixed notch panel. It does not show a space list or offer panel placement controls. The right side of the notch shows the total space count, Settings, and Quit controls; the right-click menu also provides Settings, Refresh, and Quit.

If `yabai` is unavailable or returns an error, the same compact notch shows an error state without resizing.

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
