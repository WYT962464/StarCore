/**
 * StarCoreTweak.xm
 * 最小可用版本 - 只用Logos语法注入，无框架依赖
 */

#import <UIKit/UIKit.h>

// XPC协议定义
@protocol StarCoreTweakProtocol
- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply;
- (void)swipeFromX:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY duration:(double)duration reply:(void (^)(BOOL))reply;
- (void)longPressAtX:(NSInteger)x Y:(NSInteger)y duration:(double)duration reply:(void (^)(BOOL))reply;
- (void)pressHomeButton:(void (^)(BOOL))reply;
- (void)openApp:(NSString *)bundleId reply:(void (^)(BOOL))reply;
- (void)getScreenSize:(void (^)(NSDictionary *))reply;
- (void)getCurrentApp:(void (^)(NSString *))reply;
- (void)takeScreenshot:(void (^)(NSData *))reply;
@end

NSString * const kStarCoreTweakServiceName = @"com.starcore.tweak-service";

// XPC服务实现
@interface StarCoreTweakXPCService : NSObject <NSXPCListenerDelegate, StarCoreTweakProtocol>
@end

@implementation StarCoreTweakXPCService

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(StarCoreTweakProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    NSLog(@"[StarCoreTweak] XPC连接已接受");
    return YES;
}

- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] tapAtX:%ld Y:%ld", (long)x, (long)y);
    reply(YES);
}

- (void)swipeFromX:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] swipeFrom:(%ld,%ld) -> (%ld,%ld)", (long)fromX, (long)fromY, (long)toX, (long)toY);
    reply(YES);
}

- (void)longPressAtX:(NSInteger)x Y:(NSInteger)y duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] longPressAt:(%ld,%ld) duration:%.2f", (long)x, (long)y, duration);
    reply(YES);
}

- (void)pressHomeButton:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] pressHomeButton");
    reply(YES);
}

- (void)openApp:(NSString *)bundleId reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] openApp:%@", bundleId);
    Class LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
    if (LSApplicationWorkspace) {
        id workspace = [LSApplicationWorkspace defaultWorkspace];
        if ([workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            reply([workspace openApplicationWithBundleID:bundleId]);
            return;
        }
    }
    reply(NO);
}

- (void)getScreenSize:(void (^)(NSDictionary *))reply {
    NSLog(@"[StarCoreTweak] getScreenSize");
    CGRect bounds = [UIScreen mainScreen].bounds;
    reply(@{
        @"width": @(bounds.size.width),
        @"height": @(bounds.size.height),
        @"scale": @([UIScreen mainScreen].scale)
    });
}

- (void)getCurrentApp:(void (^)(NSString *))reply {
    NSLog(@"[StarCoreTweak] getCurrentApp");
    reply(@"SpringBoard");
}

- (void)takeScreenshot:(void (^)(NSData *))reply {
    NSLog(@"[StarCoreTweak] takeScreenshot");
    reply(nil);
}

@end

// 静态变量
static StarCoreTweakXPCService *xpcService = nil;
static NSXPCListener *xpcListener = nil;

// Hook SpringBoard启动
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动完成，开始初始化...");
    
    xpcService = [[StarCoreTweakXPCService alloc] init];
    xpcListener = [[NSXPCListener alloc] initWithMachServiceName:kStarCoreTweakServiceName];
    xpcListener.delegate = xpcService;
    [xpcListener resume];
    
    NSLog(@"[StarCoreTweak] XPC服务已启动: %@", kStarCoreTweakServiceName);
    NSLog(@"[StarCoreTweak] Tweak初始化完成 - v1.0-minimal");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
}

%dtor {
    NSLog(@"[StarCoreTweak] Tweak卸载");
    [xpcListener invalidate];
}
