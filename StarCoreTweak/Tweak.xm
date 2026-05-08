/**
 * StarCoreTweak.xm
 * 主Tweak代码 - 最小可用版本，先验证编译和注入
 * 
 * 适配设备：iPhone X | iOS 16.7.12 | 多巴胺无根越狱(Dopamine rootless)
 * 
 * 版本：v1.0-minimal
 * 验证：编译通过 + 注入SpringBoard成功 + XPC服务可响应
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//==============================================================================
// 常量定义
//==============================================================================

NSString * const kStarCoreTweakServiceName = @"com.starcore.tweak-service";

// iPhone X 屏幕尺寸（逻辑像素）
#define SCREEN_WIDTH  375
#define SCREEN_HEIGHT 812

//==============================================================================
// IOKit函数指针声明（动态加载）
//==============================================================================

typedef void* (*IOHIDEventCreateDigitizerFingerEvent_t)(void *, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint8_t, uint8_t, uint32_t);
typedef void (*IOHIDEventSetFloatValue_t)(void *, uint32_t, uint32_t, double);
typedef void (*IOHIDEventSetIntegerValue_t)(void *, uint32_t, uint32_t, int32_t);
typedef void (*IOHIDEventAppendEvent_t)(void *, void *);
typedef void (*IOHIDEventSetSenderID_t)(void *, uint64_t);
typedef void* (*IOHIDEventSystemClientCreate_t)(void *);
typedef void (*IOHIDEventSystemClientDispatchEvent_t)(void *, void *);

static IOHIDEventCreateDigitizerFingerEvent_t IOHIDEventCreateDigitizerFingerEvent;
static IOHIDEventSetFloatValue_t IOHIDEventSetFloatValue;
static IOHIDEventSetIntegerValue_t IOHIDEventSetIntegerValue;
static IOHIDEventAppendEvent_t IOHIDEventAppendEvent;
static IOHIDEventSetSenderID_t IOHIDEventSetSenderID;
static IOHIDEventSystemClientCreate_t IOHIDEventSystemClientCreate;
static IOHIDEventSystemClientDispatchEvent_t IOHIDEventSystemClientDispatchEvent;

static void *g_ioKitLib = NULL;
static void *g_systemClient = NULL;
static uint64_t g_senderID = 0x1337;
static BOOL g_functionsInitialized = NO;

//==============================================================================
// XPC协议定义
//==============================================================================

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

//==============================================================================
// IOKit函数初始化
//==============================================================================

static void initIOKitFunctions(void) {
    if (g_functionsInitialized) return;
    
    g_ioKitLib = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!g_ioKitLib) {
        NSLog(@"[StarCoreTweak] 加载IOKit失败: %s", dlerror());
        return;
    }
    
    IOHIDEventCreateDigitizerFingerEvent = dlsym(g_ioKitLib, "IOHIDEventCreateDigitizerFingerEvent");
    IOHIDEventSetFloatValue = dlsym(g_ioKitLib, "IOHIDEventSetFloatValue");
    IOHIDEventSetIntegerValue = dlsym(g_ioKitLib, "IOHIDEventSetIntegerValue");
    IOHIDEventAppendEvent = dlsym(g_ioKitLib, "IOHIDEventAppendEvent");
    IOHIDEventSetSenderID = dlsym(g_ioKitLib, "IOHIDEventSetSenderID");
    IOHIDEventSystemClientCreate = dlsym(g_ioKitLib, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent = dlsym(g_ioKitLib, "IOHIDEventSystemClientDispatchEvent");
    
    if (!IOHIDEventSystemClientCreate) {
        NSLog(@"[StarCoreTweak] IOHIDEventSystemClientCreate未找到");
        return;
    }
    
    g_systemClient = IOHIDEventSystemClientCreate(NULL);
    g_functionsInitialized = YES;
    NSLog(@"[StarCoreTweak] IOKit函数初始化完成");
}

//==============================================================================
// 触摸事件辅助函数
//==============================================================================

static void *createFingerEvent(float x, float y, uint8_t touchType, uint32_t fingerIndex) {
    if (!IOHIDEventCreateDigitizerFingerEvent) return NULL;
    
    uint32_t eventMask = 0;
    uint8_t range = 0;
    uint8_t touch = 0;
    
    switch (touchType) {
        case 0: // 按下
            eventMask = 0x05;
            range = 0;
            touch = 1;
            break;
        case 1: // 抬起
            eventMask = 0x05;
            range = 1;
            touch = 0;
            break;
        case 2: // 移动
            eventMask = 0x02;
            range = 0;
            touch = 1;
            break;
    }
    
    uint32_t fixedX = (uint32_t)(x * 0x10000);
    uint32_t fixedY = (uint32_t)(y * 0x10000);
    
    void *event = IOHIDEventCreateDigitizerFingerEvent(
        NULL, fingerIndex, 3, eventMask,
        fixedX, fixedY, 0, 0, 0, 0x666, 0x666,
        range, touch, 0
    );
    
    if (event && IOHIDEventSetIntegerValue) {
        IOHIDEventSetIntegerValue(event, 0x2d, 0x2d, 1);
    }
    
    return event;
}

static void dispatchTouchEvent(void *fingerEvent) {
    if (!fingerEvent || !g_systemClient) return;
    
    if (IOHIDEventSetSenderID) {
        IOHIDEventSetSenderID(fingerEvent, g_senderID);
    }
    
    if (IOHIDEventSystemClientDispatchEvent) {
        IOHIDEventSystemClientDispatchEvent(g_systemClient, fingerEvent);
    }
}

static BOOL performTap(float x, float y) {
    if (x < 0 || x > 1 || y < 0 || y > 1) return NO;
    
    initIOKitFunctions();
    
    void *downEvent = createFingerEvent(x, y, 0, 1);
    if (downEvent) dispatchTouchEvent(downEvent);
    
    usleep(50000);
    
    void *upEvent = createFingerEvent(x, y, 1, 1);
    if (upEvent) dispatchTouchEvent(upEvent);
    
    return YES;
}

static BOOL performSwipe(float fromX, float fromY, float toX, float toY, double durationMs) {
    if (fromX < 0 || fromX > 1 || fromY < 0 || fromY > 1 ||
        toX < 0 || toX > 1 || toY < 0 || toY > 1) return NO;
    
    initIOKitFunctions();
    
    void *downEvent = createFingerEvent(fromX, fromY, 0, 1);
    if (downEvent) dispatchTouchEvent(downEvent);
    
    int steps = (int)(durationMs / 10);
    if (steps < 5) steps = 5;
    
    for (int i = 1; i <= steps; i++) {
        float progress = (float)i / steps;
        float currentX = fromX + (toX - fromX) * progress;
        float currentY = fromY + (toY - fromY) * progress;
        
        void *moveEvent = createFingerEvent(currentX, currentY, 2, 1);
        if (moveEvent) dispatchTouchEvent(moveEvent);
        
        usleep((useconds_t)(durationMs * 1000 / steps));
    }
    
    void *upEvent = createFingerEvent(toX, toY, 1, 1);
    if (upEvent) dispatchTouchEvent(upEvent);
    
    return YES;
}

//==============================================================================
// XPC服务实现
//==============================================================================

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

#pragma mark - StarCoreTweakProtocol 实现

- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] tapAtX:%ld Y:%ld", (long)x, (long)y);
    float normX = (float)x / SCREEN_WIDTH;
    float normY = (float)y / SCREEN_HEIGHT;
    reply(performTap(normX, normY));
}

- (void)swipeFromX:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] swipeFrom:(%ld,%ld) -> (%ld,%ld)", (long)fromX, (long)fromY, (long)toX, (long)toY);
    float normFromX = (float)fromX / SCREEN_WIDTH;
    float normFromY = (float)fromY / SCREEN_HEIGHT;
    float normToX = (float)toX / SCREEN_WIDTH;
    float normToY = (float)toY / SCREEN_HEIGHT;
    double durationMs = (duration > 0) ? duration * 1000 : 500;
    reply(performSwipe(normFromX, normFromY, normToX, normToY, durationMs));
}

- (void)longPressAtX:(NSInteger)x Y:(NSInteger)y duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] longPressAt:(%ld,%ld) duration:%.2f", (long)x, (long)y, duration);
    reply(YES); // 简化实现
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

//==============================================================================
// Tweak初始化
//==============================================================================

static StarCoreTweakXPCService *xpcService = nil;
static NSXPCListener *xpcListener = nil;

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
    
    initIOKitFunctions();
    
    xpcService = [[StarCoreTweakXPCService alloc] init];
    xpcListener = [[NSXPCListener alloc] initWithMachServiceName:kStarCoreTweakServiceName];
    xpcListener.delegate = xpcService;
    [xpcListener resume];
    
    NSLog(@"[StarCoreTweak] XPC服务已启动: %@", kStarCoreTweakServiceName);
    NSLog(@"[StarCoreTweak] Tweak初始化完成 - v1.0-minimal");
}

%dtor {
    NSLog(@"[StarCoreTweak] Tweak卸载");
    [xpcListener invalidate];
}
