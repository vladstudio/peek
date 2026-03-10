APP_NAME = Peek
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
BINARY = $(BUILD_DIR)/$(APP_NAME)

SWIFT_FILES = $(wildcard Sources/*.swift)
OBJC_FILES = $(wildcard Sources/*.m)
BRIDGE_HEADER = Sources/VirtualDisplayBridge.h

ARCH = $(shell uname -m)
TARGET = $(ARCH)-apple-macos15.0

FRAMEWORKS = -framework ScreenCaptureKit \
             -framework AppKit \
             -framework CoreMedia \
             -framework CoreVideo \
             -framework QuartzCore \
             -framework IOSurface \
             -framework CoreGraphics

.PHONY: build clean run

build: $(APP_BUNDLE)

$(BINARY): $(SWIFT_FILES) $(OBJC_FILES) $(BRIDGE_HEADER)
	@mkdir -p $(BUILD_DIR)
	# Compile ObjC
	clang -c -fobjc-arc -target $(TARGET) \
		Sources/VirtualDisplayBridge.m \
		-o $(BUILD_DIR)/VirtualDisplayBridge.o
	# Compile Swift + link
	swiftc \
		-import-objc-header $(BRIDGE_HEADER) \
		-target $(TARGET) \
		$(FRAMEWORKS) \
		$(SWIFT_FILES) \
		$(BUILD_DIR)/VirtualDisplayBridge.o \
		-o $(BINARY)

$(APP_BUNDLE): $(BINARY) Info.plist Peek.entitlements icon.png
	@rm -rf $(APP_BUNDLE)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/
	@cp Info.plist $(APP_BUNDLE)/Contents/
	@cp icon.png $(APP_BUNDLE)/Contents/Resources/AppIcon.png
	@cp menubar-icon.png $(APP_BUNDLE)/Contents/Resources/
	@cp menubar-icon@2x.png $(APP_BUNDLE)/Contents/Resources/
	# Convert PNG to icns for app icon
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	@sips -z 1024 1024 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png >/dev/null 2>&1
	@sips -z 512 512 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png >/dev/null 2>&1
	@sips -z 256 256 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png >/dev/null 2>&1
	@sips -z 128 128 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png >/dev/null 2>&1
	@sips -z 64 64 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png >/dev/null 2>&1
	@sips -z 32 32 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png >/dev/null 2>&1
	@sips -z 16 16 icon.png --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png >/dev/null 2>&1
	@iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o $(APP_BUNDLE)/Contents/Resources/AppIcon.icns 2>/dev/null || true
	# Sign with entitlements (ad-hoc)
	@codesign --force --sign - --entitlements Peek.entitlements $(APP_BUNDLE)
	@echo "Built: $(APP_BUNDLE)"

run: build
	@open $(APP_BUNDLE)

clean:
	@rm -rf $(BUILD_DIR)
