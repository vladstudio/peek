@preconcurrency import ScreenCaptureKit
import CoreMedia
import CoreVideo
@preconcurrency import IOSurface

@Observable
final class ScreenCapture: NSObject, SCStreamOutput, @unchecked Sendable {
    var availableDisplays: [SCDisplay] = []
    private var stream: SCStream?
    private(set) var currentDisplayID: CGDirectDisplayID = 0

    /// Called on main thread with each captured IOSurface.
    var onFrame: ((IOSurface) -> Void)?

    func refreshDisplays() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: false
            )
            await MainActor.run {
                self.availableDisplays = content.displays
            }
        } catch {
            print("Peek: Failed to get displays: \(error)")
        }
    }

    func startCapture(
        display: SCDisplay,
        sourceRect: CGRect,
        outputWidth: Int,
        outputHeight: Int
    ) async throws {
        await stopCapture()

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = outputWidth
        config.height = outputHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false
        config.showsCursor = false

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        try await newStream.startCapture()

        self.stream = newStream
        self.currentDisplayID = display.displayID
    }

    func updateCapture(sourceRect: CGRect, outputWidth: Int, outputHeight: Int) async throws {
        guard let stream else { return }
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = outputWidth
        config.height = outputHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = false
        config.showsCursor = false
        try await stream.updateConfiguration(config)
    }

    func stopCapture() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        currentDisplayID = 0
    }

    // MARK: - SCStreamOutput

    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue() else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(surface)
        }
    }
}
