/**
 * StarCoreTweak.xm
 * 主Tweak代码 - Hook SpringBoard + IOHIDEvent触摸注入 + XPC服务端
 * 
 * 适配设备：iPhone X | iOS 16.7.12 | 多巴胺无根越狱(Dopamine rootless)
 * 
 * 核心功能：
 * 1. 注入SpringBoard进程
 * 2. 实现IOHIDEvent触摸事件注入
 * 3. 提供XPC服务供StarCore App调用
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <BackBoardServices/BackBoardServices.h>
#import "StarCoreTweakBridge.h"

//==============================================================================
// 常量定义
//==============================================================================

NSString * const kStarCoreTweakServiceName = @"com.starcore.tweak-service";

static mach_port_t g_simulatorPort;
static uint64_t g_senderID = 0x1337;  // 触摸事件发送者ID

// iPhone X 屏幕尺寸（逻辑像素）
#define SCREEN_WIDTH  375
#define SCREEN_HEIGHT 812

//==============================================================================
// IOKit函数指针声明
//==============================================================================

// IOHIDEvent 相关
static void *(*IOHIDEventCreateDigitizerFingerEvent)(void *, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, uint8_t, uint8_t, uint32_t);
static void (*IOHIDEventSetFloatValue)(void *, uint32_t, uint32_t, double);
static void (*IOHIDEventSetIntegerValue)(void *, uint32_t, uint32_t, int32_t);
static void (*IOHIDEventAppendEvent)(void *, void *);
static void (*IOHIDEventSetSenderID)(void *, uint64_t);
static void *(*IOHIDEventSystemClientCreate)(void *);
static void (*IOHIDEventSystemClientDispatchEvent)(void *, void *);

// BackBoardServices
static void (*BKSHIDEventSetDigitizerInfo)(void *, uint32_t, uint8_t, uint8_t, void *, double, float);

//==============================================================================
// 触摸事件辅助函数
//==============================================================================

/**
 * 初始化IOKit函数指针
 */
static void initIOKitFunctions(void) {
    static BOOL initialized = NO;
    if (initialized) return;
    
    void *libIOKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!libIOKit) {
        NSLog(@"[StarCoreTweak] 加载IOKit失败: %s", dlerror());
        return;
    }
    
    // 获取IOKit函数
    IOHIDEventCreateDigitizerFingerEvent = dlsym(libIOKit, "IOHIDEventCreateDigitizerFingerEvent");
    IOHIDEventSetFloatValue = dlsym(libIOKit, "IOHIDEventSetFloatValue");
    IOHIDEventSetIntegerValue = dlsym(libIOKit, "IOHIDEventSetIntegerValue");
    IOHIDEventAppendEvent = dlsym(libIOKit, "IOHIDEventAppendEvent");
    IOHIDEventSetSenderID = dlsym(libIOKit, "IOHIDEventSetSenderID");
    IOHIDEventSystemClientCreate = dlsym(libIOKit, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEvent = dlsym(libIOKit, "IOHIDEventSystemClientDispatchEvent");
    
    // 获取BackBoardServices函数
    void *libBK = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_NOW);
    if (libBK) {
        BKSHIDEventSetDigitizerInfo = dlsym(libBK, "BKSHIDEventSetDigitizerInfo");
    }
    
    initialized = YES;
    NSLog(@"[StarCoreTweak] IOKit函数初始化完成");
}

/**
 * 创建手指触摸事件
 * @param x 归一化X坐标 (0.0-1.0)
 * @param y 归一化Y坐标 (0.0-1.0)
 * @param touchType 触摸类型: 0=按下, 1=抬起, 2=移动
 * @param fingerIndex 手指索引
 * @return IOHIDEvent引用
 */
