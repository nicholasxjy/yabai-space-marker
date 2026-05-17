# Changelog

## 0.0.4 - 2026-05-17

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
