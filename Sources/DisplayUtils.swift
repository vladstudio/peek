import AppKit
import ScreenCaptureKit

func scaleFactor(for display: SCDisplay) -> CGFloat {
    guard let screen = nsScreen(for: display) else { return 2.0 }
    return screen.backingScaleFactor
}

func pixelSize(for display: SCDisplay) -> (width: Int, height: Int) {
    let scale = scaleFactor(for: display)
    return (Int(CGFloat(display.width) * scale), Int(CGFloat(display.height) * scale))
}

func nsScreen(for display: SCDisplay) -> NSScreen? {
    NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
    }
}

func displayLabel(for display: SCDisplay) -> String {
    if let screen = nsScreen(for: display) {
        return screen.localizedName
    }
    return "Display \(display.displayID)"
}
