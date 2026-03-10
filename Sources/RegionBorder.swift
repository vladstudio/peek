import AppKit
import QuartzCore

class RegionBorder {
    private var window: NSWindow?
    private var shapeLayer: CAShapeLayer?
    private var flashWorkItem: DispatchWorkItem?

    /// Show persistent overlay: dims everything outside `rect`, border around the region.
    func show(rect: CGRect, on screen: NSScreen) {
        flashWorkItem?.cancel()
        flashWorkItem = nil

        let screenFrame = screen.frame
        let needsNewWindow = window == nil
            || window?.screen !== screen
            || window?.frame != screenFrame

        if needsNewWindow {
            close()
            let w = NSWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            w.backgroundColor = .clear
            w.isOpaque = false
            w.hasShadow = false
            w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            w.ignoresMouseEvents = true
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary]
            w.alphaValue = 1.0

            let view = NSView(frame: NSRect(origin: .zero, size: screenFrame.size))
            view.wantsLayer = true
            let layer = CAShapeLayer()
            layer.fillRule = .evenOdd
            view.layer?.addSublayer(layer)

            w.contentView = view
            w.orderFront(nil)

            self.window = w
            self.shapeLayer = layer
        }

        updatePath(rect: rect)
    }

    /// Flash: show briefly, then fade out.
    func flash(rect: CGRect, on screen: NSScreen) {
        show(rect: rect, on: screen)

        flashWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let w = self.window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                w.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.close()
            })
        }
        flashWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func close() {
        flashWorkItem?.cancel()
        flashWorkItem = nil
        window?.close()
        window = nil
        shapeLayer = nil
    }

    private func updatePath(rect: CGRect) {
        guard let window, let layer = shapeLayer else { return }

        let bounds = window.contentView?.bounds ?? window.frame
        // rect is in screen coordinates, convert to window-local (window origin = screen origin)
        let localRect = CGRect(
            x: rect.origin.x - window.frame.origin.x,
            y: rect.origin.y - window.frame.origin.y,
            width: rect.width,
            height: rect.height
        )

        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRect(localRect)

        layer.path = path
        layer.fillColor = NSColor.black.withAlphaComponent(0.3).cgColor
        layer.strokeColor = nil

        // Border around the cutout
        let borderLayer: CAShapeLayer
        if let existing = layer.sublayers?.first as? CAShapeLayer {
            borderLayer = existing
        } else {
            borderLayer = CAShapeLayer()
            borderLayer.fillColor = nil
            layer.addSublayer(borderLayer)
        }
        let borderInset: CGFloat = -2  // outside the region
        borderLayer.path = CGPath(rect: localRect.insetBy(dx: borderInset, dy: borderInset), transform: nil)
        borderLayer.strokeColor = NSColor.systemBlue.cgColor
        borderLayer.lineWidth = 4
    }
}
