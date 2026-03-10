#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface VirtualDisplayBridge : NSObject

- (BOOL)createWithWidth:(uint32_t)width height:(uint32_t)height;
- (void)destroy;

@property (nonatomic, readonly) CGDirectDisplayID displayID;
@property (nonatomic, readonly) BOOL isActive;

@end

NS_ASSUME_NONNULL_END