static void *createFingerEvent(float x, float y, uint8_t touchType, uint32_t fingerIndex) {
    if (!IOHIDEventCreateDigitizerFingerEvent) return NULL;
    
    uint32_t eventMask = 0;
    uint8_t range = 0;
    uint8_t touch = 0;
    
    switch (touchType) {
        case 0: // 按下
            eventMask = 0x05; // touch | range
            range = 0;
            touch = 1;
            break;
        case 1: // 抬起
            eventMask = 0x05; // touch | range
            range = 1;
            touch = 0;
            break;
        case 2: // 移动
            eventMask = 0x02; // position
            range = 0;
            touch = 1;
            break;
    }
    
    // 转换为IOFixed格式: 值 * 0x10000
    uint32_t fixedX = (uint32_t)(x * 0x10000);
    uint32_t fixedY = (uint32_t)(y * 0x10000);
    
    void *event = IOHIDEventCreateDigitizerFingerEvent(
        NULL,              // allocator
        0,                 // timestamp (mach_absolute_time)
        fingerIndex,       // transducerIndex
        3,                 // identity
        eventMask,         // eventMask
        fixedX,            // x
        fixedY,            // y
        0,                 // z
        0,                 // tipPressure
        0,                 // twist
        0x666,             // minorRadius
        0x666,             // majorRadius
        range,             // range
        touch,             // touch
        0                  // options
    );
    
    // 设置IsDisplayIntegrated标志
    if (event && IOHIDEventSetIntegerValue) {
        IOHIDEventSetIntegerValue(event, 0x2d, 0x2d, 1); // kIOHIDEventFieldDigitizerIsDisplayIntegrated
    }
    
    return event;
}

/**
 * 分发触摸事件到系统
 */
static void dispatchTouchEvent(void *fingerEvent) {
    if (!fingerEvent || !IOHIDEventSystemClientCreate || !IOHIDEventSystemClientDispatchEvent) return;
    
    static void *systemClient = NULL;
    if (!systemClient) {
        systemClient = IOHIDEventSystemClientCreate(NULL);
    }
    
    if (systemClient) {
        // 设置发送者ID
        if (IOHIDEventSetSenderID) {
            IOHIDEventSetSenderID(fingerEvent, g_senderID);
        }
        
        // 分发事件
        IOHIDEventSystemClientDispatchEvent(systemClient, fingerEvent);
    }
}

/**
 * 执行点击操作
 */
static BOOL performTap(float x, float y) {
    if (x < 0 || x > 1 || y < 0 || y > 1) {
        NSLog(@"[StarCoreTweak] 坐标超出范围");
        return NO;
    }
    
    initIOKitFunctions();
    
    // 按下
    void *downEvent = createFingerEvent(x, y, 0, 1);
    if (downEvent) {
        dispatchTouchEvent(downEvent);
    }
    
    // 延迟 ~50ms
    usleep(50000);
    
    // 抬起
    void *upEvent = createFingerEvent(x, y, 1, 1);
    if (upEvent) {
        dispatchTouchEvent(upEvent);
    }
    
    return YES;
}

/**
 * 执行滑动操作
 */
static BOOL performSwipe(float fromX, float fromY, float toX, float toY, double durationMs) {
    if (fromX < 0 || fromX > 1 || fromY < 0 || fromY > 1 ||
        toX < 0 || toX > 1 || toY < 0 || toY > 1) {
        NSLog(@"[StarCoreTweak] 坐标超出范围");
        return NO;
    }
    
    initIOKitFunctions();
    
    // 按下
    void *downEvent = createFingerEvent(fromX, fromY, 0, 1);
    if (downEvent) {
        dispatchTouchEvent(downEvent);
    }
    
    // 移动（分多步实现平滑滑动）
    int steps = (int)(durationMs / 10);
    if (steps < 5) steps = 5;
    
    for (int i = 1; i <= steps; i++) {
        float progress = (float)i / steps;
        float currentX = fromX + (toX - fromX) * progress;
        float currentY = fromY + (toY - fromY) * progress;
        
        void *moveEvent = createFingerEvent(currentX, currentY, 2, 1);
        if (moveEvent) {
            dispatchTouchEvent(moveEvent);
        }
        
        usleep((useconds_t)(durationMs * 1000 / steps));
    }
    
    // 抬起
    void *upEvent = createFingerEvent(toX, toY, 1, 1);
    if (upEvent) {
        dispatchTouchEvent(upEvent);
    }
    
    return YES;
}

