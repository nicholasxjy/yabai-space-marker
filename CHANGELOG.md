# Changelog

## 1.0.0 - 2026-05-23

### Features
- Center the active-space context inside a compact native notch panel
- Refresh the panel shell with a hardware-matching notch silhouette, sticky liquid stretch animation, and animated top-edge flow line
- Refresh the app icon set for the 1.0 release

### Fixes
- Anchor the panel to the physical top-center notch area using full-screen coordinates above the menu bar
- Simplify the settings window to focus on launch-at-login and app controls for a more consistent native experience

## 0.0.6 - 2026-05-18

### Features
- Add dragging for the collapsed panel so it can be repositioned directly

### Fixes
- Improve collapsed-panel dragging reliability by tracking mouse movement in global screen coordinates
- Polish the collapsed-panel hover state with a clearer draggable affordance
- Update README for the latest panel interaction behavior

## 0.0.5 - 2026-05-17

### Features
- Add a dedicated settings window for panel configuration and app controls
- Add panel position controls, auto-collapse timeout, launch-at-login support, and appearance mode switching
- Add Settings access in both expanded and collapsed panel states
- Refresh the floating panel with a cyberpunk-inspired neon HUD treatment while keeping behavior unchanged
- Redesign the settings window with a cleaner macOS System Settings-inspired layout

### Fixes
- Fix settings window opening failures by managing the settings window explicitly in AppKit
- Fix right-side panel drift after expand/collapse transitions
- Fix a crash when switching macOS spaces caused by repeated AppKit constraint update passes
- Simplify the refreshed panel styling for clearer hierarchy and readability
- Reduce switch-time rendering cost by simplifying shared surface layers and shortening panel animations
- Defer panel frame updates by one main-runloop turn to reduce layout churn during presentation changes

## 0.0.3 - 2026-05-16

- Previous release
