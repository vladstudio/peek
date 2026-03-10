import AppKit
import QuartzCore

class OutputWindow {
    private var window: NSWindow?
    private var displayLayer: CALayer?

    /// Show a borderless window filling the given screen, with a CALayer for frame display.
    func show(on screen: NSScreen) {
        close()

        let w = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        w.backgroundColor = .black
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        w.isReleasedWhenClosed = false
        w.collectionBehavior = [.stationary, .canJoinAllSpaces, .ignoresCycle]
        w.ignoresMouseEvents = true
        w.isOpaque = true
        w.hasShadow = false
        w.title = "Peek"

        // Use frame covering entire screen including menubar
        w.setFrame(screen.frame, display: true)

        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true

        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: screen.frame.size)
        layer.contentsGravity = .resize
        view.layer = layer

        w.contentView = view
        w.orderFront(nil)

        self.window = w
        self.displayLayer = layer
    }

    func updateFrame(_ surface: IOSurface) {
        displayLayer?.contents = surface
    }

    func close() {
        window?.close()
        window = nil
        displayLayer = nil
    }
}
