import AppKit
import ScreenCaptureKit

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
