import AppKit
import QuartzCore

class RegionBorder {
    private var window: NSWindow?
    private var fadeWorkItem: DispatchWorkItem?

    func flash(rect: CGRect, on screen: NSScreen) {
        fadeWorkItem?.cancel()
        close()

        let w = NSWindow(
            contentRect: rect,
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
        w.alphaValue = 1.0

        let view = NSView(frame: NSRect(origin: .zero, size: rect.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = .clear

        let border = CAShapeLayer()
        let inset: CGFloat = 2
        border.path = CGPath(
            rect: CGRect(origin: .zero, size: rect.size).insetBy(dx: inset, dy: inset),
            transform: nil
        )
        border.fillColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
        border.strokeColor = NSColor.systemBlue.cgColor
        border.lineWidth = 4
        view.layer?.addSublayer(border)

        w.contentView = view
        w.orderFront(nil)

        self.window = w

        let work = DispatchWorkItem { [weak self] in
            guard let self, let w = self.window else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.5
                w.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.close()
            })
        }
        fadeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func close() {
        window?.close()
        window = nil
        fadeWorkItem = nil
    }
}
