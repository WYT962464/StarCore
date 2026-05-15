/**
 * StarCoreTweak.xm v8.2 - sendEvent Hook获取真实senderID
 * 
 * v8.2 更新清单：
 * 1. ✨ 新增sendEvent Hook机制获取真实senderID
 *    - Hook -[UIApplication sendEvent:] 拦截SpringBoard已处理的触摸事件
 *    - 从UIEvent中提取IOHIDEvent的senderID（通过_hidEvent私有API）
 *    - 获取到真实senderID后自动停止拦截（性能无影响）
 *    - 不注册新RunLoop回调，不创建新IOHIDEventSystemClient
 * 2. 新增capture_senderid命令（TCP 6000端口）
 *    - 主动开启捕获模式，提示用户触摸屏幕
 * 3. initSenderID()中自动开启捕获（文件无缓存时）
 * 4. 更新diagnose输出，添加senderIDCapturing字段
 * 5. 保留set_senderid命令不变
 * 
 * v8.0 修复清单（继承）：
 * - 移除IOHIDEventSystemClient回调注册机制（导致SpringBoard崩溃的根因）
 * - 保留从文件读取senderID的逻辑
 * - 保留所有触摸注入功能（tap/swipe等）
 * - 保留TCP server 6000端口的完整功能
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

// ==================== IOKit类型定义（避免模块冲突）====================
#define kIOReturnSuccess 0
typedef int IOReturn;
typedef UInt32 IOOptionBits;

// ==================== 私有类型 ====================
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDUserDevice *IOHIDUserDeviceRef;
typedef struct __IOHIDService *IOHIDServiceRef;

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

// UIWindow私有方法
@interface UIWindow (StarCorePrivate)
@property (nonatomic, readonly) uint32_t _contextId;
@end

@interface UIApplication (StarCorePrivate)
- (void)_enqueueHIDEvent:(IOHIDEventRef)arg1;
@end

// ==================== 函数指针 ====================
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;
static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static uint64_t (*IOHIDEventGetSenderIDFunc)(IOHIDEventRef) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;
static void (*BKSHIDEventSetDigitizerInfoFunc)(IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float) = NULL;

// IOHIDEventSystemClient回调相关函数已移除（v8.0崩溃修复）

// IOHIDUserDevice函数
static IOHIDUserDeviceRef (*IOHIDUserDeviceCreateFunc)(CFAllocatorRef, CFDictionaryRef, IOOptionBits) = NULL;
static IOReturn (*IOHIDUserDeviceHandleReportFunc)(IOHIDUserDeviceRef, const uint8_t *, CFIndex) = NULL;

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL;

// BKHIDSystemInterface runtime resolution
static Class _bksClass = Nil;
static id bksSharedInstance(void) {
    if (!_bksClass) _bksClass = NSClassFromString(@"BKHIDSystemInterface");
    if (!_bksClass) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(_bksClass, @selector(sharedInstance));
}
static void bksInjectHIDEvent(id bks, void *event) {
    ((void (*)(id, SEL, void*))objc_msgSend)(bks, @selector(injectHIDEvent:), event);
}

// ==================== senderID自动获取机制 ====================
static uint64_t g_realSenderID = 0;
static BOOL g_senderIDCapturing = NO;  // v8.2: 是否正在通过sendEvent hook捕获senderID
static NSString *g_senderIDFilePath = @"/var/mobile/Library/StarCore/senderid.plist";

// senderIDCallback已移除（v8.0崩溃修复：回调注册导致SpringBoard崩溃）

// 初始化：从文件读取senderID，不存在则开启sendEvent捕获
static void initSenderID() {
    // 尝试从文件读取
    NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:g_senderIDFilePath];
    if (data) {
        NSTimeInterval bootTime = [[NSDate date] timeIntervalSince1970] - [NSProcessInfo processInfo].systemUptime;
        NSTimeInterval savedBootTime = [data[@"bootTime"] doubleValue];
        // 同一次启动（3秒内差异）才使用缓存的senderID
        if (fabs(bootTime - savedBootTime) <= 3) {
            g_realSenderID = [data[@"senderID"] unsignedLongLongValue];
            if (g_realSenderID != 0) {
                NSLog(@"[StarCoreTweak] ✅ 从文件读取senderID: 0x%llX", g_realSenderID);
                return;
            }
        } else {
            NSLog(@"[StarCoreTweak] senderID文件已过期（设备已重启），将开启sendEvent捕获");
        }
    } else {
        NSLog(@"[StarCoreTweak] senderID文件不存在，将开启sendEvent捕获");
    }
    
    // v8.2: 不再使用硬编码fallback，而是开启sendEvent hook捕获真实senderID
    // 当用户触摸屏幕时，hook会从真实的触摸事件中提取senderID
    g_senderIDCapturing = YES;
    NSLog(@"[StarCoreTweak] sendEvent hook已启用，等待真实触摸获取senderID... (也可通过set_senderid命令手动设置)");
}

// 获取当前应使用的senderID（真实优先，fallback硬编码）
static uint64_t getCurrentSenderID() {
    return g_realSenderID != 0 ? g_realSenderID : kIOHIDEventDigitizerSenderID;
}

// 全局变量
static uint32_t g_springBoardContextID = 2939785827;

// 线程安全保护
static NSString *g_contextSource = @"none";
static NSString *g_frontmostApp = @"";
static NSLock *g_globalsLock = nil;

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

// 虚拟触摸设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";

// 虚拟键盘设备
static IOHIDUserDeviceRef g_virtualKeyboardDevice = NULL;
static bool g_virtualKeyboardReady = false;

// TCP端口配置
static const uint16_t kServerPort = 6000;

// ==================== HID Report Descriptors ====================

// 多点触摸 HID Report Descriptor (字节对齐版本)
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
    0x81, 0x03,        //     Input (Constant) padding
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
    0x75, 0x08,        //     Report Size (8)
    0x95, 0x01,        //     Report Count (1)
    0x15, 0x00,        //     Logical Minimum (0)
    0x25, 0x0A,        //     Logical Maximum (10)
    0x81, 0x02,        //   Input (Data, Variable, Absolute)
    0xC0               // End Collection
};

// 键盘 HID Report Descriptor
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

// 主线程同步执行
static void runOnMainThreadSync(void (^block)(void)) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static CGRect getScreenBoundsSafe(void) {
    __block CGRect bounds = CGRectZero;
    runOnMainThreadSync(^{
        bounds = [UIScreen mainScreen].bounds;
    });
    return bounds;
}

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
    
    return (g_iokitHandle != NULL);
}

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    forceLoadFrameworks();
    
    void *handles[] = { g_iokitHandle, g_bbsHandle, RTLD_DEFAULT, NULL };
    
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
    LOAD_SYM(IOHIDEventGetSenderIDFunc, "IOHIDEventGetSenderID");
    LOAD_SYM(IOHIDEventAppendEventFunc, "IOHIDEventAppendEvent");
    LOAD_SYM(IOHIDEventSystemClientCreateFunc, "IOHIDEventSystemClientCreate");
    LOAD_SYM(IOHIDEventSystemClientDispatchEventFunc, "IOHIDEventSystemClientDispatchEvent");
    LOAD_SYM(BKSHIDEventSetDigitizerInfoFunc, "BKSHIDEventSetDigitizerInfo");
    LOAD_SYM(IOHIDUserDeviceCreateFunc, "IOHIDUserDeviceCreate");
    LOAD_SYM(IOHIDUserDeviceHandleReportFunc, "IOHIDUserDeviceHandleReport");
    
    
    #undef LOAD_SYM
    
    if (!IOHIDEventCreateDigitizerEventFunc) { NSLog(@"[StarCoreTweak] ❌ 核心函数缺失"); return false; }
    
    // 验证BKHIDSystemInterface
    id bks = bksSharedInstance();
    NSLog(@"[StarCoreTweak] BKHIDSystemInterface = %@", bks ? @"✅ OK" : @"❌ NULL (仅影响旧路径)");
    
    // 验证senderID关键函数
    NSLog(@"[StarCoreTweak] IOHIDEventGetSenderID = %@", IOHIDEventGetSenderIDFunc ? @"✅ OK" : @"❌ NULL");
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ v8.2 函数加载成功");
    return true;
}

// ==================== Context ID获取 ====================

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
                if (cid_val != 0) { SAFE_SET_GLOBAL(g_contextSource, @"keyWindow"); cid = cid_val; }
            }
        } @catch (NSException *e) {}
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
    if (cid != 0) { SAFE_SET_GLOBAL(g_contextSource, @"CAWindowServer"); return cid; }
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

// ==================== HID事件派发 ====================

static void dispatchHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    
    // ★ v7.0: 核心修复 - 先尝试BKHIDSystemInterface
    @try {
        id bks = bksSharedInstance();
        if (bks) {
            bksInjectHIDEvent(bks, event);
            NSLog(@"[StarCoreTweak] BKS injectHIDEvent ✅ (senderID=0x%llX)", getCurrentSenderID());
            return;
        }
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] BKHIDSystemInterface injectHIDEvent failed: %@", e);
    }
    
    // ★ v7.0: IOHIDEventSystemClient + 正确senderID = 也能跨App路由！
    // 这是ZXTouch的方案：有正确senderID后，IOHIDEventSystemClientDispatchEvent也能路由到前台App
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        });
        if (client) {
            IOHIDEventSystemClientDispatchEventFunc(client, event);
            NSLog(@"[StarCoreTweak] IOHIDEventSystemClient dispatch ✅ (senderID=0x%llX)", getCurrentSenderID());
            return;
        }
    }
    
    NSLog(@"[StarCoreTweak] ❌ 所有派发路径失败");
}

// ==================== 触摸注入函数 ====================

// ★ v7.0: 使用真实senderID，事件可正确路由到前台App
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
    
    // ★ v7.0 核心修复：使用真实senderID替代硬编码
    if (IOHIDEventSetSenderIDFunc) {
        uint64_t sid = getCurrentSenderID();
        IOHIDEventSetSenderIDFunc(hand, sid);
        if (g_realSenderID == 0) {
            NSLog(@"[StarCoreTweak] ⚠️ 使用硬编码senderID(未获取到真实值)，触摸可能只影响SpringBoard");
        }
    }
    
    if (setDigitizerInfo && BKSHIDEventSetDigitizerInfoFunc && cid != 0) {
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

// 触摸函数
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
    if (d) { 
        // ★ v7.0: Home键也使用真实senderID
        if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(d, getCurrentSenderID()); 
        dispatchHIDEvent(d); 
    }
    usleep(50000); ts = mach_absolute_time();
    IOHIDEventRef u = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, kHIDPage_Consumer, kHIDUsage_Csmr_Menu, false, 0);
    if (u) { 
        if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(u, getCurrentSenderID()); 
        dispatchHIDEvent(u); 
    }
    resetIdleTimer();
}

// ==================== 虚拟触摸设备 ====================

static bool initVirtualKeyboardDevice() {
    if (g_virtualKeyboardReady) return true;
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) return false;
    
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
        NSLog(@"[StarCoreTweak] ❌ 虚拟键盘设备创建失败");
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
        NSLog(@"[StarCoreTweak] ❌ 虚拟触摸设备创建失败");
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
    int steps = (int)(duration * 60);
    if (steps < 2) steps = 2;
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
    uint32_t stepInterval = 50000;
    sendTouchReport(true, 0, 200, xN, yN, 1);
    while (elapsed < sleepTimeUs) {
        usleep(stepInterval);
        elapsed += stepInterval;
        uint16_t jitterX = xN + (elapsed / stepInterval) % 3 - 1;
        uint16_t jitterY = yN + (elapsed / stepInterval) % 3 - 1;
        sendTouchReport(true, 0, 200, jitterX, jitterY, 1);
    }
    sendTouchReport(false, 0, 0, xN, yN, 0);
}

// ==================== 键盘字符输入 ====================

static bool keyToUsage(NSString *key, uint32_t *page, uint32_t *usage) {
    static NSDictionary *keyMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyMap = @{
            @"return": @(0x28), @"enter": @(0x28), @"tab": @(0x2B),
            @"space": @(0x2C), @"delete": @(0x2A), @"backspace": @(0x2A),
            @"escape": @(0x29), @"esc": @(0x29),
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
            if (c >= 'A' && c <= 'Z') { *usage = 0x04 + (c - 'A'); *page = kHIDPage_KeyboardOrKeypad; return true; }
            if (c >= '0' && c <= '9') { *usage = 0x1E + (c - '0'); *page = kHIDPage_KeyboardOrKeypad; return true; }
        }
        return false;
    }
    *usage = [usageNum unsignedIntValue];
    *page = kHIDPage_KeyboardOrKeypad;
    return true;
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

// ==================== TCP服务器 ====================

@interface StarCoreTCPServer : NSObject
- (void)startOnPort:(uint16_t)port;
- (void)stop;
@end

static StarCoreTCPServer *_server = nil;

@implementation StarCoreTCPServer { NSInteger _sock; NSMutableArray<NSNumber *> *_fds; uint16_t _port; }
- (instancetype)init { self = [super init]; if (self) { _sock = -1; _fds = [NSMutableArray new]; _port = 0; g_globalsLock = [[NSLock alloc] init]; } return self; }

- (void)startOnPort:(uint16_t)port {
    _port = port;
    _sock = socket(AF_INET, SOCK_STREAM, 0); if (_sock < 0) return;
    int y=1; setsockopt((int)_sock, SOL_SOCKET, SO_REUSEADDR, &y, sizeof(y));
    struct sockaddr_in a; memset(&a,0,sizeof(a)); a.sin_len=sizeof(a); a.sin_family=AF_INET; a.sin_port=htons(port); a.sin_addr.s_addr=htonl(INADDR_ANY);
    if (bind((int)_sock,(struct sockaddr*)&a,sizeof(a))<0||listen((int)_sock,5)<0) { close((int)_sock); _sock=-1; NSLog(@"[StarCoreTweak] ❌ 端口%d bind/listen失败", port); return; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{[self acceptLoop];});
    NSLog(@"[StarCoreTweak] TCP :%d v8.2 [sendEvent Hook获取senderID]", port);
}

- (void)acceptLoop {
    while(_sock>=0) { struct sockaddr_in ca; socklen_t cl=sizeof(ca); int fd=accept((int)_sock,(struct sockaddr*)&ca,&cl); if(fd<0) continue;
        @synchronized(_fds){[_fds addObject:@(fd)];} dispatch_async(dispatch_get_global_queue(0,0),^{[self handleClient:fd];}); }
}

- (void)handleClient:(int)fd {
    NSMutableData *buf=[NSMutableData new]; uint8_t b[4096];
    const NSUInteger kMaxBufSize = 1048576;
    while(YES) { ssize_t l=read(fd,b,sizeof(b)); if(l<=0) break; [buf appendBytes:b length:l];
        if (buf.length > kMaxBufSize) { [buf setLength:0]; break; }
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
    
    if([action isEqualToString:@"ping"]) { resp[@"success"]=@YES; resp[@"message"]=@"pong"; resp[@"version"]=@"8.1"; }
    
    else if([action isEqualToString:@"tap"]) {
        float x=[req[@"x"] floatValue],y=[req[@"y"] floatValue];
        if(x>1.0f||y>1.0f){CGRect b=getScreenBoundsSafe();x/=b.size.width;y/=b.size.height;if(x>1)x=1;if(y>1)y=1;}
        
        if (g_virtualDeviceReady) {
            virtualTap(x, y);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateTap_old(x, y);
            resp[@"success"]=@YES; resp[@"method"]=@"senderID+IOHIDEventSystemClient";
        }
    }
    
    else if([action isEqualToString:@"swipe"]) {
        float fX=[req[@"fromX"] floatValue]?:[req[@"x1"] floatValue];
        float fY=[req[@"fromY"] floatValue]?:[req[@"y1"] floatValue];
        float tX=[req[@"toX"] floatValue]?:[req[@"x2"] floatValue];
        float tY=[req[@"toY"] floatValue]?:[req[@"y2"] floatValue];
        float dur=[req[@"duration"] floatValue]?:0.5f;
        
        if (g_virtualDeviceReady) {
            virtualSwipe(fX, fY, tX, tY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateSwipe_old(fX, fY, tX, tY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"senderID+IOHIDEventSystemClient";
        }
    }
    
    else if([action isEqualToString:@"longPress"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        float d=[req[@"duration"] floatValue] ?: 1.0f;
        
        if (g_virtualDeviceReady) {
            virtualLongPress(x, y, d);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateLongPress_old(x, y, d);
            resp[@"success"]=@YES; resp[@"method"]=@"senderID+IOHIDEventSystemClient";
        }
    }
    
    else if([action isEqualToString:@"pressHome"]) { simulateHomeButton(); resp[@"success"]=@YES; }
    
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"key required"; }
        else if (!g_virtualKeyboardReady) { resp[@"success"]=@NO; resp[@"error"]=@"virtual keyboard not ready, call initDevice first"; }
        else {
            uint32_t page = 0, usage = 0;
            if (keyToUsage(key, &page, &usage)) { handleKeyPressViaVirtualDevice(page, usage); resp[@"success"]=@YES; }
            else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"unknown key: %@", key]; }
        }
    }
    
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else if (!g_virtualKeyboardReady) { resp[@"success"]=@NO; resp[@"error"]=@"virtual keyboard not ready, call initDevice first"; }
        else { handleTextInput(text); resp[@"success"]=@YES; }
    }
    
    else if([action isEqualToString:@"shell"]) {
        NSString *cmd = req[@"command"];
        if (!cmd || cmd.length == 0) { resp[@"success"]=@NO; resp[@"error"]=@"command required"; }
        else {
            const char *tmpPath = "/tmp/starcore_shell_out";
            remove(tmpPath);
            posix_spawn_file_actions_t actions;
            posix_spawn_file_actions_init(&actions);
            posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, tmpPath, O_WRONLY|O_CREAT|O_TRUNC, 0644);
            posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);
            char *argv[] = {(char*)"/bin/sh", (char*)"-c", (char*)[cmd UTF8String], NULL};
            char *envp[] = {(char*)"PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin", (char*)"HOME=/var/mobile", NULL};
            setuid(0);
            pid_t pid;
            int spawnResult = posix_spawn(&pid, "/bin/sh", &actions, NULL, argv, envp);
            posix_spawn_file_actions_destroy(&actions);
            if (spawnResult != 0) { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"posix_spawn failed: %s", strerror(spawnResult)]; }
            else {
                int status = 0, waitCount = 0;
                while (waitCount < 100) { pid_t result = waitpid(pid, &status, WNOHANG); if (result > 0 || result < 0) break; usleep(100000); waitCount++; }
                if (waitCount >= 100) { kill(pid, SIGKILL); resp[@"error"]=@"timeout (10s)"; }
                NSString *output = @"";
                FILE *fp = fopen(tmpPath, "r");
                if (fp) {
                    NSMutableData *outData = [NSMutableData data]; char buf[4096];
                    while (fgets(buf, sizeof(buf), fp)) [outData appendBytes:buf length:strlen(buf)];
                    fclose(fp);
                    if (outData.length > 65536) { [outData replaceBytesInRange:NSMakeRange(65536, outData.length - 65536) withBytes:"" length:0]; output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding]; output = [output stringByAppendingString:@"\n... [truncated]"]; }
                    else output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
                }
                remove(tmpPath);
                resp[@"success"] = @(WIFEXITED(status) && WEXITSTATUS(status) == 0);
                resp[@"output"] = output;
                resp[@"exitCode"] = @(WIFEXITED(status) ? WEXITSTATUS(status) : -1);
            }
        }
    }
    
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) { resp[@"success"]=@NO; resp[@"error"]=@"bundleId required"; }
        else {
            __block BOOL ok = NO;
            __block NSString *errMsg = @"no workspace";
            runOnMainThreadSync(^{
                Class wc = objc_getClass("LSApplicationWorkspace");
                if (wc) {
                    id ws = [wc performSelector:@selector(defaultWorkspace)];
                    if (ws) { ok = (BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), bid); if (!ok) errMsg = @"openApplication returned NO"; }
                    else errMsg = @"defaultWorkspace returned nil";
                }
            });
            resp[@"success"]=@(ok); if (!ok) resp[@"error"]=errMsg;
        }
    }
    
    else if([action isEqualToString:@"getScreenSize"]) {
        CGRect b = getScreenBoundsSafe(); CGFloat scale = getScreenScaleSafe();
        resp[@"success"]=@YES; resp[@"width"]=@(b.size.width); resp[@"height"]=@(b.size.height); resp[@"scale"]=@(scale);
    }
    
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady?@"OK":@"FAILED";
        resp[@"virtualKeyboardDevice"]=g_virtualKeyboardReady?@"OK":@"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
        resp[@"senderID"]=g_realSenderID!=0?[NSString stringWithFormat:@"0x%llX",g_realSenderID]:@"waiting";
    }
    
    else if([action isEqualToString:@"set_senderid"]) {
        // v8.0: 手动设置senderID（替代被移除的回调机制）
        uint64_t newSenderID = [req[@"value"] unsignedLongLongValue];
        if (newSenderID != 0) {
            g_realSenderID = newSenderID;
            g_senderIDCapturing = NO;  // v8.2: 手动设置后停止捕获
            // 保存到文件
            NSDictionary *saveDict = @{
                @"senderID": @(g_realSenderID),
                @"bootTime": @([[NSDate date] timeIntervalSince1970] - [NSProcessInfo processInfo].systemUptime)
            };
            [saveDict writeToFile:g_senderIDFilePath atomically:YES];
            resp[@"success"] = @YES;
            resp[@"senderID"] = [NSString stringWithFormat:@"0x%llX", g_realSenderID];
            resp[@"message"] = @"senderID已设置并保存到文件";
            NSLog(@"[StarCoreTweak] ✅ 手动设置senderID: 0x%llX (已保存)", g_realSenderID);
        } else {
            resp[@"success"] = @NO;
            resp[@"error"] = @"invalid value: must be non-zero uint64";
        }
    }
    
    else if([action isEqualToString:@"capture_senderid"]) {
        // v8.2: 通过sendEvent hook捕获真实senderID
        if (g_realSenderID != 0) {
            // 已经有真实senderID
            resp[@"success"] = @YES;
            resp[@"senderID"] = [NSString stringWithFormat:@"0x%llX", g_realSenderID];
            resp[@"source"] = @"already_captured";
        } else {
            g_senderIDCapturing = YES;
            resp[@"success"] = @YES;
            resp[@"message"] = @"Waiting for real touch event...";
            resp[@"hint"] = @"Touch the screen now to capture senderID";
            NSLog(@"[StarCoreTweak] capture_senderid: 已开启捕获，等待触摸...");
        }
    }
    
    else if([action isEqualToString:@"diagnose"]) {
        NSString *ctxSrc = SAFE_GET_GLOBAL(g_contextSource);
        NSString *frontApp = SAFE_GET_GLOBAL(g_frontmostApp);
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        
        // ★ v8.0: 判断senderID来源
        NSString *senderIDSource = @"unknown";
        if (g_realSenderID != 0) {
            NSDictionary *data = [NSDictionary dictionaryWithContentsOfFile:g_senderIDFilePath];
            if (data) {
                NSTimeInterval bootTime = [[NSDate date] timeIntervalSince1970] - [NSProcessInfo processInfo].systemUptime;
                NSTimeInterval savedBootTime = [data[@"bootTime"] doubleValue];
                senderIDSource = fabs(bootTime - savedBootTime) <= 3 ? @"file" : @"hardcoded";
            } else {
                senderIDSource = @"hardcoded";
            }
        } else {
            senderIDSource = @"hardcoded_fallback";
        }
        
        resp[@"success"]=@YES;
        resp[@"diagnostics"]=@{
            @"version": @"8.1",
            @"approach": @"senderID",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"BKHIDSystemInterface": (bksSharedInstance() != nil) ? @"OK":@"NULL",
            @"realSenderID": g_realSenderID!=0?[NSString stringWithFormat:@"0x%llX",g_realSenderID]:@"未获取",
            @"senderIDSource": senderIDSource,
            @"senderIDCapturing": @(g_senderIDCapturing),
            @"createDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"eventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@"OK":@"NULL",
            @"IOHIDEventGetSenderID": IOHIDEventGetSenderIDFunc?@"OK":@"NULL",
            @"BKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualKeyboardDevice": g_virtualKeyboardReady?@"OK":@"FAILED",
            @"virtualDeviceError": g_virtualDeviceError ?: @"",
            @"frontmostApp": frontApp ?: @"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": ctxSrc ?: @"none",
            @"dispatchPath": (bksSharedInstance() != nil) ? @"BKHIDSystemInterface":@"IOHIDEventSystemClient+senderID",
        };
    }
    
    else if([action isEqualToString:@"validate"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"BKHIDSystemInterfaceAvailable": (bksSharedInstance() != nil) ? @YES:@NO,
            @"functionIOHIDEventCreateDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@YES:@NO,
            @"functionIOHIDEventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@YES:@NO,
            @"functionIOHIDEventGetSenderID": IOHIDEventGetSenderIDFunc?@YES:@NO,
            @"functionBKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@YES:@NO,
            @"functionIOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@YES:@NO,
            @"functionIOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@YES:@NO,
            @"realSenderID": g_realSenderID!=0?@YES:@NO,
            @"canInjectTouch": @YES,
            @"canInjectTouchToApp": @(g_realSenderID != 0 || bksSharedInstance() != nil),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
            @"virtualKeyboardReady": @(g_virtualKeyboardReady),
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
        };
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

// ==================== sendEvent Hook (v8.2: 安全获取真实senderID) ====================

%hook UIApplication
- (void)sendEvent:(id)event {
    %orig;
    
    // 只在需要捕获senderID时处理，获取到后立即停止（性能零影响）
    if (g_senderIDCapturing && g_realSenderID == 0 && IOHIDEventGetSenderIDFunc) {
        @try {
            // UIEvent中包含IOHIDEvent，通过私有API _hidEvent 获取
            IOHIDEventRef hidEvent = NULL;
            
            // 方法1: 尝试 _hidEvent 私有属性
            if ([event respondsToSelector:@selector(_hidEvent)]) {
                id hidEventObj = [event performSelector:@selector(_hidEvent)];
                if (hidEventObj) {
                    hidEvent = (__bridge IOHIDEventRef)hidEventObj;
                }
            }
            
            // 方法2: 尝试 KVC 获取 _hidEvent
            if (!hidEvent) {
                @try {
                    id hidEventObj = [event valueForKey:@"_hidEvent"];
                    if (hidEventObj) {
                        hidEvent = (__bridge IOHIDEventRef)hidEventObj;
                    }
                } @catch (NSException *e) {
                    // KVC失败，静默忽略
                }
            }
            
            // 方法3: 尝试 _systemEvent 私有属性
            if (!hidEvent) {
                @try {
                    id sysEvent = [event valueForKey:@"_systemEvent"];
                    if (sysEvent) {
                        hidEvent = (__bridge IOHIDEventRef)sysEvent;
                    }
                } @catch (NSException *e) {}
            }
            
            if (hidEvent) {
                uint64_t sid = IOHIDEventGetSenderIDFunc(hidEvent);
                // 过滤掉硬编码值和0值，只接受真实的硬件senderID
                if (sid != 0 && sid != kIOHIDEventDigitizerSenderID) {
                    g_realSenderID = sid;
                    g_senderIDCapturing = NO;
                    NSLog(@"[StarCoreTweak] ✅ 从sendEvent获取到真实senderID: 0x%llX", sid);
                    
                    // 保存到文件，下次启动可直接使用
                    NSDictionary *dict = @{
                        @"senderID": @(sid),
                        @"bootTime": @([[NSDate date] timeIntervalSince1970] - [NSProcessInfo processInfo].systemUptime)
                    };
                    [dict writeToFile:g_senderIDFilePath atomically:YES];
                    NSLog(@"[StarCoreTweak] senderID已保存到文件");
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] sendEvent hook异常: %@", e);
        }
    }
}
%end

// ==================== 进程入口 ====================

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动 v8.2 (sendEvent Hook获取senderID)");
    loadFunctions();
    
    // ★ v8.2: 初始化senderID（从文件读取，无缓存则开启sendEvent捕获）
    initSenderID();
    
    _server = [[StarCoreTCPServer alloc] init];
    [_server startOnPort:kServerPort];
    NSLog(@"[StarCoreTweak] v8.2 ready - senderID: 0x%llX (capturing=%d, 也可通过set_senderid设置)", g_realSenderID, g_senderIDCapturing);
}
%end

%ctor {
    %init;
    NSLog(@"[StarCoreTweak] v8.2 loading in SpringBoard... (sendEvent Hook获取senderID)");
}

%dtor { [_server stop]; }
