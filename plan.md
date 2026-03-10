# Peek — Implementation Plan

## Overview
Menubar-only macOS app that captures a region of a physical monitor and outputs it to a **virtual display** (via `CGVirtualDisplay` private API). The virtual display appears as a shareable "screen" in Google Meet / Zoom — no visible window on the user's desktop.

## Tech Stack
- **Language**: Swift
- **UI**: SwiftUI (menubar only)
- **Capture**: ScreenCaptureKit (macOS 15+)
- **Output**: CGVirtualDisplay (CoreGraphics private API) + Metal (frame blit to IOSurface)
- **Build**: Swift Package Manager (command-line `swift build`, no Xcode project needed)

## Architecture

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────────┐
│ SCStream      │────▶│ Metal Renderer  │────▶│ CGVirtualDisplay │
│ (30fps,       │     │ (blit to        │     │ (headless,       │
│  sourceRect)  │     │  IOSurface)     │     │  shows as screen │
└──────────────┘     └─────────────────┘     │  in share picker) │
        ▲                                     └──────────────────┘
        │                                              ▲
┌──────────────┐                              ┌──────────────────┐
│ PeekApp      │─────────────────────────────▶│ VirtualDisplay   │
│ (MenuBarExtra)│  creates/resizes on change  │ Manager          │
└──────────────┘                              └──────────────────┘
```

## Files

```
Peek/
├── PeekApp.swift              # @main, MenuBarExtra, menu structure, state coordination
├── ScreenCapture.swift        # SCStream lifecycle, frame delivery
├── VirtualDisplay.swift       # CGVirtualDisplay creation, teardown, resize
├── MetalRenderer.swift        # Blit captured CVPixelBuffer → virtual display IOSurface
├── RegionPreset.swift         # Enum with CGRect computation
├── DisplayUtils.swift         # Helper: match SCDisplay↔NSScreen, get scale factor
├── Info.plist                 # LSUIElement=true, NSScreenCaptureUsageDescription
└── Peek.entitlements          # com.apple.security.screen-recording
```

## Detailed Steps

### 1. Project Setup
- Create Xcode project: macOS App, SwiftUI lifecycle
- Deployment target: macOS 15.0
- `Info.plist`: `LSUIElement = true` (no dock icon), `NSScreenCaptureUsageDescription`
- Entitlement: `com.apple.security.screen-recording`
- Link frameworks: ScreenCaptureKit, Metal, CoreGraphics

### 2. RegionPreset.swift
```swift
enum RegionPreset: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, centerHalf
    case leftThird, rightThird, centerThird

    var id: String { rawValue }
    var label: String { /* "Left Half", etc. */ }

    func sourceRect(displayWidth: Int, displayHeight: Int) -> CGRect {
        // Returns pixel rect for the region
    }

    func regionSize(displayWidth: Int, displayHeight: Int) -> (width: Int, height: Int) {
        // Returns pixel dimensions of the region
    }
}
```

### 3. DisplayUtils.swift
```swift
/// Match SCDisplay to NSScreen to get backingScaleFactor
func scaleFactor(for display: SCDisplay) -> CGFloat

/// Get pixel dimensions (points × scaleFactor)
func pixelSize(for display: SCDisplay) -> (width: Int, height: Int)
```

### 4. VirtualDisplay.swift — CGVirtualDisplay wrapper
Uses CoreGraphics private API. These are Obj-C classes accessed via Swift bridging.

**CGVirtualDisplay private API surface needed:**
```swift
// CGVirtualDisplayDescriptor
class CGVirtualDisplayDescriptor: NSObject {
    var queue: DispatchQueue
    var name: String
    var maxPixelsWide: UInt32
    var maxPixelsHigh: UInt32
    var sizeInMillimeters: CGSize
    var serialNum: UInt32
    var vendorID: UInt32
    var productID: UInt32
    var terminationHandler: (() -> Void)?
}

// CGVirtualDisplayMode
class CGVirtualDisplayMode: NSObject {
    init(width: UInt32, height: UInt32, refreshRate: Float)
}

// CGVirtualDisplaySettings
class CGVirtualDisplaySettings: NSObject {
    var modes: [CGVirtualDisplayMode]
    var hipiMode: CGVirtualDisplayMode
}