/**
 * 执行长按操作
 */
static BOOL performLongPress(float x, float y, double durationMs) {
    if (x < 0 || x > 1 || y < 0 || y > 1) {
        NSLog(@"[StarCoreTweak] 坐标超出范围");
        return NO;
    }
    
    initIOKitFunctions();
    
    // 按下
    void *downEvent = createFingerEvent(x, y, 0, 1);
    if (downEvent) {
        dispatchTouchEvent(downEvent);
    }
    
    // 保持按下状态，定期发送移动事件
    uint64_t interval = durationMs * 1000; // 转换为微秒
    uint64_t start = mach_absolute_time();
    
    while (1) {
        uint64_t elapsed = mach_absolute_time() - start;
        // 需要将mach时间转换为微秒
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        uint64_t elapsedUs = elapsed * timebase.numer / timebase.denom / 1000;
        
        if (elapsedUs >= (uint64_t)(durationMs * 1000)) {
            break;
        }
        
        // 每100ms发送一次保持事件
        if (elapsedUs % 100000 < 10000) {
            void *holdEvent = createFingerEvent(x, y, 2, 1);
            if (holdEvent) {
                dispatchTouchEvent(holdEvent);
            }
        }
        
        usleep(10000); // 10ms
    }
    
    // 抬起
    void *upEvent = createFingerEvent(x, y, 1, 1);
    if (upEvent) {
        dispatchTouchEvent(upEvent);
    }
    
    return YES;
}

/**
 * 模拟Home键按下
 */
static BOOL performHomeButtonPress(void) {
    initIOKitFunctions();
    
    // 使用SBSoundController或直接发送Home键事件
    // 方式1: 使用SpringBoard的私有API
    Class SBApplicationController = objc_getClass("SBApplicationController");
    if (SBApplicationController) {
        // 尝试通过SBUIController按Home键
        Class SBUIController = objc_getClass("SBUIController");
        if (SBUIController) {
            id sharedController = [SBUIController sharedInstance];
            if (sharedController && [sharedController respondsToSelector:@selector(handleHomeButton)]) {
                [sharedController handleHomeButton];
                return YES;
            }
        }
    }
    
    // 方式2: 使用IOHIDEvent模拟Home键
    // 这里简化处理，实际可能需要更复杂的实现
    NSLog(@"[StarCoreTweak] Home键模拟可能需要其他方式");
    
    return NO;
}

//==============================================================================
// XPC服务实现
//==============================================================================

@interface StarCoreTweakXPCService : NSObject <NSXPCListenerDelegate, StarCoreTweakProtocol>
@end

@implementation StarCoreTweakXPCService

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // 配置XPC连接
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(StarCoreTweakProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    NSLog(@"[StarCoreTweak] XPC连接已接受: %@", newConnection);
    return YES;
}

#pragma mark - StarCoreTweakProtocol 实现

- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] tapAtX:%ld Y:%ld", (long)x, (long)y);
    
    float normX = (float)x / SCREEN_WIDTH;
    float normY = (float)y / SCREEN_HEIGHT;
    
    BOOL success = performTap(normX, normY);
    reply(success);
}

- (void)swipeFromX:(NSInteger)fromX fromY:(NSInteger)fromY toX:(NSInteger)toX toY:(NSInteger)toY duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] swipeFrom:(%ld,%ld) -> (%ld,%ld) duration:%.2f", 
          (long)fromX, (long)fromY, (long)toX, (long)toY, duration);
    
    float normFromX = (float)fromX / SCREEN_WIDTH;
    float normFromY = (float)fromY / SCREEN_HEIGHT;
    float normToX = (float)toX / SCREEN_WIDTH;
    float normToY = (float)toY / SCREEN_HEIGHT;
    
    double durationMs = (duration > 0) ? duration * 1000 : 500;
    BOOL success = performSwipe(normFromX, normFromY, normToX, normToY, durationMs);
    reply(success);
}

