# Peek

Share only a portion of your screen in Google Meet, Zoom, etc.

Peek sits in your menubar and creates a virtual display that mirrors a selected region of your monitor. Video conferencing apps see it as a regular screen you can share.

## Install

Requires macOS 15+ and Xcode Command Line Tools.

```bash
curl -sL https://raw.githubusercontent.com/vladstudio/peek/main/install.sh | bash
```

Or build from source:

```bash
git clone https://github.com/vladstudio/peek.git
cd peek
./build.sh
```

## Usage

1. Click the eyes icon in your menubar
2. Pick a region (left half, right third, etc.)
3. Click **Start Sharing**
4. In your video call, share the "Peek" screen

Screen Recording permission is required on first launch.

## How it works

Uses CoreGraphics private API (`CGVirtualDisplay`) to create a headless display, ScreenCaptureKit to capture a region, and IOSurface for zero-copy frame delivery.

## License

MIT