// CGVirtualDisplay
class CGVirtualDisplay: NSObject {
    init(descriptor: CGVirtualDisplayDescriptor)
    func applySettings(_ settings: CGVirtualDisplaySettings) -> Bool
    var displayID: CGDirectDisplayID
}
```

**Access strategy**: Use `@objc` dynamic lookup or create a bridging header with class declarations. Since these are private API classes loaded at runtime in CoreGraphics, we use `NSClassFromString` + dynamic casting.

**VirtualDisplayManager class:**
- `create(width:height:)` → creates CGVirtualDisplay at given pixel dimensions
- `resize(width:height:)` → tears down old display, creates new one (CGVirtualDisplay doesn't support live resize)
- `destroy()` → releases the display
- Exposes `displayID: CGDirectDisplayID` for getting the IOSurface framebuffer

**Getting the IOSurface for the virtual display:**
- Use `CGDisplayStream` pointed at the virtual display's `displayID`
- OR use `IOSurfaceCreate` and associate it via the display stream
- The actual framebuffer surface is obtained via `CGDisplayCopyDisplayMode` + `CGDisplayCreateImage` pipeline, but for writing, we use **Metal** to render to a surface and use `CGVirtualDisplay`'s built-in surface

**Practical approach:** After creating the virtual display, macOS creates a framebuffer for it. We obtain this surface by creating a `CGDisplayStream` for the virtual display's `displayID`. The stream's update handler gives us the IOSurface backbuffer. We then blit captured frames to this surface using Metal.

### 5. MetalRenderer.swift
Blits captured screen frames onto the virtual display's IOSurface.

```swift
class MetalRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    func render(pixelBuffer: CVPixelBuffer, to surface: IOSurface) {
        // 1. Create MTLTexture from pixelBuffer (via CVMetalTextureCache)
        // 2. Create MTLTexture from destination IOSurface
        // 3. Use blitCommandEncoder.copy() — GPU-side copy, no CPU involvement
        // 4. Commit command buffer
    }
}
```

This is a single GPU blit operation per frame — minimal overhead.

### 6. ScreenCapture.swift
- `@Observable class ScreenCapture: NSObject, SCStreamOutput`
- **Properties**: `stream: SCStream?`, `isCapturing: Bool`, `availableDisplays: [SCDisplay]`
- **Setup**:
  1. `SCShareableContent.current` → populate `availableDisplays`
  2. Create `SCContentFilter(display:excludingWindows: [])` — no windows to exclude (no output window!)
  3. Create `SCStreamConfiguration`:
     - `sourceRect` = region preset rect (in pixels)
     - `width` / `height` = region pixel size
     - `minimumFrameInterval` = CMTime(value: 1, timescale: 30)
     - `pixelFormat` = kCVPixelFormatType_32BGRA
     - `capturesAudio` = false
     - `showsCursor` = false
  4. Create `SCStream`, add output, start capture
- **SCStreamOutput.stream(_:didOutputSampleBuffer:of:)**:
  - Extract CVPixelBuffer from CMSampleBuffer
  - Call `metalRenderer.render(pixelBuffer:to:virtualDisplaySurface)`
- **Teardown**: `stream.stopCapture()`, nil references
- **No self-capture issue**: virtual display has no window, and we capture a specific physical display. No feedback loop possible.

### 7. PeekApp.swift (MenuBarExtra)
```
@main SwiftUI App with MenuBarExtra
```
- **State** (in an `@Observable PeekState` class):
  - `selectedDisplay: SCDisplay?` (defaults to main)
  - `selectedPreset: RegionPreset` (defaults to leftHalf)
  - `isCapturing: Bool`
  - `availableDisplays: [SCDisplay]`
- **Menu structure**:
  ```
  ┌─────────────────────────┐
  │ ▶ Start  /  ■ Stop      │
  │ ───────────────────────  │
  │ Monitor                  │
  │   ✓ Built-in Display     │
  │     DELL U2723QE         │
  │ ───────────────────────  │
  │ Region                   │
  │   ✓ Left Half            │
  │     Right Half           │
  │     Center Half          │
  │     Left Third           │
  │     Right Third          │
  │     Center Third         │
  │ ───────────────────────  │
  │ Quit                     │
  └─────────────────────────┘
  ```
- **Actions**:
  - **Start**: create virtual display → start capture
  - **Stop**: stop capture → destroy virtual display
  - **Change preset while capturing**: see §8
  - **Change monitor while capturing**: see §8
  - **Quit**: stop capture → destroy virtual display → `NSApp.terminate(nil)`

### 8. Live Settings Changes (No Stale State)

All transitions go through a central `applyConfiguration()` method that computes the desired state and reconciles.

```swift
func applyConfiguration() async {
    let display = selectedDisplay ?? mainDisplay
    let scale = scaleFactor(for: display)
    let pixelW = Int(CGFloat(display.width) * scale)
    let pixelH = Int(CGFloat(display.height) * scale)
    let region = selectedPreset.regionSize(displayWidth: pixelW, displayHeight: pixelH)
    let sourceRect = selectedPreset.sourceRect(displayWidth: pixelW, displayHeight: pixelH)

    // --- Virtual display ---
    // Resize needed if region dimensions changed
    if virtualDisplay == nil || currentRegionSize != region {
        // Tear down old virtual display (if any) BEFORE creating new
        virtualDisplay?.destroy()
        virtualDisplay = VirtualDisplayManager()
        virtualDisplay.create(width: region.width, height: region.height)
        currentRegionSize = region
    }

    // --- Stream ---
    let needsNewStream = (stream == nil) || (currentDisplay?.displayID != display.displayID)

    if needsNewStream {
        // Full teardown + rebuild (display changed or first start)
        await stream?.stopCapture()
        stream = buildStream(display: display, sourceRect: sourceRect, regionSize: region)
        await stream.startCapture()
        currentDisplay = display
    } else {
        // Same display, just update sourceRect (preset changed)
        let config = buildConfig(sourceRect: sourceRect, regionSize: region)
        try? await stream.updateConfiguration(config)
    }
}
```

**Transitions handled:**

| User action | While capturing? | What happens |
|---|---|---|
| Start | No | Create virtual display → start stream |
| Stop | Yes | Stop stream → destroy virtual display |
| Change preset | No | Just update state; applied on next Start |
| Change preset | Yes | `stream.updateConfiguration()` with new sourceRect + resize virtual display |
| Change monitor | No | Just update state; applied on next Start |
| Change monitor | Yes | Full teardown → rebuild with new display filter |
| Quit | Either | Stop if running → destroy → terminate |
| Monitor disconnected | Yes | Detect via notification → stop → fall back to main display |

**Key invariant**: Every state change calls `applyConfiguration()` which idempotently reconciles desired state → actual state. No partial updates, no stale references.

### 9. Permission Handling
- On Start, call `SCShareableContent.current` which triggers the system permission dialog if not yet granted
- If the call throws (permission denied), show `NSAlert` pointing to System Settings > Privacy & Security > Screen Recording
- Menu shows "Start" grayed out until permission is granted (check on app launch)

### 10. Retina / Scale Factor Handling
- `SCDisplay.width`/`.height` = points. Multiply by `NSScreen.backingScaleFactor` for pixels.
- Match `SCDisplay` → `NSScreen` via: `NSScreen.screens.first { screen in screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == display.displayID }`
- Virtual display created at pixel dimensions
- `sourceRect` in pixel coordinates

### 11. Display Change Notifications
Listen for `NSApplication.didChangeScreenParametersNotification`:
- Re-fetch `SCShareableContent.current` to update available displays list
- If `selectedDisplay` is no longer in the list:
  - If capturing: stop → fall back to main display → restart
  - If not capturing: reset to main display

## Performance Notes
- **GPU-only frame path**: ScreenCaptureKit → CVPixelBuffer → Metal blit → IOSurface. Zero CPU pixel copies.
- **sourceRect cropping**: done by ScreenCaptureKit at capture time, not post-capture.
- **30fps cap**: sufficient for screen sharing, minimizes GPU/CPU load.
- **No audio, no cursor**: reduces capture overhead.
- **Metal blit**: single `blitCommandEncoder.copy()` per frame, ~0.1ms GPU time.

## Edge Cases
1. **No self-capture loop** — virtual display is headless; SCStream captures a physical display. No feedback possible.
2. **Display disconnected while capturing** → `didChangeScreenParametersNotification` → stop, fall back to main, optionally restart.
3. **Screen recording permission denied** → alert with instructions.
4. **Selected monitor unavailable at Start** → fall back to main display.
5. **Retina vs non-Retina** → always compute pixel dimensions via scaleFactor (§10).
6. **Thread safety** → SCStreamOutput delivers on background queue; Metal rendering is thread-safe; virtual display operations on its own queue.
7. **Memory** → CVPixelBuffers released after Metal blit completes; one frame in flight at a time.
8. **Rapid preset changes** → `applyConfiguration()` is serialized (async, one at a time). Intermediate states are skipped — only final state is applied.
9. **Rapid start/stop** → each Start awaits full teardown of previous session before starting new one.
10. **Virtual display teardown** → CGVirtualDisplay deallocation removes it from the system. Google Meet's share picker updates automatically.
11. **App crash / force quit** → CGVirtualDisplay is tied to process lifetime; OS cleans up automatically.
12. **CGVirtualDisplay private API unavailable** → check at launch via `NSClassFromString("CGVirtualDisplay")`. If nil, show alert and quit. Future-proofing: guard every private API call.

## Risk: Private API
`CGVirtualDisplay` is a private CoreGraphics API. Implications:
- **Cannot distribute via Mac App Store** (private API + entitlement requirements)
- **May break on macOS updates** — mitigate by guarding all API access with runtime checks
- **Used by established apps** (BetterDisplay, Luna Display) — unlikely to be removed without replacement
- **Acceptable for personal use / direct distribution** (which is our case)

## Build & Run Verification
1. Build succeeds with no warnings
2. App appears in menubar only (no dock icon, no windows)
3. Start → virtual display appears in System Settings > Displays
4. Google Meet > Share Screen > "Peek" appears as a screen option
5. Participants see only the selected region of the chosen monitor
6. Change preset while sharing → view updates, no interruption to share
7. Change monitor while sharing → brief interruption, then resumes
8. Stop → virtual display disappears from system
9. CPU usage < 5% idle, < 10% while capturing
