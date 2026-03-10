import AppKit

class VirtualDisplayManager {
    private let bridge = VirtualDisplayBridge()
    private(set) var currentWidth: Int = 0
    private(set) var currentHeight: Int = 0

    var displayID: CGDirectDisplayID { bridge.displayID }
    var isActive: Bool { bridge.isActive }

    func create(width: Int, height: Int) -> Bool {
        guard bridge.create(withWidth: UInt32(width), height: UInt32(height)) else {
            return false
        }
        currentWidth = width
        currentHeight = height
        return true
    }

    /// Try to reconfigure without destroying. Falls back to recreate.
    func reconfigure(width: Int, height: Int) -> Bool {
        guard bridge.reconfigure(withWidth: UInt32(width), height: UInt32(height)) else {
            return false
        }
        currentWidth = width
        currentHeight = height
        return true
    }

    func destroy() {
        bridge.destroy()
        currentWidth = 0
        currentHeight = 0
    }

    /// Wait for the virtual display to appear as an NSScreen (up to 3s).
    func waitForScreen() async -> NSScreen? {
        let targetID = displayID
        guard targetID != 0 else { return nil }
        for _ in 0..<30 {
            if let screen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == targetID
            }) {
                return screen
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }
}
