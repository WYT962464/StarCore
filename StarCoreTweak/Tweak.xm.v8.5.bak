/**
 * StarCoreTweak.xm v8.4 - ios-mcp功能移植
 * 
 * v8.4 新增功能（从 ios-mcp 移植）：
 * 1. 🔥 screenshot - 三级降级截图（IOSurface → _UICreateScreenUIImage → window capture）
 * 2. 🔥 inputText - Unicode文字输入（IOHIDEventCreateUnicodeEvent + BKSHIDEventSendToProcess）
 *    - 支持中文输入！
 *    - 降级方案：clipboard+paste
 * 3. 🔥 pressPower/pressVolumeUp/pressVolumeDown - 硬件按键模拟
 * 4. 🔥 getScreenInfo - 屏幕状态（锁屏、亮屏、方向）
 * 5. 🔥 改进触摸方案 - IOHIDEventCreateDigitizerFingerEvent 归一化坐标
 *    - senderID: 0x8000000817319372（ios-mcp验证值）
 * 
 * 继承 v5.9 修复：
 * - BKHIDSystemInterface优先派发
 * - performSelector返回原始类型用objc_msgSend
 * - UIKit操作dispatch到主线程
 * - 线程安全保护
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <stdio.h>
#import <spawn.h>
#import <sys/wait.h>
#import <fcntl.h>
#import <mach/mach_time.h>
#import <mach-o/dyld.h>
#import <CoreFoundation/CoreFoundation.h>
#import <ImageIO/ImageIO.h>

// ==================== IOKit类型定义（避免模块冲突）====================
#define kIOReturnSuccess 0
typedef int IOReturn;
typedef UInt32 IOOptionBits;

// ==================== 私有类型 ====================
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDUserDevice *IOHIDUserDeviceRef;
typedef struct __IOSurface *IOSurfaceRef;

#define kIOHIDTransducerTypeHand 3
#define kIOHIDEventFieldDigitizerDisplayIntegrated 0x00040001
#define kIOHIDEventFieldBuiltIn 0x00040010
#define kIOHIDEventFieldDigitizerEventMask 0x00040002
#define kIOHIDEventFieldDigitizerRange 0x00040004
#define kIOHIDEventFieldDigitizerTouch 0x00040005
#define kIOHIDDigitizerEventTouch    0x00000001
#define kIOHIDDigitizerEventRange    0x00000004
#define kIOHIDDigitizerEventPosition 0x00000002
#define kIOHIDDigitizerEventIdentity 0x00000020
#define TOUCH_DOWN  1
#define TOUCH_MOVE  0
#define TOUCH_UP    2
#define kHIDPage_Consumer 0x0C
#define kHIDUsage_Csmr_Menu 0x40
#define kIOHIDEventDigitizerSenderID 0x000000010000027FULL

// HID Usage Page/Usage
#define kHIDPage_KeyboardOrKeypad 0x07

// ★ v8.4: ios-mcp验证的senderID（用于触摸和Unicode输入）
#define SYNTHETIC_SENDER_ID 0x8000000817319372ULL

// ★ v8.4: 硬件按键 Usage
#define kHIDUsage_Csmr_Power 0x30
#define kHIDUsage_Csmr_VolumeIncrement 0xE9
#define kHIDUsage_Csmr_VolumeDecrement 0xEA

// ★ v8.4: Unicode编码
#define kIOHIDUnicodeEncodingTypeUTF16LE 1

// ★ v8.4: 截图常量
static const NSUInteger kScreenshotTargetBytes = 400 * 1024;
static const CGFloat kScreenshotInitialJPEGQuality = 0.82;
static const CGFloat kScreenshotMinimumJPEGQuality = 0.45;
static const NSInteger kScreenshotJPEGSearchPasses = 6;
static const NSInteger kScreenshotResizePasses = 4;

// UIWindow私有方法
@interface UIWindow (StarCorePrivate)
@property (nonatomic, readonly) uint32_t _contextId;
@end

@interface UIApplication (StarCorePrivate)
- (void)_enqueueHIDEvent:(IOHIDEventRef)arg1;
@end


// ==================== 函数指针 ====================
// 旧方案函数
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;
static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef, uint32_t) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;
static void (*BKSHIDEventSetDigitizerInfoFunc)(IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float) = NULL;

// ★ v5.1: IOHIDUserDevice函数（虚拟触摸设备）
static IOHIDUserDeviceRef (*IOHIDUserDeviceCreateFunc)(CFAllocatorRef, CFDictionaryRef, IOOptionBits) = NULL;
static IOReturn (*IOHIDUserDeviceHandleReportFunc)(IOHIDUserDeviceRef, const uint8_t *, CFIndex) = NULL;

// ★ v8.4: IOHIDEventCreateDigitizerFingerEvent（ios-mcp触摸方案）
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;

// ★ v8.4: IOHIDEventCreateUnicodeEvent（Unicode文字输入）
static IOHIDEventRef (*IOHIDEventCreateUnicodeEventFunc)(CFAllocatorRef, uint64_t, const uint8_t *, uint32_t, uint32_t, IOOptionBits) = NULL;

// ★ v8.4: BKSHIDEventSendToProcess（发送事件到前台App进程）
static void (*BKSHIDEventSendToProcessFunc)(IOHIDEventRef, pid_t) = NULL;

// ★ v8.4: IOHIDEventSetIntegerValue（无options版本）
static void (*IOHIDEventSetIntegerValueFunc)(IOHIDEventRef, uint32_t, int32_t) = NULL;

// ★ v8.4: 截图函数
typedef UIImage *(*UICreateScreenUIImageFuncType)(void);
typedef CGImageRef (*UICreateCGImageFromIOSurfaceFuncType)(IOSurfaceRef surface);
typedef CGImageRef (*CARenderServerCaptureDisplayFuncType)(uint32_t serverPort, CFStringRef displayName, CFDictionaryRef options);

static UICreateScreenUIImageFuncType _UICreateScreenUIImageFunc = NULL;
static UICreateCGImageFromIOSurfaceFuncType _UICreateCGImageFromIOSurfaceFunc = NULL;
static CARenderServerCaptureDisplayFuncType _CARenderServerCaptureDisplayFunc = NULL;

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL;
static void *g_quartzCoreHandle = NULL;

// ★ v5.9: BKHIDSystemInterface runtime resolution (no link-time dependency)
static Class _bksClass = Nil;
static id bksSharedInstance(void) {
    if (!_bksClass) _bksClass = NSClassFromString(@"BKHIDSystemInterface");
    if (!_bksClass) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(_bksClass, @selector(sharedInstance));
}
static void bksInjectHIDEvent(id bks, void *event) {
    ((void (*)(id, SEL, void*))objc_msgSend)(bks, @selector(injectHIDEvent:), event);
}

// 全局变量
static uint32_t g_springBoardContextID = 2939785827;

// ★ v5.7: 线程安全保护 - 使用锁保护全局字符串
static NSString *g_contextSource = @"none";
static NSString *g_frontmostApp = @"";
static NSLock *g_globalsLock = nil;

// ★ v5.7: 安全读写全局字符串的辅助宏
#define SAFE_SET_GLOBAL(var, val) do { \
    [g_globalsLock lock]; \
    var = (val); \
    [g_globalsLock unlock]; \
} while(0)

#define SAFE_GET_GLOBAL(var) ({ \
    __block NSString *_val; \
    [g_globalsLock lock]; \
    _val = var; \
    [g_globalsLock unlock]; \
    _val; \
})

// ★ v5.1: 虚拟触摸设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";

// ★ v5.2: 虚拟键盘设备
static IOHIDUserDeviceRef g_virtualKeyboardDevice = NULL;
static bool g_virtualKeyboardReady = false;

// ★ v8.4: Unicode输入运行时解析状态
static bool g_unicodeRuntimeResolved = false;
static bool g_unicodeRuntimeAvailable = false;
static NSString *g_unicodeRuntimeSource = @"";
static NSString *g_unicodeRuntimeError = @"";

// ★ v8.4: BackBoard HID SendToProcess 运行时解析状态
static bool g_backBoardSendResolved = false;
static bool g_backBoardSendAvailable = false;
static NSString *g_backBoardSendSource = @"";
static NSString *g_backBoardSendError = @"";

// ★ v5.1 修复：HID Report Descriptor - 所有字段字节对齐
static const uint8_t g_multitouch_descriptor[] = {
    0x05, 0x0D,        // Usage Page (Digitizer)
    0x09, 0x04,        // Usage (Touch Screen)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        //   Report ID (1)
    0x09, 0x22,        //   Usage (Finger)
    0xA1, 0x02,        //   Collection (Logical)
    0x09, 0x42,        //     Usage (Tip Switch)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x01,        //     Logical Maximum (1)
    0x75, 0x08,        //     Report Size (8)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    0x75, 0x08,        //     Report Size (8)
    0x95, 0x07,        //     Report Count (7)
    0x81, 0x03,        //     Input (Constant)
    0x09, 0x51,        //     Usage (Contact Identifier)
    0x75, 0x08,        //     Report Size (8)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    0x09, 0x30,        //     Usage (Tip Pressure)
    0x15, 0x00,        //     Logical Minimum (0)
    0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    0x05, 0x01,        //     Usage Page (Generic Desktop)
    0x09, 0x01,        //     Usage (Pointer)
    0x15, 0x00,        //     Logical Minimum (0)
    0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x01,        //     Report Count (1)
    0x09, 0x30,        //     Usage (X)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    0x09, 0x31,        //     Usage (Y)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    0xC0,              //   End Collection
    0x05, 0x0D,        //   Usage Page (Digitizer)
    0x09, 0x54,        //   Usage (Contact Count)
    0x75, 0x08,        //   Report Size (8)
    0x95, 0x01,        //   Report Count (1)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x0A,        //     Logical Maximum (10)
    0x81, 0x02,        //   Input (Data, Variable, Absolute)
    0xC0               // End Collection
};

// ★ v5.2: 键盘HID Report Descriptor
static const uint8_t g_keyboard_descriptor[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x02,        //   Report ID (2)
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0xE0,        //   Usage Minimum (224)
    0x29, 0xE7,        //   Usage Maximum (231)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8)
    0x81, 0x02,        //   Input (Data, Variable, Absolute)
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x08,        //   Report Size (8)
    0x81, 0x01,        //   Input (Constant)
    0x95, 0x06,        //   Report Count (6)
    0x75, 0x08,        //   Report Size (8)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x65,        //   Logical Maximum (101)
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0x00,        //   Usage Minimum (0)
    0x29, 0x65,        //   Usage Maximum (101)
    0x81, 0x00,        //   Input (Data, Array)
    0xC0               // End Collection
};

// ==================== 前向声明 ====================
static void resetIdleTimer(void);
static void dispatchHIDEvent(IOHIDEventRef event);

// ★ v5.7: 主线程同步执行辅助函数
static void runOnMainThreadSync(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

// ★ v5.7: 在主线程获取屏幕尺寸（线程安全）
static CGRect getScreenBoundsSafe(void) {
    __block CGRect bounds = CGRectZero;
    runOnMainThreadSync(^{
        bounds = [UIScreen mainScreen].bounds;
    });
    return bounds;
}

// ★ v5.7: 在主线程获取屏幕scale（线程安全）
static CGFloat getScreenScaleSafe(void) {
    __block CGFloat scale = 1.0;
    runOnMainThreadSync(^{
        scale = [UIScreen mainScreen].scale;
    });
    return scale;
}

// ==================== 框架加载 ====================

static bool forceLoadFrameworks() {
    const char *iokitPaths[] = {
        "/System/Library/Frameworks/IOKit.framework/IOKit",
        "/System/Library/Frameworks/IOKit.framework/IOKit.dylib",
        NULL
    };
    for (int i = 0; iokitPaths[i]; i++) {
        dlerror();
        void *h = dlopen(iokitPaths[i], RTLD_NOW | RTLD_GLOBAL);
        if (h) { g_iokitHandle = h; NSLog(@"[StarCoreTweak] ✅ IOKit: %s", iokitPaths[i]); break; }
    }
    
    const char *bbsPaths[] = {
        "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",
        NULL
    };
    for (int i = 0; bbsPaths[i]; i++) {
        dlerror();
        void *h = dlopen(bbsPaths[i], RTLD_NOW | RTLD_GLOBAL);
        if (h) { g_bbsHandle = h; NSLog(@"[StarCoreTweak] ✅ BBS: %s", bbsPaths[i]); break; }
    }
    
    // ★ v8.4: 加载 QuartzCore（CARenderServerCaptureDisplay）
    const char *qcPaths[] = {
        "/System/Library/Frameworks/QuartzCore.framework/QuartzCore",
        NULL
    };
    for (int i = 0; qcPaths[i]; i++) {
        dlerror();
        void *h = dlopen(qcPaths[i], RTLD_NOW | RTLD_GLOBAL);
        if (h) { g_quartzCoreHandle = h; NSLog(@"[StarCoreTweak] ✅ QuartzCore: %s", qcPaths[i]); break; }
    }
    
    return (g_iokitHandle != NULL);
}

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    forceLoadFrameworks();
    
    void *handles[] = { g_iokitHandle, g_bbsHandle, g_quartzCoreHandle, RTLD_DEFAULT, NULL };
    
    #define LOAD_SYM(var, name) do { \
        var = NULL; \
        for (int _i = 0; handles[_i] && !var; _i++) { \
            var = (typeof(var))dlsym(handles[_i], name); \
        } \
        NSLog(@"[StarCoreTweak] %s = %@", name, var ? @"OK" : @"NULL"); \
    } while(0)
    
    LOAD_SYM(IOHIDEventCreateDigitizerEventFunc, "IOHIDEventCreateDigitizerEvent");
    LOAD_SYM(IOHIDEventCreateDigitizerFingerEventWithQualityFunc, "IOHIDEventCreateDigitizerFingerEventWithQuality");
    LOAD_SYM(IOHIDEventCreateKeyboardEventFunc, "IOHIDEventCreateKeyboardEvent");
    LOAD_SYM(IOHIDEventSetIntegerValueWithOptionsFunc, "IOHIDEventSetIntegerValueWithOptions");
    LOAD_SYM(IOHIDEventSetFloatValueFunc, "IOHIDEventSetFloatValue");
    LOAD_SYM(IOHIDEventSetSenderIDFunc, "IOHIDEventSetSenderID");
    LOAD_SYM(IOHIDEventAppendEventFunc, "IOHIDEventAppendEvent");
    LOAD_SYM(IOHIDEventSystemClientCreateFunc, "IOHIDEventSystemClientCreate");
    LOAD_SYM(IOHIDEventSystemClientDispatchEventFunc, "IOHIDEventSystemClientDispatchEvent");
    LOAD_SYM(BKSHIDEventSetDigitizerInfoFunc, "BKSHIDEventSetDigitizerInfo");
    
    // ★ v5.1: IOHIDUserDevice函数
    LOAD_SYM(IOHIDUserDeviceCreateFunc, "IOHIDUserDeviceCreate");
    LOAD_SYM(IOHIDUserDeviceHandleReportFunc, "IOHIDUserDeviceHandleReport");
    
    // ★ v8.4: IOHIDEventCreateDigitizerFingerEvent（ios-mcp触摸方案）
    LOAD_SYM(IOHIDEventCreateDigitizerFingerEventFunc, "IOHIDEventCreateDigitizerFingerEvent");
    
    // ★ v8.4: IOHIDEventCreateUnicodeEvent（Unicode文字输入）
    LOAD_SYM(IOHIDEventCreateUnicodeEventFunc, "IOHIDEventCreateUnicodeEvent");
    // 也尝试带下划线前缀
    if (!IOHIDEventCreateUnicodeEventFunc) {
        IOHIDEventCreateUnicodeEventFunc = (typeof(IOHIDEventCreateUnicodeEventFunc))dlsym(RTLD_DEFAULT, "_IOHIDEventCreateUnicodeEvent");
        if (IOHIDEventCreateUnicodeEventFunc) NSLog(@"[StarCoreTweak] _IOHIDEventCreateUnicodeEvent = OK");
    }
    
    // ★ v8.4: BKSHIDEventSendToProcess
    LOAD_SYM(BKSHIDEventSendToProcessFunc, "BKSHIDEventSendToProcess");
    if (!BKSHIDEventSendToProcessFunc) {
        BKSHIDEventSendToProcessFunc = (typeof(BKSHIDEventSendToProcessFunc))dlsym(RTLD_DEFAULT, "_BKSHIDEventSendToProcess");
        if (BKSHIDEventSendToProcessFunc) NSLog(@"[StarCoreTweak] _BKSHIDEventSendToProcess = OK");
    }
    
    // ★ v8.4: IOHIDEventSetIntegerValue（无options版本，ios-mcp使用）
    LOAD_SYM(IOHIDEventSetIntegerValueFunc, "IOHIDEventSetIntegerValue");
    
    // ★ v8.4: 截图函数
    LOAD_SYM(_UICreateScreenUIImageFunc, "_UICreateScreenUIImage");
    LOAD_SYM(_UICreateCGImageFromIOSurfaceFunc, "UICreateCGImageFromIOSurface");
    LOAD_SYM(_CARenderServerCaptureDisplayFunc, "CARenderServerCaptureDisplay");
    
    #undef LOAD_SYM
    
    if (!IOHIDEventCreateDigitizerEventFunc) { NSLog(@"[StarCoreTweak] ❌ 核心函数缺失"); return false; }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ v8.4 函数加载成功");
    NSLog(@"[StarCoreTweak]   IOHIDEventCreateDigitizerFingerEvent: %@", IOHIDEventCreateDigitizerFingerEventFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   IOHIDEventCreateUnicodeEvent: %@", IOHIDEventCreateUnicodeEventFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   BKSHIDEventSendToProcess: %@", BKSHIDEventSendToProcessFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   _UICreateScreenUIImage: %@", _UICreateScreenUIImageFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   CARenderServerCaptureDisplay: %@", _CARenderServerCaptureDisplayFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   UICreateCGImageFromIOSurface: %@", _UICreateCGImageFromIOSurfaceFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   IOHIDEventSetIntegerValue: %@", IOHIDEventSetIntegerValueFunc ? @"OK" : @"NULL");
    
    return true;
}

// ★ v8.4: 延迟解析Unicode运行时（从IOKit.framework动态加载）
static bool resolveUnicodeRuntime() {
    if (g_unicodeRuntimeResolved) return g_unicodeRuntimeAvailable;
    g_unicodeRuntimeResolved = true;
    
    // 先检查全局已加载的
    if (IOHIDEventCreateUnicodeEventFunc) {
        g_unicodeRuntimeAvailable = true;
        g_unicodeRuntimeSource = @"loadFunctions";
        return true;
    }
    
    // 从IOKit框架显式加载
    const char *paths[] = {
        "/System/Library/Frameworks/IOKit.framework/IOKit",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        void *handle = dlopen(paths[i], RTLD_LAZY);
        if (!handle) continue;
        
        IOHIDEventCreateUnicodeEventFunc = (typeof(IOHIDEventCreateUnicodeEventFunc))dlsym(handle, "IOHIDEventCreateUnicodeEvent");
        if (!IOHIDEventCreateUnicodeEventFunc) {
            IOHIDEventCreateUnicodeEventFunc = (typeof(IOHIDEventCreateUnicodeEventFunc))dlsym(handle, "_IOHIDEventCreateUnicodeEvent");
        }
        
        if (IOHIDEventCreateUnicodeEventFunc) {
            g_unicodeRuntimeAvailable = true;
            g_unicodeRuntimeSource = [NSString stringWithUTF8String:paths[i]];
            NSLog(@"[StarCoreTweak] ✅ IOHIDEventCreateUnicodeEvent resolved from %s", paths[i]);
            return true;
        }
    }
    
    g_unicodeRuntimeError = @"IOHIDEventCreateUnicodeEvent not found in IOKit.framework";
    NSLog(@"[StarCoreTweak] ❌ IOHIDEventCreateUnicodeEvent unavailable: %@", g_unicodeRuntimeError);
    return false;
}

// ★ v8.4: 延迟解析BKSHIDEventSendToProcess
static bool resolveBackBoardSendRuntime() {
    if (g_backBoardSendResolved) return g_backBoardSendAvailable;
    g_backBoardSendResolved = true;
    
    if (BKSHIDEventSendToProcessFunc) {
        g_backBoardSendAvailable = true;
        g_backBoardSendSource = @"loadFunctions";
        return true;
    }
    
    const char *paths[] = {
        "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        void *handle = dlopen(paths[i], RTLD_LAZY);
        if (!handle) continue;
        
        BKSHIDEventSendToProcessFunc = (typeof(BKSHIDEventSendToProcessFunc))dlsym(handle, "BKSHIDEventSendToProcess");
        if (!BKSHIDEventSendToProcessFunc) {
            BKSHIDEventSendToProcessFunc = (typeof(BKSHIDEventSendToProcessFunc))dlsym(handle, "_BKSHIDEventSendToProcess");
        }
        
        if (BKSHIDEventSendToProcessFunc) {
            g_backBoardSendAvailable = true;
            g_backBoardSendSource = [NSString stringWithUTF8String:paths[i]];
            NSLog(@"[StarCoreTweak] ✅ BKSHIDEventSendToProcess resolved from %s", paths[i]);
            return true;
        }
    }
    
    g_backBoardSendError = @"BKSHIDEventSendToProcess not found";
    NSLog(@"[StarCoreTweak] ❌ BKSHIDEventSendToProcess unavailable: %@", g_backBoardSendError);
    return false;
}

// ==================== Context ID获取（线程安全）====================

static uint32_t getContextIDFromCAWindowServer() {
    __block uint32_t bestCID = 0;
    runOnMainThreadSync(^{
        @try {
            Class wsClass = objc_getClass("CAWindowServer");
            if (!wsClass) wsClass = NSClassFromString(@"CAWindowServer");
            if (!wsClass) return;
            
            SEL serverSel = NSSelectorFromString(@"serverIfRunning");
            if (![wsClass respondsToSelector:serverSel]) return;
            
            id ws = ((id(*)(id, SEL))objc_msgSend)(wsClass, serverSel);
            if (!ws) return;
            
            SEL contextsSel = NSSelectorFromString(@"contexts");
            if (![ws respondsToSelector:contextsSel]) return;
            
            NSArray *contexts = ((NSArray *(*)(id, SEL))objc_msgSend)(ws, contextsSel);
            if (!contexts || contexts.count == 0) return;
            
            for (id ctx in contexts) {
                if (![ctx respondsToSelector:@selector(pid)]) continue;
                pid_t pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(ctx, @selector(pid));
                if (pid == getpid()) continue;
                
                if (pid == 0) {
                    if ([ctx respondsToSelector:@selector(contextID)]) {
                        uint32_t cid = ((uint32_t(*)(id, SEL))objc_msgSend)(ctx, @selector(contextID));
                        if (cid != 0) { bestCID = cid; break; }
                    }
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] getContextIDFromCAWindowServer exception: %@", e);
        }
    });
    return bestCID;
}

static uint32_t getKeyWindowContextID() {
    __block uint32_t cid = 0;
    runOnMainThreadSync(^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (!app) return;
            
            UIWindow *keyWin = nil;
            for (UIWindow *window in app.windows) {
                if (window.isKeyWindow) { keyWin = window; break; }
            }
            if (!keyWin && [app respondsToSelector:@selector(keyWindow)]) {
                keyWin = [app performSelector:@selector(keyWindow)];
            }
            
            if (keyWin && [keyWin respondsToSelector:@selector(_contextId)]) {
                uint32_t cid_val = ((uint32_t(*)(id, SEL))objc_msgSend)(keyWin, @selector(_contextId));
                if (cid_val != 0) {
                    SAFE_SET_GLOBAL(g_contextSource, @"keyWindow");
                    cid = cid_val;
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] getKeyWindowContextID exception: %@", e);
        }
    });
    return cid;
}

static uint32_t getTargetContextID() {
    uint32_t cid = getKeyWindowContextID();
    if (cid != 0) {
        runOnMainThreadSync(^{
            @try {
                UIApplication *app = [UIApplication sharedApplication];
                if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                    id frontApp = [app performSelector:@selector(frontmostApplication)];
                    if (frontApp && [frontApp respondsToSelector:@selector(bundleIdentifier)]) {
                        NSString *bid = [frontApp performSelector:@selector(bundleIdentifier)];
                        if (bid) SAFE_SET_GLOBAL(g_frontmostApp, bid);
                    }
                }
            } @catch (NSException *e) {}
        });
        return cid;
    }
    
    cid = getContextIDFromCAWindowServer();
    if (cid != 0) {
        SAFE_SET_GLOBAL(g_contextSource, @"CAWindowServer");
        return cid;
    }
    
    SAFE_SET_GLOBAL(g_contextSource, @"fallback");
    g_springBoardContextID = 2939785827;
    return g_springBoardContextID;
}

static void resetIdleTimer() {
    runOnMainThreadSync(^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (app) {
                ((void(*)(id, SEL, BOOL))objc_msgSend)(app, @selector(setIdleTimerDisabled:), YES);
                ((void(*)(id, SEL, BOOL))objc_msgSend)(app, @selector(setIdleTimerDisabled:), NO);
            }
        } @catch (NSException *e) {}
    });
}

static void dispatchHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    
    // ★ v5.9: 优先使用BKHIDSystemInterface
    @try {
        id bks = bksSharedInstance();
        if (bks) {
            bksInjectHIDEvent(bks, event);
            return;
        }
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] BKHIDSystemInterface injectHIDEvent failed: %@", e);
    }
    
    // 回退：IOHIDEventSystemClient
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        });
        if (client) IOHIDEventSystemClientDispatchEventFunc(client, event);
    }
}

// ★ v8.4: 获取前台App的PID
static pid_t getFrontmostAppPid() {
    __block pid_t pid = 0;
    runOnMainThreadSync(^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                id frontApp = [app performSelector:@selector(frontmostApplication)];
                if (frontApp && [frontApp respondsToSelector:@selector(processID)]) {
                    pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(frontApp, @selector(processID));
                }
            }
        } @catch (NSException *e) {}
    });
    return pid;
}

// ==================== 旧方案触摸函数 ====================

static void simulateTouchEx(int type, float x, float y, int fingerId, uint32_t cid, bool setDigitizerInfo) {
    if (!loadFunctions()) return;
    
    int touch_ = (type == TOUCH_DOWN) ? 1 : 0;
    int range_ = (type == TOUCH_UP) ? 0 : 1;
    uint32_t hem = (touch_ << 0) | (range_ << 1);
    uint64_t ts = mach_absolute_time();
    
    IOHIDEventRef hand = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault, ts, 0, 0, kIOHIDTransducerTypeHand,
        fingerId, 0, 0, x, y, 0, 0, touch_ ? true : false,
        touch_ ? true : false, kIOHIDDigitizerEventTouch);
    
    if (!hand) return;
    
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(hand, kIOHIDEventDigitizerSenderID);
    
    if (setDigitizerInfo && BKSHIDEventSetDigitizerInfoFunc) {
        BKSHIDEventSetDigitizerInfoFunc(hand, cid, 1, 1, NULL, 0, touch_ ? 0.2f : 0.0f);
    }
    
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerEventMask, hem, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerRange, range_, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerTouch, touch_, (unsigned int)-268435456);
    
    resetIdleTimer();
    dispatchHIDEvent(hand);
}

static void simulateTouch(int type, float x, float y, int fingerId) {
    uint32_t cid = getTargetContextID();
    simulateTouchEx(type, x, y, fingerId, cid, cid != 0);
}

static void simulateTap_old(float x, float y) { simulateTouch(TOUCH_DOWN, x, y, 1); usleep(50000); simulateTouch(TOUCH_UP, x, y, 1); }
static void simulateSwipe_old(float fX, float fY, float tX, float tY, float dur) {
    int steps = (int)(dur * 120); if (steps < 2) steps = 2;
    simulateTouch(TOUCH_DOWN, fX, fY, 1);
    for (int i = 1; i <= steps; i++) { float t = (float)i/steps; simulateTouch(TOUCH_MOVE, fX+(tX-fX)*t, fY+(tY-fY)*t, 1); usleep((useconds_t)(dur*1000000/steps)); }
    simulateTouch(TOUCH_UP, tX, tY, 1);
}
static void simulateLongPress_old(float x, float y, float d) { simulateTouch(TOUCH_DOWN, x, y, 1); usleep((useconds_t)(d*1000000)); simulateTouch(TOUCH_UP, x, y, 1); }
static void simulateHomeButton() {
    if (!loadFunctions()) return;
    uint64_t ts = mach_absolute_time();
    IOHIDEventRef d = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, kHIDPage_Consumer, kHIDUsage_Csmr_Menu, true, 0);
    if (d) { if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(d, kIOHIDEventDigitizerSenderID); dispatchHIDEvent(d); }
    usleep(50000); ts = mach_absolute_time();
    IOHIDEventRef u = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, kHIDPage_Consumer, kHIDUsage_Csmr_Menu, false, 0);
    if (u) { if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(u, kIOHIDEventDigitizerSenderID); dispatchHIDEvent(u); }
    resetIdleTimer();
}

// ★ v8.4: 统一硬件按键模拟（ios-mcp方案）
static void sendButtonEvent(uint32_t usagePage, uint32_t usage, float durationMs) {
    if (!loadFunctions()) return;
    
    uint64_t ts = mach_absolute_time();
    
    // key down
    IOHIDEventRef downEvent = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, usagePage, usage, true, 0);
    if (downEvent) {
        if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(downEvent, SYNTHETIC_SENDER_ID);
        if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(downEvent, 4, 1); // flags
        dispatchHIDEvent(downEvent);
    }
    
    // duration
    float ms = durationMs > 0 ? durationMs : 100.0f;
    usleep((useconds_t)(ms * 1000));
    
    // key up
    ts = mach_absolute_time();
    IOHIDEventRef upEvent = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, usagePage, usage, false, 0);
    if (upEvent) {
        if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(upEvent, SYNTHETIC_SENDER_ID);
        if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(upEvent, 4, 1);
        dispatchHIDEvent(upEvent);
    }
    
    resetIdleTimer();
}

// ==================== v8.4: ios-mcp触摸方案（IOHIDEventCreateDigitizerFingerEvent）====================

// ★ v8.4: 创建触摸子事件（归一化坐标 0~1）
static IOHIDEventRef createChildTouchEvent(int phase, int index, float normX, float normY) {
    if (!IOHIDEventCreateDigitizerFingerEventFunc) return NULL;
    
    uint32_t eventMask = 0;
    bool range = true;
    bool touch = true;
    
    switch (phase) {
        case TOUCH_DOWN: // Began
            eventMask = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch;
            range = true; touch = true;
            break;
        case TOUCH_MOVE: // Moved
            eventMask = kIOHIDDigitizerEventPosition;
            range = true; touch = true;
            break;
        case TOUCH_UP: // Ended
            eventMask = kIOHIDDigitizerEventTouch;
            range = false; touch = false;
            break;
    }
    
    IOHIDEventRef child = IOHIDEventCreateDigitizerFingerEventFunc(
        kCFAllocatorDefault,
        mach_absolute_time(),
        index,         // finger index
        3,             // transducer type
        eventMask,
        normX,         // normalized X (0~1)
        normY,         // normalized Y (0~1)
        0.0f,          // twist
        0.0f,          // major radius
        0.0f,          // minor radius
        range,
        touch,
        0
    );
    
    if (child && IOHIDEventSetFloatValueFunc) {
        IOHIDEventSetFloatValueFunc(child, 0xb0014, 0.04f);
        IOHIDEventSetFloatValueFunc(child, 0xb0015, 0.04f);
    }
    
    return child;
}

// ★ v8.4: 通过ios-mcp方案发送触摸事件
static void dispatchTouchViaIOHIDFinger(int phase, int fingerIndex, float normX, float normY) {
    if (!loadFunctions()) return;
    if (!IOHIDEventCreateDigitizerFingerEventFunc) {
        // 回退到旧方案
        simulateTouch(phase, normX, normY, fingerIndex);
        return;
    }
    
    // 创建父事件
    IOHIDEventRef parent = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault,
        mach_absolute_time(),
        kIOHIDTransducerTypeHand, // 3
        99,    // parent index
        1,     // ?
        0, 0, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, false, false, 0
    );
    if (!parent) return;
    
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parent, 0xb0019, 1);
        IOHIDEventSetIntegerValueFunc(parent, 0x4, 1);
    }
    
    // 创建并附加子事件
    IOHIDEventRef child = createChildTouchEvent(phase, fingerIndex, normX, normY);
    if (child && IOHIDEventAppendEventFunc) {
        IOHIDEventAppendEventFunc(parent, child, 0);
    }
    
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parent, 0xb0007, 0x23);
        IOHIDEventSetIntegerValueFunc(parent, 0xb0008, 0x1);
        IOHIDEventSetIntegerValueFunc(parent, 0xb0009, 0x1);
    }
    
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(parent, SYNTHETIC_SENDER_ID);
    
    resetIdleTimer();
    dispatchHIDEvent(parent);
}

// ★ v8.4: ios-mcp方案 tap（使用归一化坐标）
static void iosmcpTap(float normX, float normY) {
    dispatchTouchViaIOHIDFinger(TOUCH_DOWN, 1, normX, normY);
    usleep(30000);
    dispatchTouchViaIOHIDFinger(TOUCH_MOVE, 1, normX, normY);
    dispatchTouchViaIOHIDFinger(TOUCH_UP, 1, normX, normY);
}

// ★ v8.4: ios-mcp方案 swipe（使用归一化坐标）
static void iosmcpSwipe(float normStartX, float normStartY, float normEndX, float normEndY, float duration) {
    int steps = (int)(duration * 60);
    if (steps < 2) steps = 2;
    
    dispatchTouchViaIOHIDFinger(TOUCH_DOWN, 1, normStartX, normStartY);
    
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        float x = normStartX + (normEndX - normStartX) * t;
        float y = normStartY + (normEndY - normStartY) * t;
        dispatchTouchViaIOHIDFinger(TOUCH_MOVE, 1, x, y);
        usleep(16667);
    }
    
    dispatchTouchViaIOHIDFinger(TOUCH_UP, 1, normEndX, normEndY);
}

// ==================== v5.1: IOHIDUserDevice虚拟触摸设备 ====================

static bool initVirtualKeyboardDevice() {
    if (g_virtualKeyboardReady) return true;
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    NSData *descriptorData = [NSData dataWithBytes:g_keyboard_descriptor length:sizeof(g_keyboard_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    properties[@"Product"] = @"StarCore Virtual Keyboard";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0002);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    properties[@"PrimaryUsagePage"] = @(0x07);
    properties[@"PrimaryUsage"] = @(0x06);
    properties[@"DeviceUsagePage"] = @(0x01);
    properties[@"DeviceUsage"] = @(0x06);
    
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    g_virtualKeyboardDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualKeyboardDevice) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate键盘设备失败");
        return false;
    }
    
    g_virtualKeyboardReady = true;
    NSLog(@"[StarCoreTweak] ✅ 虚拟键盘设备创建成功");
    return true;
}

static bool sendKeyboardReport(uint8_t modifiers, const uint8_t *keyCodes, int keyCodeCount) {
    if (!g_virtualKeyboardReady || !IOHIDUserDeviceHandleReportFunc) return false;
    
    uint8_t report[9] = {0};
    report[0] = 0x02;
    report[1] = modifiers;
    report[2] = 0;
    int count = (keyCodeCount > 6) ? 6 : keyCodeCount;
    for (int i = 0; i < count; i++) report[3 + i] = keyCodes[i];
    
    IOReturn result = IOHIDUserDeviceHandleReportFunc(g_virtualKeyboardDevice, report, sizeof(report));
    return result == kIOReturnSuccess;
}

static void handleKeyPressViaVirtualDevice(uint32_t page, uint32_t usage) {
    if (!g_virtualKeyboardReady) return;
    uint8_t keys[1] = { (uint8_t)usage };
    sendKeyboardReport(0, keys, 1);
    usleep(50000);
    uint8_t noKeys[1] = { 0 };
    sendKeyboardReport(0, noKeys, 0);
    resetIdleTimer();
}

static bool initVirtualTouchDevice() {
    if (g_virtualDeviceReady && g_virtualKeyboardReady) return true;
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        g_virtualDeviceError = @"IOHIDUserDevice函数未加载";
        return false;
    }
    
    if (!g_virtualKeyboardReady) initVirtualKeyboardDevice();
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    NSData *descriptorData = [NSData dataWithBytes:g_multitouch_descriptor length:sizeof(g_multitouch_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    properties[@"Product"] = @"StarCore Virtual Touch";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0001);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    properties[@"PrimaryUsagePage"] = @(0x0D);
    properties[@"PrimaryUsage"] = @(0x04);
    properties[@"DeviceUsagePage"] = @(0x0D);
    properties[@"DeviceUsage"] = @(0x04);
    
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    g_virtualDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualDevice) {
        g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate触摸设备失败");
    } else {
        g_virtualDeviceReady = true;
        g_virtualDeviceError = @"";
        NSLog(@"[StarCoreTweak] ✅ 虚拟触摸设备创建成功");
    }
    
    return g_virtualDeviceReady || g_virtualKeyboardReady;
}

static bool sendTouchReport(bool tipSwitch, uint8_t contactId, uint16_t pressure, uint16_t xNorm, uint16_t yNorm, uint8_t contactCount) {
    if (!g_virtualDeviceReady || !IOHIDUserDeviceHandleReportFunc) return false;
    
    uint8_t report[17] = {0};
    report[0] = 0x01;
    report[1] = tipSwitch ? 0x01 : 0x00;
    report[9] = contactId;
    report[10] = pressure & 0xFF;
    report[11] = (pressure >> 8) & 0xFF;
    report[12] = xNorm & 0xFF;
    report[13] = (xNorm >> 8) & 0xFF;
    report[14] = yNorm & 0xFF;
    report[15] = (yNorm >> 8) & 0xFF;
    report[16] = contactCount;
    
    IOReturn result = IOHIDUserDeviceHandleReportFunc(g_virtualDevice, report, sizeof(report));
    return result == kIOReturnSuccess;
}

static inline uint16_t normalizeCoord(float coord) {
    if (coord < 0) coord = 0;
    if (coord > 1) coord = 1;
    return (uint16_t)(coord * 32767.0f);
}

static void virtualTap(float x, float y) {
    if (!g_virtualDeviceReady) return;
    uint16_t xN = normalizeCoord(x), yN = normalizeCoord(y);
    sendTouchReport(true, 0, 200, xN, yN, 1);
    usleep(50000);
    sendTouchReport(false, 0, 0, xN, yN, 0);
}

static void virtualSwipe(float startX, float startY, float endX, float endY, float duration) {
    if (!g_virtualDeviceReady) return;
    int steps = (int)(duration * 60); if (steps < 2) steps = 2;
    uint16_t startXN = normalizeCoord(startX), startYN = normalizeCoord(startY);
    uint16_t endXN = normalizeCoord(endX), endYN = normalizeCoord(endY);
    sendTouchReport(true, 0, 200, startXN, startYN, 1);
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        uint16_t xN = startXN + (int)((endXN - startXN) * t);
        uint16_t yN = startYN + (int)((endYN - startYN) * t);
        sendTouchReport(true, 0, 200, xN, yN, 1);
        usleep(16667);
    }
    sendTouchReport(false, 0, 0, endXN, endYN, 0);
}

static void virtualLongPress(float x, float y, float duration) {
    if (!g_virtualDeviceReady) return;
    uint16_t xN = normalizeCoord(x), yN = normalizeCoord(y);
    uint32_t sleepTimeUs = (uint32_t)(duration * 1000000);
    uint32_t elapsed = 0;
    sendTouchReport(true, 0, 200, xN, yN, 1);
    while (elapsed < sleepTimeUs) {
        usleep(50000); elapsed += 50000;
        uint16_t jitterX = xN + (elapsed / 50000) % 3 - 1;
        uint16_t jitterY = yN + (elapsed / 50000) % 3 - 1;
        sendTouchReport(true, 0, 200, jitterX, jitterY, 1);
    }
    sendTouchReport(false, 0, 0, xN, yN, 0);
}

// ==================== v5.2: 键盘字符输入 ====================

static bool keyToUsage(NSString *key, uint32_t *page, uint32_t *usage) {
    static NSDictionary *keyMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyMap = @{
            @"return": @(0x28), @"enter": @(0x28), @"tab": @(0x2B), @"space": @(0x2C),
            @"delete": @(0x2A), @"backspace": @(0x2A), @"escape": @(0x29), @"esc": @(0x29),
            @"a": @(0x04), @"b": @(0x05), @"c": @(0x06), @"d": @(0x07),
            @"e": @(0x08), @"f": @(0x09), @"g": @(0x0A), @"h": @(0x0B),
            @"i": @(0x0C), @"j": @(0x0D), @"k": @(0x0E), @"l": @(0x0F),
            @"m": @(0x10), @"n": @(0x11), @"o": @(0x12), @"p": @(0x13),
            @"q": @(0x14), @"r": @(0x15), @"s": @(0x16), @"t": @(0x17),
            @"u": @(0x18), @"v": @(0x19), @"w": @(0x1A), @"x": @(0x1B),
            @"y": @(0x1C), @"z": @(0x1D),
            @"1": @(0x1E), @"2": @(0x1F), @"3": @(0x20), @"4": @(0x21),
            @"5": @(0x22), @"6": @(0x23), @"7": @(0x24), @"8": @(0x25),
            @"9": @(0x26), @"0": @(0x27),
            @"-": @(0x2D), @"=": @(0x2E), @"[": @(0x2F), @"]": @(0x30),
            @"\\": @(0x31), @";": @(0x33), @"'": @(0x34), @"`": @(0x35),
            @",": @(0x36), @".": @(0x37), @"/": @(0x38),
            @"f1": @(0x3A), @"f2": @(0x3B), @"f3": @(0x3C), @"f4": @(0x3D),
            @"f5": @(0x3E), @"f6": @(0x3F), @"f7": @(0x40), @"f8": @(0x41),
            @"f9": @(0x42), @"f10": @(0x43), @"f11": @(0x44), @"f12": @(0x45),
        };
    });
    
    NSString *lowerKey = [key lowercaseString];
    NSNumber *usageNum = keyMap[lowerKey];
    
    if (!usageNum) {
        if (key.length == 1) {
            unichar c = [key characterAtIndex:0];
            if (c >= 'a' && c <= 'z') { *usage = 0x04 + (c - 'a'); *page = kHIDPage_KeyboardOrKeypad; return true; }
            else if (c >= 'A' && c <= 'Z') { *usage = 0x04 + (c - 'A'); *page = kHIDPage_KeyboardOrKeypad; return true; }
            else if (c >= '0' && c <= '9') { *usage = 0x1E + (c - '0'); *page = kHIDPage_KeyboardOrKeypad; return true; }
        }
        return false;
    }
    
    *usage = [usageNum unsignedIntValue];
    *page = kHIDPage_KeyboardOrKeypad;
    return true;
}

static void handleKeyPress(NSString *key) {
    uint32_t page = 0, usage = 0;
    if (!keyToUsage(key, &page, &usage)) return;
    if (g_virtualKeyboardReady) { handleKeyPressViaVirtualDevice(page, usage); return; }
    NSLog(@"[StarCoreTweak] ⚠️ 键盘输入需要虚拟键盘设备");
}

static void handleTextInput(NSString *text) {
    if (!text || text.length == 0) return;
    if (!g_virtualKeyboardReady) return;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        NSString *charStr = [NSString stringWithCharacters:&c length:1];
        uint32_t page = 0, usage = 0;
        if (keyToUsage(charStr, &page, &usage)) handleKeyPressViaVirtualDevice(page, usage);
        usleep(30000);
    }
}

// ==================== v8.4: Unicode文字输入 ====================

// ★ v8.4: 检查文本是否只含ASCII（可用HID键盘输入）
static bool textCanUseHIDKeyboard(NSString *text) {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar ch = [text characterAtIndex:i];
        if (ch >= 128) return false;
    }
    return true;
}

// ★ v8.4: 分块发送Unicode文本（每块最多64个UTF-16单元）
static NSArray<NSString *> *textChunks(NSString *text, NSUInteger maxUTF16Units) {
    if (maxUTF16Units == 0) maxUTF16Units = 64;
    
    NSMutableArray<NSString *> *chunks = [NSMutableArray array];
    __block NSMutableString *current = [NSMutableString string];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substringRange; (void)enclosingRange; (void)stop;
        
        if (substring.length > maxUTF16Units) {
            if (current.length > 0) { [chunks addObject:[current copy]]; [current setString:@""]; }
            [chunks addObject:substring];
            return;
        }
        
        if (current.length > 0 && current.length + substring.length > maxUTF16Units) {
            [chunks addObject:[current copy]];
            [current setString:@""];
        }
        [current appendString:substring];
    }];
    
    if (current.length > 0) [chunks addObject:[current copy]];
    return chunks;
}

// ★ v8.4: 发送Unicode文本块（IOHIDEventCreateUnicodeEvent）
static bool dispatchUnicodeTextChunk(NSString *chunk, pid_t targetPid, NSString **outError) {
    if (!resolveUnicodeRuntime() || !IOHIDEventCreateUnicodeEventFunc) {
        if (outError) *outError = g_unicodeRuntimeError;
        return false;
    }
    
    // 编码为UTF-16LE
    NSData *payload = [chunk dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    if (payload.length == 0) {
        if (outError) *outError = @"Failed to encode text as UTF-16LE";
        return false;
    }
    
    IOHIDEventRef event = IOHIDEventCreateUnicodeEventFunc(
        kCFAllocatorDefault,
        mach_absolute_time(),
        (const uint8_t *)payload.bytes,
        (uint32_t)payload.length,
        kIOHIDUnicodeEncodingTypeUTF16LE,
        0
    );
    
    if (!event) {
        if (outError) *outError = @"IOHIDEventCreateUnicodeEvent returned nil";
        return false;
    }
    
    if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(event, 4, 1); // flags
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(event, SYNTHETIC_SENDER_ID);
    
    // ★ v8.4: 优先通过BKSHIDEventSendToProcess发送到前台App
    if (resolveBackBoardSendRuntime() && BKSHIDEventSendToProcessFunc && targetPid > 0) {
        BKSHIDEventSendToProcessFunc(event, targetPid);
        CFRelease(event);
        return true;
    }
    
    // 回退：通过BKHIDSystemInterface injectHIDEvent
    @try {
        id bks = bksSharedInstance();
        if (bks) {
            bksInjectHIDEvent(bks, event);
            CFRelease(event);
            return true;
        }
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] BKS injectHIDEvent for unicode failed: %@", e);
    }
    
    // 最终回退：IOHIDEventSystemClient
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        });
        if (client) {
            IOHIDEventSystemClientDispatchEventFunc(client, event);
            CFRelease(event);
            return true;
        }
    }
    
    CFRelease(event);
    if (outError) *outError = @"No dispatch path available for unicode event";
    return false;
}

// ★ v8.4: Unicode文本输入主函数
static NSDictionary *doInputText(NSString *text) {
    if (!text || text.length == 0) return @{@"success": @NO, @"error": @"text required"};
    
    // 获取前台App PID
    pid_t targetPid = getFrontmostAppPid();
    
    // 1. 尝试Unicode输入
    if (resolveUnicodeRuntime() && IOHIDEventCreateUnicodeEventFunc) {
        NSUInteger chunkSize = 64;
        NSArray<NSString *> *chunks = textChunks(text, chunkSize);
        
        bool allOk = true;
        NSString *firstError = nil;
        for (NSString *chunk in chunks) {
            NSString *chunkError = nil;
            if (!dispatchUnicodeTextChunk(chunk, targetPid, &chunkError)) {
                allOk = false;
                if (!firstError) firstError = chunkError;
                break;
            }
            usleep(50000);
        }
        
        if (allOk) {
            return @{@"success": @YES, @"method": @"IOHIDEventCreateUnicodeEvent", @"chunks": @(chunks.count)};
        }
        
        NSLog(@"[StarCoreTweak] ⚠️ Unicode输入失败: %@, 尝试降级方案", firstError);
    }
    
    // 2. 降级方案：clipboard + paste
    NSLog(@"[StarCoreTweak] 📋 使用 clipboard+paste 降级方案");
    
    // 设置剪贴板
    runOnMainThreadSync(^{
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        [pb setString:text];
    });
    
    // 模拟粘贴（Cmd+V 或长按→粘贴）
    // 在iOS上，通过模拟长按然后选择粘贴不太可靠
    // 更好的方式：通过键盘 Cmd+V
    if (g_virtualKeyboardReady) {
        // Cmd+V: modifier=0x01(GUI/Command), keycode=0x19(V)
        uint8_t vKey[1] = { 0x19 };
        sendKeyboardReport(0x08, vKey, 1); // 0x08 = Right GUI
        usleep(30000);
        uint8_t noKeys[1] = { 0 };
        sendKeyboardReport(0, noKeys, 0);
        usleep(50000);
    }
    
    return @{@"success": @YES, @"method": @"clipboard_paste", @"warning": @"Unicode HID unavailable, used clipboard fallback"};
}

// ★ v8.4: 逐字输入
static NSDictionary *doTypeText(NSString *text, float delayMs) {
    if (!text || text.length == 0) return @{@"success": @NO, @"error": @"text required"};
    
    if (delayMs <= 0) delayMs = 50;
    useconds_t delay = (useconds_t)(delayMs * 1000);
    
    pid_t targetPid = getFrontmostAppPid();
    
    // 1. 尝试Unicode逐字输入
    if (resolveUnicodeRuntime() && IOHIDEventCreateUnicodeEventFunc) {
        NSArray<NSString *> *chunks = textChunks(text, 1); // 每块1个字符
        
        bool allOk = true;
        NSString *firstError = nil;
        for (NSString *chunk in chunks) {
            NSString *chunkError = nil;
            if (!dispatchUnicodeTextChunk(chunk, targetPid, &chunkError)) {
                allOk = false;
                if (!firstError) firstError = chunkError;
                break;
            }
            if (delay > 0) usleep(delay);
        }
        
        if (allOk) {
            return @{@"success": @YES, @"method": @"IOHIDEventCreateUnicodeEvent_charByChar", @"chunks": @(chunks.count)};
        }
    }
    
    // 2. 降级：ASCII键盘输入
    if (textCanUseHIDKeyboard(text)) {
        handleTextInput(text);
        return @{@"success": @YES, @"method": @"HID_keyboard_ASCII_fallback"};
    }
    
    // 3. 最终降级：clipboard+paste
    runOnMainThreadSync(^{
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        [pb setString:text];
    });
    if (g_virtualKeyboardReady) {
        uint8_t vKey[1] = { 0x19 };
        sendKeyboardReport(0x08, vKey, 1);
        usleep(30000);
        uint8_t noKeys[1] = { 0 };
        sendKeyboardReport(0, noKeys, 0);
    }
    return @{@"success": @YES, @"method": @"clipboard_paste", @"warning": @"Unicode and ASCII keyboard unavailable"};
}

// ==================== v8.4: 截图功能 ====================

// ★ v8.4: 从CGImage创建UIImage（通过bitmap，避免方向问题）
static UIImage *bitmapImageFromCGImage(CGImageRef cgImage, CGFloat scale) {
    if (!cgImage) return nil;
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0) return nil;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) return nil;
    
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace,
        kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (!context) return nil;
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGImageRef copiedImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (!copiedImage) return nil;
    
    UIImage *image = [UIImage imageWithCGImage:copiedImage scale:(scale > 0 ? scale : 1.0) orientation:UIImageOrientationUp];
    CGImageRelease(copiedImage);
    return image;
}

// ★ v8.4: JPEG二分搜索压缩
static NSData *JPEGDataForImage(UIImage *image, NSUInteger maxBytes) {
    NSData *bestData = UIImageJPEGRepresentation(image, kScreenshotInitialJPEGQuality);
    if (!bestData) return nil;
    if (bestData.length <= maxBytes) return bestData;
    
    NSData *minimumData = UIImageJPEGRepresentation(image, kScreenshotMinimumJPEGQuality);
    if (!minimumData) return bestData;
    if (minimumData.length > maxBytes) return minimumData;
    
    CGFloat low = kScreenshotMinimumJPEGQuality;
    CGFloat high = kScreenshotInitialJPEGQuality;
    for (NSInteger pass = 0; pass < kScreenshotJPEGSearchPasses; pass++) {
        CGFloat quality = (low + high) / 2.0;
        NSData *candidate = UIImageJPEGRepresentation(image, quality);
        if (!candidate) break;
        if (candidate.length > maxBytes) high = quality;
        else { low = quality; bestData = candidate; }
    }
    return bestData;
}

// ★ v8.4: 缩放图片
static UIImage *resizedImageToFitBytes(UIImage *image, NSUInteger currentBytes) {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage || currentBytes == 0) return nil;
    
    CGFloat ratio = sqrt((double)kScreenshotTargetBytes / (double)currentBytes) * 0.98;
    ratio = MIN(ratio, 0.9);
    ratio = MAX(ratio, 0.55);
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    CGSize targetSize = CGSizeMake(MAX((CGFloat)floor(width * ratio), 1.0), MAX((CGFloat)floor(height * ratio), 1.0));
    if (targetSize.width >= width || targetSize.height >= height) return nil;
    
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
}

// ★ v8.4: 编码图片为base64 payload
static NSDictionary *encodedPayloadForImage(UIImage *image) {
    if (!image) return nil;
    
    // 先试PNG
    NSData *pngData = UIImagePNGRepresentation(image);
    if (pngData.length > 0 && pngData.length <= kScreenshotTargetBytes) {
        return @{@"data": [pngData base64EncodedStringWithOptions:0], @"mimeType": @"image/png"};
    }
    
    // JPEG多轮压缩+缩放
    UIImage *workingImage = image;
    NSData *bestJPEGData = nil;
    
    for (NSInteger attempt = 0; attempt < kScreenshotResizePasses; attempt++) {
        NSData *jpegData = JPEGDataForImage(workingImage, kScreenshotTargetBytes);
        if (!jpegData) break;
        
        bestJPEGData = jpegData;
        if (jpegData.length <= kScreenshotTargetBytes) {
            return @{@"data": [jpegData base64EncodedStringWithOptions:0], @"mimeType": @"image/jpeg"};
        }
        
        UIImage *scaledImage = resizedImageToFitBytes(workingImage, jpegData.length);
        if (!scaledImage) break;
        workingImage = scaledImage;
    }
    
    if (bestJPEGData.length > 0) {
        return @{@"data": [bestJPEGData base64EncodedStringWithOptions:0], @"mimeType": @"image/jpeg"};
    }
    
    return nil;
}

// ★ v8.4: 截图方法1 - CARenderServerCaptureDisplay
static UIImage *screenshotFromRenderServer() {
    if (!_CARenderServerCaptureDisplayFunc) return nil;
    
    NSArray<NSString *> *displayNames = @[@"LCD", @"Main"];
    CGFloat scale = getScreenScaleSafe();
    
    for (NSString *displayName in displayNames) {
        CGImageRef cgImage = _CARenderServerCaptureDisplayFunc(0, (__bridge CFStringRef)displayName, nil);
        if (!cgImage) continue;
        UIImage *image = bitmapImageFromCGImage(cgImage, scale);
        CGImageRelease(cgImage);
        if (image) return image;
    }
    return nil;
}

// ★ v8.4: 截图方法2 - _UICreateScreenUIImage
static UIImage *screenshotFromUICreateScreenUIImage() {
    if (!_UICreateScreenUIImageFunc) return nil;
    UIImage *image = _UICreateScreenUIImageFunc();
    return image;
}

// ★ v8.4: 截图方法3 - IOSurface
static UIImage *screenshotFromIOSurface() {
    SEL selector = NSSelectorFromString(@"createScreenIOSurface");
    if (![UIWindow respondsToSelector:selector] || !_UICreateCGImageFromIOSurfaceFunc) return nil;
    
    IOSurfaceRef surface = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    surface = (__bridge IOSurfaceRef)[UIWindow performSelector:selector];
#pragma clang diagnostic pop
    if (!surface) return nil;
    
    CGImageRef cgImage = _UICreateCGImageFromIOSurfaceFunc(surface);
    CFRelease(surface);
    if (!cgImage) return nil;
    
    CGFloat scale = getScreenScaleSafe();
    UIImage *image = bitmapImageFromCGImage(cgImage, scale);
    CGImageRelease(cgImage);
    return image;
}

// ★ v8.4: 截图方法4 - Window capture (drawViewHierarchy)
static UIImage *screenshotFromWindowCapture() {
    __block UIImage *image = nil;
    runOnMainThreadSync(^{
        @try {
            UIWindow *keyWindow = nil;
            for (UIWindow *window in [UIApplication sharedApplication].windows) {
                if (window.isKeyWindow) { keyWindow = window; break; }
            }
            if (!keyWindow) return;
            
            UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
            format.scale = [UIScreen mainScreen].scale;
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:keyWindow.bounds.size format:format];
            image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                [keyWindow drawViewHierarchyInRect:keyWindow.bounds afterScreenUpdates:NO];
            }];
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] window capture exception: %@", e);
        }
    });
    return image;
}

// ★ v8.5: 截图主函数 - 超时保护版
// 在TCP线程发起，主线程执行截图，用semaphore+超时避免永久阻塞
static NSDictionary *doScreenshot() {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIImage *image = nil;
            NSString *source = @"none";
            
            // 降级策略1: CARenderServerCaptureDisplay
            image = screenshotFromRenderServer();
            NSLog(@"[StarCoreTweak] 📸 method1 renderServer: %@", image ? [NSString stringWithFormat:@"%.0fx%.0f scale=%.1f", image.size.width, image.size.height, image.scale] : @"nil");
            if (image) source = @"CARenderServerCaptureDisplay";
            
            // 降级策略2: _UICreateScreenUIImage
            if (!image) {
                image = screenshotFromUICreateScreenUIImage();
                NSLog(@"[StarCoreTweak] 📸 method2 UICreateScreen: %@", image ? [NSString stringWithFormat:@"%.0fx%.0f scale=%.1f", image.size.width, image.size.height, image.scale] : @"nil");
                if (image) source = @"_UICreateScreenUIImage";
            }
            
            // 降级策略3: IOSurface
            if (!image) {
                image = screenshotFromIOSurface();
                NSLog(@"[StarCoreTweak] 📸 method3 IOSurface: %@", image ? [NSString stringWithFormat:@"%.0fx%.0f scale=%.1f", image.size.width, image.size.height, image.scale] : @"nil");
                if (image) source = @"IOSurface";
            }
            
            // 降级策略4: Window capture
            if (!image) {
                image = screenshotFromWindowCapture();
                NSLog(@"[StarCoreTweak] 📸 method4 windowCapture: %@", image ? [NSString stringWithFormat:@"%.0fx%.0f scale=%.1f", image.size.width, image.size.height, image.scale] : @"nil");
                if (image) source = @"window_capture";
            }
            
            if (!image) {
                result = @{@"success": @NO, @"error": @"All screenshot methods failed"};
                dispatch_semaphore_signal(sema);
                return;
            }
            
            // 编码图片
            NSLog(@"[StarCoreTweak] 📸 encoding image: %.0fx%.0f scale=%.1f", image.size.width, image.size.height, image.scale);
            NSData *pngData = UIImagePNGRepresentation(image);
            NSLog(@"[StarCoreTweak] 📸 PNG size: %lu bytes", (unsigned long)pngData.length);
            NSDictionary *payload = encodedPayloadForImage(image);
            NSLog(@"[StarCoreTweak] 📸 payload: %@", payload ? [NSString stringWithFormat:@"mimeType=%@ dataLen=%lu", payload[@"mimeType"], (unsigned long)[payload[@"data"] length]] : @"nil");
            if (!payload) {
                result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"Failed to encode screenshot (image size: %.0fx%.0f, scale: %.1f)", image.size.width, image.size.height, image.scale]};
                dispatch_semaphore_signal(sema);
                return;
            }
            
            NSMutableDictionary *mutableResult = [payload mutableCopy];
            mutableResult[@"success"] = @YES;
            mutableResult[@"source"] = source;
            result = [mutableResult copy];
            
            NSLog(@"[StarCoreTweak] 📸 Screenshot captured via %@, base64 length: %lu", source, (unsigned long)[payload[@"data"] length]);
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"Screenshot exception: %@", e]};
        }
        dispatch_semaphore_signal(sema);
    });
    
    // ★ 超时等待8秒
    long waitResult = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    if (waitResult != 0) {
        NSLog(@"[StarCoreTweak] ⚠️ Screenshot timed out after 8s");
        return @{@"success": @NO, @"error": @"Screenshot timed out (8s)"};
    }
    
    return result ?: @{@"success": @NO, @"error": @"Screenshot returned nil"};
}

// ==================== v8.4: 屏幕状态 ====================

// ★ v8.4: 辅助函数 - 从类和选择器读取BOOL
static bool readBoolFromSelector(const char *className, SEL selector, BOOL *outValue) {
    Class cls = objc_getClass(className);
    if (!cls || !selector || ![cls respondsToSelector:selector]) return false;
    @try {
        // 先尝试类方法获取实例
        id target = ((id (*)(id, SEL))objc_msgSend)((id)cls, selector);
        if (target && [target respondsToSelector:selector]) {
            // 如果选择器在实例上
            BOOL value = ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
            if (outValue) *outValue = value;
            return true;
        }
    } @catch (NSException *e) {}
    return false;
}

// ★ v8.4: 读取BOOL选择器值
static BOOL readBoolSelector(id target, SEL selector) {
    if (!target || !selector || ![target respondsToSelector:selector]) return NO;
    @try {
        return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector);
    } @catch (NSException *e) { return NO; }
}

// ★ v8.4: 读取NSInteger选择器值
static BOOL readIntegerSelector(id target, SEL selector, NSInteger *outValue) {
    if (!target || !selector || ![target respondsToSelector:selector]) return NO;
    @try {
        NSInteger value = ((NSInteger (*)(id, SEL))objc_msgSend)(target, selector);
        if (outValue) *outValue = value;
        return YES;
    } @catch (NSException *e) { return NO; }
}

// ★ v8.4: 从类名+选择器获取单例对象
static id getObjectFromClassSelector(const char *className, SEL selector) {
    Class cls = objc_getClass(className);
    if (!cls || !selector || ![cls respondsToSelector:selector]) return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)((id)cls, selector);
    } @catch (NSException *e) { return nil; }
}

// ★ v8.4: 获取屏幕交互状态（必须在主线程）
static NSDictionary *deviceInteractionStateOnMainThread() {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    
    // 获取SpringBoard私有类实例
    id springBoard = getObjectFromClassSelector("SpringBoard", @selector(sharedApplication));
    id lockScreenManager = getObjectFromClassSelector("SBLockScreenManager", @selector(sharedInstance));
    id lockStateAggregator = getObjectFromClassSelector("SBLockStateAggregator", @selector(sharedInstance));
    id backlightController = getObjectFromClassSelector("SBBacklightController", @selector(sharedInstance));
    
    // 锁屏状态
    BOOL locked = NO;
    BOOL lockedKnown = NO;
    
    NSArray<NSString *> *lockSelectors = @[@"isUILocked", @"isLocked", @"isSecurelyLocked", @"isDeviceLocked"];
    for (NSString *selectorName in lockSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        BOOL value = NO;
        if (lockScreenManager && [lockScreenManager respondsToSelector:selector]) {
            value = readBoolSelector(lockScreenManager, selector);
            locked = locked || value;
            lockedKnown = YES;
        } else if (springBoard && [springBoard respondsToSelector:selector]) {
            value = readBoolSelector(springBoard, selector);
            locked = locked || value;
            lockedKnown = YES;
        }
    }
    
    // 锁屏可见状态
    BOOL lockScreenVisible = NO;
    BOOL lockScreenVisibleKnown = NO;
    NSArray<NSString *> *visibleSelectors = @[@"isLockScreenVisible", @"isLockScreenActive", @"isShowingLockScreen", @"lockScreenVisible", @"lockScreenActive"];
    for (NSString *selectorName in visibleSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        BOOL value = NO;
        if (lockScreenManager && [lockScreenManager respondsToSelector:selector]) {
            value = readBoolSelector(lockScreenManager, selector);
            lockScreenVisible = lockScreenVisible || value;
            lockScreenVisibleKnown = YES;
        } else if (springBoard && [springBoard respondsToSelector:selector]) {
            value = readBoolSelector(springBoard, selector);
            lockScreenVisible = lockScreenVisible || value;
            lockScreenVisibleKnown = YES;
        }
    }
    
    // lockState
    NSInteger lockState = 0;
    if (readIntegerSelector(lockStateAggregator, @selector(lockState), &lockState)) {
        state[@"raw_lock_state"] = @(lockState);
        if (!lockedKnown && lockState != 0) { locked = YES; lockedKnown = YES; }
    }
    
    // protectedDataAvailable
    __block BOOL protectedDataAvailable = NO;
    runOnMainThreadSync(^{
        protectedDataAvailable = [UIApplication sharedApplication].protectedDataAvailable;
    });
    state[@"protected_data_available"] = @(protectedDataAvailable);
    if (!protectedDataAvailable) { locked = YES; lockedKnown = YES; }
    
    // 屏幕亮灭
    BOOL screenOn = NO;
    BOOL screenOnKnown = NO;
    NSArray<NSString *> *screenOnSelectors = @[@"screenIsOn", @"isScreenOn", @"displayIsOn", @"isDisplayOn", @"isBacklightOn"];
    for (NSString *selectorName in screenOnSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        BOOL value = NO;
        if (backlightController && [backlightController respondsToSelector:selector]) {
            value = readBoolSelector(backlightController, selector);
            screenOn = value;
            screenOnKnown = YES;
            break;
        }
    }
    
    state[@"locked"] = lockedKnown ? @(locked) : [NSNull null];
    state[@"locked_known"] = @(lockedKnown);
    if (lockScreenVisibleKnown) state[@"lock_screen_visible"] = @(lockScreenVisible);
    state[@"screen_on"] = screenOnKnown ? @(screenOn) : [NSNull null];
    state[@"screen_on_known"] = @(screenOnKnown);
    
    return [state copy];
}

// ★ v8.4: getScreenInfo主函数
static NSDictionary *doGetScreenInfo() {
    __block NSDictionary *result = nil;
    
    runOnMainThreadSync(^{
        @try {
            UIScreen *screen = [UIScreen mainScreen];
            CGRect bounds = screen.bounds;
            CGFloat scale = screen.scale;
            
            // 方向
            NSString *orientationStr = @"unknown";
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            
            // iOS 14兼容：使用statusBarOrientation
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            orientation = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
            
            switch (orientation) {
                case UIInterfaceOrientationPortrait:           orientationStr = @"portrait"; break;
                case UIInterfaceOrientationPortraitUpsideDown: orientationStr = @"portrait_upside_down"; break;
                case UIInterfaceOrientationLandscapeLeft:      orientationStr = @"landscape_left"; break;
                case UIInterfaceOrientationLandscapeRight:     orientationStr = @"landscape_right"; break;
                default: break;
            }
            
            NSMutableDictionary *info = [@{
                @"width": @(bounds.size.width),
                @"height": @(bounds.size.height),
                @"scale": @(scale),
                @"pixel_width": @(bounds.size.width * scale),
                @"pixel_height": @(bounds.size.height * scale),
                @"orientation": orientationStr,
            } mutableCopy];
            
            // 添加交互状态
            NSDictionary *interactionState = deviceInteractionStateOnMainThread();
            if (interactionState.count > 0) {
                info[@"device_state"] = interactionState;
                id locked = interactionState[@"locked"];
                id screenOn = interactionState[@"screen_on"];
                if (locked && ![locked isEqual:[NSNull null]]) info[@"locked"] = locked;
                if (screenOn && ![screenOn isEqual:[NSNull null]]) info[@"screen_on"] = screenOn;
            }
            
            result = [info copy];
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"getScreenInfo exception: %@", e]};
        }
    });
    
    return result ?: @{@"success": @NO, @"error": @"getScreenInfo returned nil"};
}

// ==================== TCP服务器 ====================

@interface StarCoreTCPServer : NSObject
- (void)start;
- (void)stop;
@end
static StarCoreTCPServer *_server = nil;

@implementation StarCoreTCPServer { NSInteger _sock; NSMutableArray<NSNumber *> *_fds; }
- (instancetype)init { self = [super init]; if (self) { _sock = -1; _fds = [NSMutableArray new]; g_globalsLock = [[NSLock alloc] init]; } return self; }
- (void)start {
    _sock = socket(AF_INET, SOCK_STREAM, 0); if (_sock < 0) return;
    int y=1; setsockopt((int)_sock, SOL_SOCKET, SO_REUSEADDR, &y, sizeof(y));
    struct sockaddr_in a; memset(&a,0,sizeof(a)); a.sin_len=sizeof(a); a.sin_family=AF_INET; a.sin_port=htons(6000); a.sin_addr.s_addr=inet_addr("127.0.0.1");
    if (bind((int)_sock,(struct sockaddr*)&a,sizeof(a))<0||listen((int)_sock,5)<0) { close((int)_sock); _sock=-1; return; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{[self acceptLoop];});
    NSLog(@"[StarCoreTweak] TCP :6000 v8.4 (ios-mcp功能移植)");
}
- (void)acceptLoop {
    while(_sock>=0) { struct sockaddr_in ca; socklen_t cl=sizeof(ca); int fd=accept((int)_sock,(struct sockaddr*)&ca,&cl); if(fd<0) continue;
        @synchronized(_fds){[_fds addObject:@(fd)];} dispatch_async(dispatch_get_global_queue(0,0),^{[self handleClient:fd];}); }
}
- (void)handleClient:(int)fd {
    NSMutableData *buf=[NSMutableData new]; uint8_t b[4096];
    const NSUInteger kMaxBufSize = 2097152; // ★ v8.4: 2MB上限（截图base64可能很大）
    while(YES) { ssize_t l=read(fd,b,sizeof(b)); if(l<=0) break; [buf appendBytes:b length:l];
        if (buf.length > kMaxBufSize) {
            NSLog(@"[StarCoreTweak] ⚠️ TCP缓冲区超过2MB，丢弃");
            [buf setLength:0]; break;
        }
        while(buf.length>0) { const uint8_t *bs=(const uint8_t*)buf.bytes; NSInteger nl=-1;
            for(NSInteger i=0;i<buf.length;i++){if(bs[i]=='\n'){nl=i;break;}} if(nl<0) break;
            NSData *ld=[buf subdataWithRange:NSMakeRange(0, nl)]; [buf replaceBytesInRange:NSMakeRange(0, nl+1) withBytes:"" length:0];
            NSString *js=[[NSString alloc]initWithData:ld encoding:NSUTF8StringEncoding];
            if(js){NSDictionary *r=[self processMessage:js];if(r)[self sendResponse:r toFd:fd];} } }
    @synchronized(_fds){[_fds removeObject:@(fd)];} close(fd);
}
- (NSDictionary *)processMessage:(NSString *)jsonStr {
    NSData *d=[jsonStr dataUsingEncoding:NSUTF8StringEncoding]; if(!d) return @{@"success":@NO,@"error":@"invalid JSON"};
    NSError *e; NSDictionary *req=[NSJSONSerialization JSONObjectWithData:d options:0 error:&e];
    if(!req||![req isKindOfClass:[NSDictionary class]]) return @{@"success":@NO,@"error":@"invalid JSON"};
    NSString *action=req[@"action"]; NSNumber *mid=req[@"id"]?:@0; NSMutableDictionary *resp=[@{@"id":mid} mutableCopy];
    
    if([action isEqualToString:@"ping"]) { resp[@"success"]=@YES; resp[@"message"]=@"pong"; resp[@"version"]=@"8.5"; }
    
    // ★ v5.1: tap - 优先使用ios-mcp方案，再虚拟设备，最后旧方案
    else if([action isEqualToString:@"tap"]) {
        float x=[req[@"x"] floatValue],y=[req[@"y"] floatValue];
        CGRect b=getScreenBoundsSafe();
        CGFloat screenW = b.size.width, screenH = b.size.height;
        
        // 像素坐标转归一化
        float normX = x, normY = y;
        if (x > 1.0f || y > 1.0f) {
            normX = x / screenW; normY = y / screenH;
            if (normX > 1) normX = 1; if (normY > 1) normY = 1;
        }
        
        // ★ v8.4: 优先使用ios-mcp方案（IOHIDEventCreateDigitizerFingerEvent）
        if (IOHIDEventCreateDigitizerFingerEventFunc) {
            iosmcpTap(normX, normY);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDEventCreateDigitizerFingerEvent";
        } else if (g_virtualDeviceReady) {
            virtualTap(normX, normY);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateTap_old(normX, normY);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    // ★ v5.1: swipe
    else if([action isEqualToString:@"swipe"]) {
        float fX=[req[@"fromX"] floatValue], fY=[req[@"fromY"] floatValue];
        float tX=[req[@"toX"] floatValue], tY=[req[@"toY"] floatValue];
        float dur=[req[@"duration"] floatValue] ?: 0.5f;
        
        CGRect b=getScreenBoundsSafe();
        CGFloat screenW = b.size.width, screenH = b.size.height;
        float normFX = fX, normFY = fY, normTX = tX, normTY = tY;
        if (fX > 1.0f || fY > 1.0f) { normFX = fX/screenW; normFY = fY/screenH; }
        if (tX > 1.0f || tY > 1.0f) { normTX = tX/screenW; normTY = tY/screenH; }
        if (normFX > 1) normFX = 1; if (normFY > 1) normFY = 1;
        if (normTX > 1) normTX = 1; if (normTY > 1) normTY = 1;
        
        if (IOHIDEventCreateDigitizerFingerEventFunc) {
            iosmcpSwipe(normFX, normFY, normTX, normTY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDEventCreateDigitizerFingerEvent";
        } else if (g_virtualDeviceReady) {
            virtualSwipe(normFX, normFY, normTX, normTY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateSwipe_old(normFX, normFY, normTX, normTY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    // ★ v5.1: longPress
    else if([action isEqualToString:@"longPress"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        float dur=[req[@"duration"] floatValue] ?: 1.0f;
        
        CGRect b=getScreenBoundsSafe();
        float normX = x, normY = y;
        if (x > 1.0f || y > 1.0f) { normX = x/b.size.width; normY = y/b.size.height; }
        if (normX > 1) normX = 1; if (normY > 1) normY = 1;
        
        if (g_virtualDeviceReady) {
            virtualLongPress(normX, normY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateLongPress_old(normX, normY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    else if([action isEqualToString:@"pressHome"]) { simulateHomeButton(); resp[@"success"]=@YES; }
    
    // ★ v8.4: pressPower
    else if([action isEqualToString:@"pressPower"]) {
        float dur = [req[@"duration"] floatValue] ?: 100.0f;
        sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Power, dur);
        resp[@"success"]=@YES; resp[@"usage"]=@(kHIDUsage_Csmr_Power);
    }
    
    // ★ v8.4: pressVolumeUp
    else if([action isEqualToString:@"pressVolumeUp"]) {
        sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_VolumeIncrement, 100.0f);
        resp[@"success"]=@YES; resp[@"usage"]=@(kHIDUsage_Csmr_VolumeIncrement);
    }
    
    // ★ v8.4: pressVolumeDown
    else if([action isEqualToString:@"pressVolumeDown"]) {
        sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_VolumeDecrement, 100.0f);
        resp[@"success"]=@YES; resp[@"usage"]=@(kHIDUsage_Csmr_VolumeDecrement);
    }
    
    // ★ v5.2: keyPress
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"key required"; }
        else if (!g_virtualKeyboardReady) { resp[@"success"]=@NO; resp[@"error"]=@"virtual keyboard not ready"; }
        else {
            uint32_t page = 0, usage = 0;
            if (keyToUsage(key, &page, &usage)) { handleKeyPressViaVirtualDevice(page, usage); resp[@"success"]=@YES; }
            else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"unknown key: %@", key]; }
        }
    }
    
    // ★ v5.2: textInput - ASCII only via virtual keyboard
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else if (!g_virtualKeyboardReady) { resp[@"success"]=@NO; resp[@"error"]=@"virtual keyboard not ready"; }
        else { handleTextInput(text); resp[@"success"]=@YES; resp[@"method"]=@"virtual_keyboard_ASCII"; }
    }
    
    // ★ v8.4: inputText - Unicode文字输入（支持中文！）
    else if([action isEqualToString:@"inputText"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else {
            NSDictionary *inputResult = doInputText(text);
            [resp addEntriesFromDictionary:inputResult];
        }
    }
    
    // ★ v8.4: typeText - 逐字输入
    else if([action isEqualToString:@"typeText"]) {
        NSString *text = req[@"text"];
        float delayMs = [req[@"delayMs"] floatValue] ?: 50.0f;
        if (!text || text.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else {
            NSDictionary *inputResult = doTypeText(text, delayMs);
            [resp addEntriesFromDictionary:inputResult];
        }
    }
    
    // ★ v8.5: screenshot - 截图
    else if([action isEqualToString:@"screenshot"]) {
        NSDictionary *screenshotResult = doScreenshot();
        [resp addEntriesFromDictionary:screenshotResult];
    }
    
    // ★ v8.4: getScreenInfo - 屏幕状态
    else if([action isEqualToString:@"getScreenInfo"]) {
        NSDictionary *screenInfo = doGetScreenInfo();
        resp[@"success"]=@YES;
        [resp addEntriesFromDictionary:screenInfo];
    }
    
    // ★ v8.5: shell - 改用popen()（兼容Dopamine越狱，posix_spawn在SpringBoard不可靠）
    else if([action isEqualToString:@"shell"]) {
        NSString *cmd = req[@"command"];
        if (!cmd || cmd.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"command required"; }
        else {
            NSString *fullCmd = [NSString stringWithFormat:@"PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin HOME=/var/mobile %@ 2>&1", cmd];
            FILE *fp = popen([fullCmd UTF8String], "r");
            if (!fp) { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"popen failed: %s", strerror(errno)]; }
            else {
                NSMutableData *outData = [NSMutableData data]; char buf2[4096];
                while (fgets(buf2, sizeof(buf2), fp)) { [outData appendBytes:buf2 length:strlen(buf2)]; }
                int exitCode = pclose(fp);
                NSString *output = @"";
                if (outData.length > 65536) { [outData replaceBytesInRange:NSMakeRange(65536, outData.length - 65536) withBytes:"" length:0]; output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding]; output = [output stringByAppendingString:@"\n... [truncated]"]; }
                else { output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @""; }
                resp[@"success"] = @(exitCode == 0);
                resp[@"output"] = output;
                resp[@"exitCode"] = @(exitCode);
            }
        }
    }
    
    // ★ v8.5: readFile - Tweak直接读任意路径（绕过沙盒）
    else if([action isEqualToString:@"readFile"]) {
        NSString *path = req[@"path"];
        if (!path || path.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else {
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data) {
                NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (content) {
                    if (content.length > 10000) content = [[content substringToIndex:10000] stringByAppendingString:@"\n... [truncated]"];
                    resp[@"success"] = @YES;
                    resp[@"content"] = content;
                    resp[@"size"] = @(data.length);
                } else {
                    resp[@"success"] = @YES;
                    resp[@"content"] = [data base64EncodedStringWithOptions:0];
                    resp[@"size"] = @(data.length);
                    resp[@"binary"] = @YES;
                }
            } else {
                resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"read failed: %s", strerror(errno)];
            }
        }
    }
    
    // ★ v8.5: writeFile - Tweak直接写任意路径（绕过沙盒）
    else if([action isEqualToString:@"writeFile"]) {
        NSString *path = req[@"path"];
        NSString *wcontent = req[@"content"];
        if (!path || path.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else if (!wcontent || wcontent.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"content required"; }
        else {
            // 确保目录存在
            NSString *dir = [path stringByDeletingLastPathComponent];
            NSFileManager *fm = [NSFileManager defaultManager];
            if (![fm fileExistsAtPath:dir]) { [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]; }
            NSError *err = nil;
            BOOL ok = [wcontent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
            if (ok) {
                // 校验
                NSData *readBack = [NSData dataWithContentsOfFile:path];
                resp[@"success"] = @YES;
                resp[@"size"] = @(readBack.length);
                resp[@"path"] = path;
            } else {
                resp[@"success"] = @NO; resp[@"error"]=[NSString stringWithFormat:@"write failed: %@", err.localizedDescription];
            }
        }
    }
    
    // ★ v8.5: appendFile - Tweak追加写任意路径
    else if([action isEqualToString:@"appendFile"]) {
        NSString *path = req[@"path"];
        NSString *acontent = req[@"appendContent"] ?: req[@"content"];
        if (!path || path.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else if (!acontent || acontent.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"content required"; }
        else {
            NSString *existing = @"";
            NSData *existingData = [NSData dataWithContentsOfFile:path];
            if (existingData) { existing = [[NSString alloc] initWithData:existingData encoding:NSUTF8StringEncoding] ?: @""; }
            NSString *newContent = [existing stringByAppendingString:@"\n"];
            newContent = [newContent stringByAppendingString:acontent];
            NSError *err = nil;
            BOOL ok = [newContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
            if (ok) { resp[@"success"] = @YES; resp[@"size"] = @(newContent.length); resp[@"path"] = path; }
            else { resp[@"success"] = @NO; resp[@"error"]=[NSString stringWithFormat:@"append failed: %@", err.localizedDescription]; }
        }
    }
    
    // ★ v8.5: listFiles - Tweak列任意目录（绕过沙盒）
    else if([action isEqualToString:@"listFiles"]) {
        NSString *path = req[@"path"];
        if (!path || path.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else {
            NSFileManager *fm = [NSFileManager defaultManager];
            NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
            NSMutableArray *items = [NSMutableArray array];
            NSString *file;
            int count = 0;
            while ((file = [enumerator nextObject]) && count < 100) {
                NSString *fullPath = [path stringByAppendingPathComponent:file];
                BOOL isDir = NO;
                [fm fileExistsAtPath:fullPath isDirectory:&isDir];
                NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
                [items addObject:@{
                    @"name": file,
                    @"path": fullPath,
                    @"isDirectory": @(isDir),
                    @"size": attrs[@"NSFileSize"] ?: @0
                }];
                count++;
            }
            resp[@"success"] = @YES;
            resp[@"items"] = items;
            resp[@"count"] = @(items.count);
        }
    }
    
    // ★ v8.5: openApp - 三级降级策略（参考ios-mcp验证过的方案）
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) { resp[@"success"]=@NO; resp[@"error"]=@"bundleId required"; }
        else {
            __block BOOL ok = NO;
            __block NSString *errMsg = @"all methods failed";
            __block NSString *method = @"none";
            runOnMainThreadSync(^{
                // 策略1: SBUIController activateApplication（SpringBoard内部，最可靠）
                Class SBAppCtrl = objc_getClass("SBApplicationController");
                if (SBAppCtrl) {
                    id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
                    if (appCtrl) {
                        id sbApp = [appCtrl performSelector:@selector(applicationWithBundleIdentifier:) withObject:bid];
                        if (sbApp) {
                            Class SBUICtrlClass = objc_getClass("SBUIController");
                            if (SBUICtrlClass) {
                                id ctrl = [SBUICtrlClass performSelector:@selector(sharedInstance)];
                                SEL activateSel = @selector(activateApplication:);
                                if ([ctrl respondsToSelector:activateSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    [ctrl performSelector:activateSel withObject:sbApp];
#pragma clang diagnostic pop
                                    ok = YES;
                                    method = @"SBUIController";
                                }
                            }
                        } else {
                            errMsg = @"app not installed or not found by SBApplicationController";
                        }
                    }
                }
                
                // 策略2: FBSSystemService openApplication（FrontBoard服务）
                if (!ok) {
                    Class fbsClass = objc_getClass("FBSSystemService");
                    if (fbsClass) {
                        id fbs = [fbsClass performSelector:@selector(sharedService)];
                        SEL openSel = @selector(openApplication:options:withResult:);
                        if (fbs && [fbs respondsToSelector:openSel]) {
                            ((void(*)(id,SEL,NSString*,id,void(^)(void)))objc_msgSend)(fbs, openSel, bid, nil, nil);
                            ok = YES;
                            method = @"FBSSystemService";
                        }
                    }
                }
                
                // 策略3: LSApplicationWorkspace（降级方案）
                if (!ok) {
                    Class wc = objc_getClass("LSApplicationWorkspace");
                    if (wc) {
                        id ws = [wc performSelector:@selector(defaultWorkspace)];
                        if (ws) {
                            ok = (BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), bid);
                            if (ok) {
                                method = @"LSApplicationWorkspace";
                            } else {
                                errMsg = @"openApplication returned NO";
                            }
                        } else errMsg = @"defaultWorkspace returned nil";
                    }
                }
            });
            resp[@"success"]=@(ok); 
            if (ok) resp[@"method"]=method;
            if (!ok) resp[@"error"]=errMsg;
        }
    }
    
        // ★ v5.7: getScreenSize
    else if([action isEqualToString:@"getScreenSize"]) {
        CGRect b = getScreenBoundsSafe();
        CGFloat scale = getScreenScaleSafe();
        resp[@"success"]=@YES; resp[@"width"]=@(b.size.width); resp[@"height"]=@(b.size.height); resp[@"scale"]=@(scale);
    }
    
    // ★ v5.4: initDevice
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady ? @"OK" : @"FAILED";
        resp[@"virtualKeyboardDevice"]=g_virtualKeyboardReady ? @"OK" : @"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
        if (!g_virtualDeviceReady || !g_virtualKeyboardReady) resp[@"hint"]=@"IOHIDUserDeviceCreate返回NULL通常因为缺少HID entitlements";
    }
    
    // ★ v5.7: diagnose
    else if([action isEqualToString:@"diagnose"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        NSString *ctxSrc = SAFE_GET_GLOBAL(g_contextSource);
        NSString *frontApp = SAFE_GET_GLOBAL(g_frontmostApp);
        
        resp[@"success"]=@YES;
        resp[@"diagnostics"]=@{
            @"version": @"8.5",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"quartzCoreHandle": g_quartzCoreHandle?@"OK":@"NULL",
            @"BKHIDSystemInterface": (bksSharedInstance() != nil) ? @"OK":@"NULL",
            @"createDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"createDigitizerFingerEvent": IOHIDEventCreateDigitizerFingerEventFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"createUnicodeEvent": IOHIDEventCreateUnicodeEventFunc?@"OK":@"NULL",
            @"BKSHIDEventSendToProcess": BKSHIDEventSendToProcessFunc?@"OK":@"NULL",
            @"CARenderServerCaptureDisplay": _CARenderServerCaptureDisplayFunc?@"OK":@"NULL",
            @"_UICreateScreenUIImage": _UICreateScreenUIImageFunc?@"OK":@"NULL",
            @"UICreateCGImageFromIOSurface": _UICreateCGImageFromIOSurfaceFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualKeyboardDevice": g_virtualKeyboardReady?@"OK":@"FAILED",
            @"frontmostApp": frontApp ?: @"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": ctxSrc ?: @"none",
            @"dispatchPath": (bksSharedInstance() != nil) ? @"BKHIDSystemInterface":@"IOHIDEventSystemClient(fallback)",
        };
    }
    
    // ★ v5.7: validate
    else if([action isEqualToString:@"validate"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        bool canInjectTouch = (BKSHIDEventSetDigitizerInfoFunc != NULL) && (frontmostCID != 0 || springCID != 0);
        
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"frameworkQuartzCore": g_quartzCoreHandle?@YES:@NO,
            @"BKHIDSystemInterfaceAvailable": (bksSharedInstance() != nil) ? @YES:@NO,
            @"functionIOHIDEventCreateDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@YES:@NO,
            @"functionIOHIDEventCreateDigitizerFingerEvent": IOHIDEventCreateDigitizerFingerEventFunc?@YES:@NO,
            @"functionIOHIDEventCreateUnicodeEvent": IOHIDEventCreateUnicodeEventFunc?@YES:@NO,
            @"functionBKSHIDEventSendToProcess": BKSHIDEventSendToProcessFunc?@YES:@NO,
            @"functionCARenderServerCaptureDisplay": _CARenderServerCaptureDisplayFunc?@YES:@NO,
            @"function_UICreateScreenUIImage": _UICreateScreenUIImageFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
            @"canInjectTouchToApp": @((bksSharedInstance() != nil)),
            @"canInputUnicode": @(IOHIDEventCreateUnicodeEventFunc != NULL),
            @"canScreenshot": @(_CARenderServerCaptureDisplayFunc != NULL || _UICreateScreenUIImageFunc != NULL),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
            @"virtualKeyboardReady": @(g_virtualKeyboardReady),
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
        };
    }
    
    // ★ v8.4: setClipboard
    else if([action isEqualToString:@"setClipboard"]) {
        NSString *text = req[@"text"];
        if (!text) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else {
            runOnMainThreadSync(^{ [UIPasteboard generalPasteboard].string = text; });
            resp[@"success"]=@YES;
        }
    }
    
    // ★ v8.4: getClipboard
    else if([action isEqualToString:@"getClipboard"]) {
        __block NSString *text = nil;
        runOnMainThreadSync(^{ text = [UIPasteboard generalPasteboard].string; });
        resp[@"success"]=@YES;
        resp[@"text"]=text ?: @"";
    }
    
    else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"unknown: %@",action]; }
    return resp;
}
- (void)sendResponse:(NSDictionary *)r toFd:(int)fd {
    NSError *e; NSData *d=[NSJSONSerialization dataWithJSONObject:r options:0 error:&e]; if(!d) return;
    NSMutableData *sd=[d mutableCopy]; uint8_t nl='\n'; [sd appendBytes:&nl length:1];
    const uint8_t *b=(const uint8_t*)sd.bytes; size_t tl=sd.length,s=0;
    while(s<tl){ssize_t n=write(fd,b+s,tl-s);if(n<=0)break;s+=n;}
}
- (void)stop { 
    if(_sock>=0){close((int)_sock);_sock=-1;} 
    @synchronized(_fds){
        for(NSNumber*f in _fds)close([f intValue]);
        [_fds removeAllObjects];
    } 
}
@end

// ==================== SpringBoard Hook ====================

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动 v8.4 (ios-mcp功能移植)");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    NSLog(@"[StarCoreTweak] v8.5: screenshot, inputText, pressPower, pressVolume, getScreenInfo, ios-mcp触摸");
}
%end

%ctor { %init; NSLog(@"[StarCoreTweak] v8.4 loading... (ios-mcp功能移植)"); }
%dtor { [_server stop]; }
