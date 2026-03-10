# Peek

Share only a portion of your screen in Google Meet, Zoom, etc.

Peek sits in your menubar and creates a virtual display that mirrors a selected region of your monitor. Video conferencing apps see it as a regular screen you can share.

## How to use

1. `make run`
2. Click the eyes icon in your menubar
3. Pick a region (left half, right third, etc.)
4. Click **Start Sharing**
5. In your video call, share the "Peek" screen

Requires macOS 15+ and Screen Recording permission.

## How it works

Uses CoreGraphics private API (`CGVirtualDisplay`) to create a headless display, ScreenCaptureKit to capture a region, and IOSurface for zero-copy frame delivery.

## License

MIT
