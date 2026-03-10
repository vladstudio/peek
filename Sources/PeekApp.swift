import SwiftUI
import ScreenCaptureKit

@main
struct PeekApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(appState: appState)
        } label: {
            Image(nsImage: Self.menuBarIcon())
        }
    }

    private static func menuBarIcon() -> NSImage {
        let img = Bundle.main.image(forResource: "menubar-icon")
            ?? NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: "Peek")!
        img.isTemplate = true
        return img
    }
}

// MARK: - Menu

struct MenuView: View {
    @Bindable var appState: AppState

    var body: some View {
        Button(appState.isCapturing ? "Stop Sharing" : "Start Sharing") {
            Task { @MainActor in await appState.toggle() }
        }
        .keyboardShortcut("s")
        .onAppear { appState.showBorderIfActive() }

        Divider()

        if appState.availableDisplays.count > 1 {
            Menu("Monitor") {
                ForEach(appState.availableDisplays, id: \.displayID) { display in
                    Button {
                        Task { @MainActor in await appState.selectDisplay(display) }
                    } label: {
                        HStack {
                            if appState.selectedDisplayID == display.displayID {
                                Image(systemName: "checkmark")
                            }
                            Text(displayLabel(for: display))
                        }
                    }
                }
            }
            Divider()
        }

        Menu("Region") {
            ForEach(RegionPreset.allCases) { preset in
                Button {
                    Task { @MainActor in await appState.selectPreset(preset) }
                } label: {
                    HStack {
                        if appState.selectedPreset == preset {
                            Image(systemName: "checkmark")
                        }
                        Text(preset.rawValue)
                    }
                }
            }
        }

        Divider()

        Button("Quit") {
            Task { @MainActor in
                await appState.stop()
                NSApp.terminate(nil)
            }
        }
        .keyboardShortcut("q")
    }
}

// MARK: - App State

@MainActor
@Observable
class AppState {
    var selectedPreset: RegionPreset = .leftHalf
    var selectedDisplayID: CGDirectDisplayID = CGMainDisplayID()
    var isCapturing = false
    var availableDisplays: [SCDisplay] = []

    private let capture = ScreenCapture()
    private let virtualDisplay = VirtualDisplayManager()
    private let outputWindow = OutputWindow()
    private let regionBorder = RegionBorder()

    init() {
        capture.onFrame = { [weak self] surface in
            self?.outputWindow.updateFrame(surface)
        }
        Task { await start() }
        observeScreenChanges()
    }

    // MARK: Actions

    func toggle() async {
        if isCapturing {
            await stop()
        } else {
            await start()
        }
    }

    func start() async {
        await refreshDisplays()
        guard let display = resolvedDisplay() else {
            print("Peek: No display available")
            return
        }

        let dw = display.width
        let dh = display.height
        let region = selectedPreset.regionSize(displayWidth: dw, displayHeight: dh)
        let sourceRect = selectedPreset.sourceRect(displayWidth: dw, displayHeight: dh)

        // Create virtual display
        guard virtualDisplay.create(width: region.width, height: region.height) else {
            print("Peek: Failed to create virtual display")
            return
        }

        // Wait for NSScreen to appear
        guard let screen = await virtualDisplay.waitForScreen() else {
            print("Peek: Virtual display screen not found")
            virtualDisplay.destroy()
            return
        }

        // Show output window on virtual display
        outputWindow.show(on: screen)

        // Start capture
        do {
            try await capture.startCapture(
                display: display,
                sourceRect: sourceRect,
                outputWidth: region.width,
                outputHeight: region.height
            )
            isCapturing = true
            showBorder()
        } catch {
            print("Peek: Capture failed: \(error)")
            outputWindow.close()
            virtualDisplay.destroy()
        }
    }

    func stop() async {
        await capture.stopCapture()
        outputWindow.close()
        virtualDisplay.destroy()
        regionBorder.close()
        isCapturing = false
    }

    func selectPreset(_ preset: RegionPreset) async {
        guard preset != selectedPreset else { return }
        selectedPreset = preset
        if isCapturing {
            await applyConfiguration()
            showBorder()
        } else {
            flashBorder()
        }
    }

    func selectDisplay(_ display: SCDisplay) async {
        guard display.displayID != selectedDisplayID else { return }
        selectedDisplayID = display.displayID
        if isCapturing {
            await applyConfiguration()
        }
    }

    // MARK: - Configuration

    private func applyConfiguration() async {
        guard let display = resolvedDisplay() else { return }
        let dw = display.width
        let dh = display.height
        let region = selectedPreset.regionSize(displayWidth: dw, displayHeight: dh)
        let sourceRect = selectedPreset.sourceRect(displayWidth: dw, displayHeight: dh)

        let needsResize = region.width != virtualDisplay.currentWidth
            || region.height != virtualDisplay.currentHeight
        let needsNewStream = display.displayID != capture.currentDisplayID

        if needsResize {
            await stop()
            await start()
            return
        }

        if needsNewStream {
            do {
                try await capture.startCapture(
                    display: display,
                    sourceRect: sourceRect,
                    outputWidth: region.width,
                    outputHeight: region.height
                )
            } catch {
                print("Peek: Failed to switch display: \(error)")
                await stop()
            }
            return
        }

        // Same display, same size — just update sourceRect
        do {
            try await capture.updateCapture(
                sourceRect: sourceRect,
                outputWidth: region.width,
                outputHeight: region.height
            )
        } catch {
            print("Peek: Failed to update capture: \(error)")
        }
    }

    // MARK: - Helpers

    func showBorderIfActive() {
        if isCapturing {
            showBorder()
        } else {
            flashBorder()
        }
    }

    func showBorder() {
        guard let (rect, screen) = borderRectAndScreen() else { return }
        regionBorder.show(rect: rect, on: screen)
    }

    func flashBorder() {
        guard let (rect, screen) = borderRectAndScreen() else { return }
        regionBorder.flash(rect: rect, on: screen)
    }

    private func borderRectAndScreen() -> (CGRect, NSScreen)? {
        guard let display = resolvedDisplay(),
              let screen = nsScreen(for: display) else { return nil }
        let sourceRect = selectedPreset.sourceRect(
            displayWidth: display.width, displayHeight: display.height
        )
        let screenFrame = screen.frame
        let flipped = CGRect(
            x: screenFrame.origin.x + sourceRect.origin.x,
            y: screenFrame.origin.y + screenFrame.height - sourceRect.origin.y - sourceRect.height,
            width: sourceRect.width,
            height: sourceRect.height
        )
        return (flipped, screen)
    }

    private func resolvedDisplay() -> SCDisplay? {
        availableDisplays.first { $0.displayID == selectedDisplayID }
            ?? availableDisplays.first
    }

    private func refreshDisplays() async {
        await capture.refreshDisplays()
        availableDisplays = capture.availableDisplays.filter {
            $0.displayID != virtualDisplay.displayID
        }
        if !availableDisplays.contains(where: { $0.displayID == selectedDisplayID }) {
            selectedDisplayID = CGMainDisplayID()
        }
    }

    private nonisolated func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshDisplays()
                if self.isCapturing && self.resolvedDisplay() == nil {
                    await self.stop()
                }
            }
        }
    }
}
