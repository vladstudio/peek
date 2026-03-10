# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
make build    # Build the app bundle to build/Peek.app
make run      # Build and run
make clean    # Remove build directory
```

The Makefile compiles Objective-C and Swift sources together, creates the .app bundle with icon and Info.plist, and ad-hoc code signs with entitlements.

## Architecture

Peek is a macOS menubar app that creates a virtual display mirroring a selected region of the screen, enabling partial screen sharing in video calls. Requires macOS 15+.

**Language**: Swift (primary) + Objective-C (for private CoreGraphics API)

### Core Data Flow

1. User selects a monitor + region preset from the menubar
2. `AppState.start()` creates a virtual display, waits for it to appear as an NSScreen, opens a fullscreen output window on it, and starts screen capture
3. `ScreenCapture` delivers IOSurface frames → `OutputWindow` renders them via CALayer
4. Stop/quit tears down in reverse order

### Key Source Files (`Sources/`)

- **PeekApp.swift** — Entry point, SwiftUI MenuBarExtra UI, `AppState` (central coordinator)
- **VirtualDisplayBridge.m/h** — Objective-C bridge using private `CGVirtualDisplay` API to create headless displays
- **VirtualDisplay.swift** — Swift wrapper around the ObjC bridge
- **ScreenCapture.swift** — ScreenCaptureKit-based capture with region/output size config
- **OutputWindow.swift** — Borderless fullscreen window on virtual display rendering IOSurface frames
- **RegionPreset.swift** — Enum defining region presets (halves, thirds)
- **RegionBorder.swift** — Animated border flash for visual feedback on region selection
- **DisplayUtils.swift** — SCDisplay↔NSScreen mapping helpers

### Key Design Points

- Private `CGVirtualDisplay` API (no public equivalent) — the ObjC bridge exists because these APIs aren't accessible from Swift
- IOSurface for zero-copy frame delivery between capture and display
- App sandbox disabled via entitlements to allow private API access
- `LSUIElement: true` — menubar-only, no dock icon
- `@Observable` AppState with `@MainActor` throughout
