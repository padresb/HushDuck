# CLAUDE.md

## Project Overview

HushDuck is a macOS menu bar utility that mutes system audio while the Fn key is held. It targets macOS 13+ and is built entirely in Swift with no external dependencies.

## Build & Run

```bash
# Debug build
swift build

# Release build + .app bundle
./build-app.sh

# Run the app
open .build/release/HushDuck.app

# Install to /Applications
cp -r .build/release/HushDuck.app /Applications/
```

## Project Structure

All source code lives in `Sources/HushDuck/`. Key files:

- `FnKeyMonitor.swift` — CGEventTap with C callback for Fn key edge detection. Most delicate code in the project.
- `AudioController.swift` — CoreAudio property get/set for mute, device change listener, duck/unduck state machine.
- `AppDelegate.swift` — Wires FnKeyMonitor to AudioController, manages lifecycle, crash recovery, sleep observer.
- `StatusItemManager.swift` — NSStatusItem with native NSMenu (not SwiftUI popover).

## Key Technical Details

- App uses `NSApp.setActivationPolicy(.accessory)` to hide from Dock (no Info.plist needed at dev time, `build-app.sh` adds `LSUIElement` for the .app bundle).
- CGEventTap requires Accessibility permissions. The app is NOT sandboxed.
- The Fn key only generates `flagsChanged` events (not keyDown/keyUp). Detection uses `CGEventFlags.maskSecondaryFn` with edge detection to avoid repeat firing.
- CoreAudio mute uses `kAudioDevicePropertyMute` on the default output device. The `didDuck` flag tracks whether we set the mute (vs user had it muted already).
- After rebuilding, you may need to reset TCC permissions: `tccutil reset Accessibility com.hushduck.app`

## Conventions

- No external dependencies — CoreAudio, CoreGraphics, AppKit, SwiftUI only.
- Menu bar UI uses native NSMenu for standard macOS appearance.
- SF Symbols used for menu bar icon (waveform family).
- Bundle identifier: `com.hushduck.app`