- (void)longPressAtX:(NSInteger)x Y:(NSInteger)y duration:(double)duration reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] longPressAt:(%ld,%ld) duration:%.2f", (long)x, (long)y, duration);
    
    float normX = (float)x / SCREEN_WIDTH;
    float normY = (float)y / SCREEN_HEIGHT;
    
    double durationMs = (duration > 0) ? duration * 1000 : 1000;
    BOOL success = performLongPress(normX, normY, durationMs);
    reply(success);
}

- (void)pressHomeButton:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] pressHomeButton");
    
    BOOL success = performHomeButtonPress();
    reply(success);
}

- (void)openApp:(NSString *)bundleId reply:(void (^)(BOOL))reply {
    NSLog(@"[StarCoreTweak] openApp:%@", bundleId);
    
    Class LSApplicationWorkspace = objc_getClass("LSApplicationWorkspace");
    if (LSApplicationWorkspace) {
        id workspace = [LSApplicationWorkspace defaultWorkspace];
        if (workspace && [workspace respondsToSelector:@selector(openApplicationWithBundleID:)]) {
            BOOL success = [workspace openApplicationWithBundleID:bundleId];
            reply(success);
            return;
        }
    }
    
    reply(NO);
}

- (void)getScreenSize:(void (^)(NSDictionary *))reply {
    NSLog(@"[StarCoreTweak] getScreenSize");
    
    CGRect bounds = [UIScreen mainScreen].bounds;
    NSDictionary *sizeInfo = @{
        @"width": @(bounds.size.width),
        @"height": @(bounds.size.height),
        @"scale": @([UIScreen mainScreen].scale)
    };
    
    reply(sizeInfo);
}

- (void)getCurrentApp:(void (^)(NSString *))reply {
    NSLog(@"[StarCoreTweak] getCurrentApp");
    
    Class SBApplicationController = objc_getClass("SBApplicationController");
    if (SBApplicationController) {
        id frontApp = [SBApplicationController sharedInstance];
        if (frontApp && [frontApp respondsToSelector:@selector(foremostApplication)]) {
            id app = [frontApp foremostApplication];
            if (app && [app respondsToSelector:@selector(bundleIdentifier)]) {
                reply([app bundleIdentifier]);
                return;
            }
        }
    }
    
    reply(@"SpringBoard");
}

- (void)takeScreenshot:(void (^)(NSData *))reply {
    NSLog(@"[StarCoreTweak] takeScreenshot");
    
    // 使用UIGetScreenImage()截图
    // 注意：这是私有API，仅在越狱环境下可用
    UIImage *image = nil;
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGImageRef screenCGImage = UIGetScreenImage();
    if (screenCGImage) {
        image = [UIImage imageWithCGImage:screenCGImage];
        CGImageRelease(screenCGImage);
    }
#pragma clang diagnostic pop
    
    if (image) {
        NSData *pngData = UIImagePNGRepresentation(image);
        reply(pngData);
    } else {
        reply(nil);
    }
}

@end

//==============================================================================
// Tweak初始化
//==============================================================================

static StarCoreTweakXPCService *xpcService = nil;
static NSXPCListener *xpcListener = nil;

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
    
    // 初始化IOKit函数
    initIOKitFunctions();
    
    // 创建并启动XPC监听器
    xpcService = [[StarCoreTweakXPCService alloc] init];
    xpcListener = [[NSXPCListener alloc] initWithMachServiceName:kStarCoreTweakServiceName];
    xpcListener.delegate = xpcService;
    [xpcListener resume];
    
    NSLog(@"[StarCoreTweak] XPC服务已启动: %@", kStarCoreTweakServiceName);
    NSLog(@"[StarCoreTweak] Tweak初始化完成");
}

%dtor {
    NSLog(@"[StarCoreTweak] Tweak卸载");
    [xpcListener invalidate];
}
