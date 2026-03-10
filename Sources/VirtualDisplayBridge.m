#import "VirtualDisplayBridge.h"

// Forward declarations for CoreGraphics private API (verified via runtime introspection)
@interface CGVirtualDisplayDescriptor : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) unsigned int maxPixelsWide;
@property (nonatomic) unsigned int maxPixelsHigh;
@property (nonatomic) CGSize sizeInMillimeters;
@property (nonatomic) unsigned int serialNumber;
@property (nonatomic) unsigned int vendorID;
@property (nonatomic) unsigned int productID;
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width
                       height:(unsigned int)height
                  refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property (nonatomic, strong) NSArray *modes;
@property (nonatomic) unsigned int hiDPI;
@end

@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property (nonatomic, readonly) CGDirectDisplayID displayID;
@end

// ------------------------------------------------------------------

@implementation VirtualDisplayBridge {
    CGVirtualDisplay *_display;
}

- (BOOL)createWithWidth:(uint32_t)width height:(uint32_t)height {
    [self destroy];

    if (!NSClassFromString(@"CGVirtualDisplay")) {
        NSLog(@"Peek: CGVirtualDisplay API not available");
        return NO;
    }

    CGVirtualDisplayDescriptor *desc = [[CGVirtualDisplayDescriptor alloc] init];
    desc.queue = dispatch_get_main_queue();
    desc.name = @"Peek";
    desc.maxPixelsWide = width;
    desc.maxPixelsHigh = height;
    // Physical size for ~110 DPI (1x scaling)
    desc.sizeInMillimeters = CGSizeMake(
        (CGFloat)width / 110.0 * 25.4,
        (CGFloat)height / 110.0 * 25.4
    );
    desc.serialNumber = 1;
    desc.vendorID = 0x4065;
    desc.productID = 0x656B;

    _display = [[CGVirtualDisplay alloc] initWithDescriptor:desc];
    if (!_display) {
        NSLog(@"Peek: Failed to create virtual display");
        return NO;
    }

    CGVirtualDisplayMode *mode =
        [[CGVirtualDisplayMode alloc] initWithWidth:width
                                             height:height
                                        refreshRate:30.0];

    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    settings.modes = @[mode];
    settings.hiDPI = 0;  // 1x scaling

    if (![_display applySettings:settings]) {
        NSLog(@"Peek: Failed to apply display settings");
        _display = nil;
        return NO;
    }

    NSLog(@"Peek: Virtual display created (ID=%u, %ux%u)",
          _display.displayID, width, height);
    return YES;
}

- (BOOL)reconfigureWithWidth:(uint32_t)width height:(uint32_t)height {
    if (!_display) return NO;

    CGVirtualDisplayMode *mode =
        [[CGVirtualDisplayMode alloc] initWithWidth:width
                                             height:height
                                        refreshRate:30.0];

    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    settings.modes = @[mode];
    settings.hiDPI = 0;

    if (![_display applySettings:settings]) {
        NSLog(@"Peek: reconfigure failed, recreating display");
        return [self createWithWidth:width height:height];
    }
    return YES;
}

- (void)destroy {
    if (_display) {
        NSLog(@"Peek: Destroying virtual display (ID=%u)", _display.displayID);
        _display = nil;
    }
}

- (CGDirectDisplayID)displayID {
    return _display ? _display.displayID : 0;
}

- (BOOL)isActive {
    return _display != nil && _display.displayID != 0;
}

@end
