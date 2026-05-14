/**
 * StarCoreTweak.xm v5.9 - BKHIDSystemInterface触摸注入修复
 * 
 * v5.9 修复清单：
 * 1. 🔥 dispatchHIDEvent()优先使用BKHIDSystemInterface injectHIDEvent:（BackBoardServices私有API）
 *    - IOHIDEventSystemClientDispatchEvent只能派发到SpringBoard自身，无法注入到前台App
 *    - BKHIDSystemInterface injectHIDEvent:是ZXTouch/ios-mcp验证过的正确注入路径
 *    - 保留IOHIDEventSystemClient作为回退方案
 * 2. diagnose/validate输出添加BKS状态报告
 * 
 * v5.7 修复清单（继承）：
 * 1. 🔥 performSelector调用返回非对象类型(pid_t, uint32_t)→野指针→全部改用objc_msgSend
 * 2. 🔥 UIKit操作从TCP后台线程调用→线程不安全→全部dispatch到主线程
 * 3. 🔥 UIScreen.mainScreen.bounds从后台线程访问→dispatch到主线程
 * 4. 🔥 resetIdleTimer从后台线程调用→dispatch到主线程
 * 5. 🔥 openApp从后台线程调用→dispatch到主线程
 * 6. 全局变量(g_contextSource/g_frontmostApp)添加线程安全保护
 * 7. TCP缓冲区溢出保护(1MB上限)
 * 8. @try/@catch标注：无法捕获SIGSEGV，只能捕获ObjC异常
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
// 旧方案函数
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;
static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;
static void (*BKSHIDEventSetDigitizerInfoFunc)(IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float) = NULL;

// ★ v5.1: IOHIDUserDevice函数（虚拟触摸设备）
static IOHIDUserDeviceRef (*IOHIDUserDeviceCreateFunc)(CFAllocatorRef, CFDictionaryRef, IOOptionBits) = NULL;
static IOReturn (*IOHIDUserDeviceHandleReportFunc)(IOHIDUserDeviceRef, const uint8_t *, CFIndex) = NULL;

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL;

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

// ★ v5.1 修复：HID Report Descriptor - 所有字段字节对齐
// 修复：Tip Switch 从 1 bit 改为 8 bits (1字节)，添加 padding 使后续字段正确对齐
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
    0x75, 0x08,        //     Report Size (8) ← 改为8位字节对齐
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data, Variable, Absolute)
    // 添加padding让后续字段字节对齐
    0x75, 0x08,        //     Report Size (8)
    0x95, 0x07,        //     Report Count (7) ← 7字节padding
    0x81, 0x03,        //     Input (Constant) ← padding
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
    // Contact Count Maximum 作为 Feature Report 已移除（非必需）
    0xC0               // End Collection
};

// ★ v5.2: 键盘HID Report Descriptor
// Keyboard Usage Page (0x07) - 标准101键键盘
// Report ID = 2
// 格式：Byte 0(Report ID) + Byte 1(Modifiers) + Byte 2(Reserved) + Bytes 3-8(KeyCodes)
static const uint8_t g_keyboard_descriptor[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x02,        //   Report ID (2)
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0xE0,        //   Usage Minimum (224) - Left Control
    0x29, 0xE7,        //   Usage Maximum (231) - Right GUI
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8) - 8 modifier keys
    0x81, 0x02,        //   Input (Data, Variable, Absolute) - Modifier keys
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x08,        //   Report Size (8)
    0x81, 0x01,        //   Input (Constant) - Reserved byte
    0x95, 0x06,        //   Report Count (6) - 6 key codes
    0x75, 0x08,        //   Report Size (8)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x65,        //   Logical Maximum (101) - Keyboard a-z, 0-9, etc.
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0x00,        //   Usage Minimum (0) - No Event
    0x29, 0x65,        //   Usage Maximum (101) - Keyboard Application
    0x81, 0x00,        //   Input (Data, Array) - Key codes
    0xC0               // End Collection
};

// ==================== 前向声明 ====================
static void resetIdleTimer(void);
static void dispatchHIDEvent(IOHIDEventRef event);

// ★ v5.7: 主线程同步执行辅助函数
// 所有UIKit操作必须通过此函数dispatch到主线程
// ⚠️ 注意：不能从主线程调用此函数并等待另一个也等待主线程的操作，否则死锁
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
    LOAD_SYM(IOHIDEventAppendEventFunc, "IOHIDEventAppendEvent");
    LOAD_SYM(IOHIDEventSystemClientCreateFunc, "IOHIDEventSystemClientCreate");
    LOAD_SYM(IOHIDEventSystemClientDispatchEventFunc, "IOHIDEventSystemClientDispatchEvent");
    LOAD_SYM(BKSHIDEventSetDigitizerInfoFunc, "BKSHIDEventSetDigitizerInfo");
    
    // ★ v5.1: IOHIDUserDevice函数
    LOAD_SYM(IOHIDUserDeviceCreateFunc, "IOHIDUserDeviceCreate");
    LOAD_SYM(IOHIDUserDeviceHandleReportFunc, "IOHIDUserDeviceHandleReport");
    
    #undef LOAD_SYM
    
    if (!IOHIDEventCreateDigitizerEventFunc) { NSLog(@"[StarCoreTweak] ❌ 核心函数缺失"); return false; }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ v5.9 函数加载成功");
    return true;
}

// ==================== Context ID获取（线程安全）====================

// ★ v5.7: getContextIDFromCAWindowServer - 全部在主线程执行
// 修复：pid和contextID都返回原始类型(pid_t/uint32_t)，performSelector:会野指针崩溃
static uint32_t getContextIDFromCAWindowServer() {
    __block uint32_t bestCID = 0;
    
    // ★ v5.7: CAWindowServer操作必须在主线程
    runOnMainThreadSync(^{
        @try {
            Class wsClass = objc_getClass("CAWindowServer");
            if (!wsClass) {
                wsClass = NSClassFromString(@"CAWindowServer");
            }
            if (!wsClass) return;
            
            SEL serverSel = NSSelectorFromString(@"serverIfRunning");
            if (![wsClass respondsToSelector:serverSel]) return;
            
            // serverIfRunning返回id(CAWindowServer实例)，performSelector:安全
            id ws = ((id(*)(id, SEL))objc_msgSend)(wsClass, serverSel);
            if (!ws) return;
            
            SEL contextsSel = NSSelectorFromString(@"contexts");
            if (![ws respondsToSelector:contextsSel]) return;
            
            // contexts返回NSArray*，performSelector:安全
            NSArray *contexts = ((NSArray *(*)(id, SEL))objc_msgSend)(ws, contextsSel);
            if (!contexts || contexts.count == 0) return;
            
            for (id ctx in contexts) {
                if (![ctx respondsToSelector:@selector(pid)]) continue;
                
                // ★ v5.7修复：pid返回pid_t(原始int类型)
                // 旧代码 [[ctx performSelector:@selector(pid)] intValue] 野指针崩溃！
                // performSelector:把pid_t小整数当id指针→SIGSEGV
                pid_t pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(ctx, @selector(pid));
                
                if (pid == getpid()) continue;
                
                if (pid == 0) {
                    if ([ctx respondsToSelector:@selector(contextID)]) {
                        // ★ v5.7修复：contextID返回uint32_t(原始类型)
                        // 旧代码 [[ctx performSelector:@selector(contextID)] unsignedIntValue] 野指针崩溃！
                        // 与v5.4的_contextId崩溃同一类bug
                        uint32_t cid = ((uint32_t(*)(id, SEL))objc_msgSend)(ctx, @selector(contextID));
                        if (cid != 0) {
                            bestCID = cid;
                            break;
                        }
                    }
                }
            }
        } @catch (NSException *e) {
            // ⚠️ 注意：@try/@catch只能捕获ObjC异常，无法捕获SIGSEGV/SIGBUS信号
            NSLog(@"[StarCoreTweak] getContextIDFromCAWindowServer exception: %@", e);
        }
    });
    
    return bestCID;
}

// ★ v5.7: getKeyWindowContextID - 全部在主线程执行
static uint32_t getKeyWindowContextID() {
    __block uint32_t cid = 0;
    
    // ★ v5.7: keyWindow访问必须在主线程
    runOnMainThreadSync(^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (!app) return;
            
            // ★ v5.7: 优先使用windows数组找keyWindow（keyWindow属性已废弃且非线程安全）
            UIWindow *keyWin = nil;
            for (UIWindow *window in app.windows) {
                if (window.isKeyWindow) {
                    keyWin = window;
                    break;
                }
            }
            
            // 回退：尝试keyWindow属性
            if (!keyWin && [app respondsToSelector:@selector(keyWindow)]) {
                keyWin = [app performSelector:@selector(keyWindow)];
            }
            
            if (keyWin && [keyWin respondsToSelector:@selector(_contextId)]) {
                // ★ v5.5已修复：_contextId返回uint32_t，用objc_msgSend直接取值
                uint32_t cid_val = ((uint32_t(*)(id, SEL))objc_msgSend)(keyWin, @selector(_contextId));
                if (cid_val != 0) {
                    SAFE_SET_GLOBAL(g_contextSource, @"keyWindow");
                    cid = cid_val;
                }
            }
        } @catch (NSException *e) {
            // ⚠️ 注意：@try/@catch只能捕获ObjC异常，无法捕获SIGSEGV/SIGBUS信号
            NSLog(@"[StarCoreTweak] getKeyWindowContextID exception: %@", e);
        }
    });
    
    return cid;
}

// ★ v5.7: getTargetContextID - UIKit操作全部在主线程
static uint32_t getTargetContextID() {
    uint32_t cid = getKeyWindowContextID();
    if (cid != 0) {
        // ★ v5.7: frontmostApplication访问在主线程
        runOnMainThreadSync(^{
            @try {
                UIApplication *app = [UIApplication sharedApplication];
                if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                    id frontApp = [app performSelector:@selector(frontmostApplication)];
                    if (frontApp && [frontApp respondsToSelector:@selector(bundleIdentifier)]) {
                        NSString *bid = [frontApp performSelector:@selector(bundleIdentifier)];
                        if (bid) {
                            SAFE_SET_GLOBAL(g_frontmostApp, bid);
                        }
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

// ★ v5.7: resetIdleTimer - UIKit操作在主线程
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
    
    // ★ v5.9: 优先使用BKHIDSystemInterface（BackBoardServices私有API，从SpringBoard注入到前台App）
    // IOHIDEventSystemClientDispatchEvent只能派发事件到SpringBoard自身进程，
    // 无法将触摸事件注入到前台运行的App。BKHIDSystemInterface injectHIDEvent:
    // 是BackBoardServices框架提供的私有API，通过Backboard daemon将事件
    // 正确路由到前台App的UIEvent处理链。这是ZXTouch和ios-mcp验证过的方案。
    @try {
        id bks = bksSharedInstance();
        if (bks) {
            bksInjectHIDEvent(bks, event);
            return; // BKS成功注入，不需要走IOHIDEventSystemClient
        }
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] BKHIDSystemInterface injectHIDEvent failed: %@", e);
    }
    
    // 回退：IOHIDEventSystemClient（只能影响SpringBoard自身，无法注入前台App）
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        });
        if (client) {
            IOHIDEventSystemClientDispatchEventFunc(client, event);
        }
    }
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

// 旧方案触摸函数（用于回退）
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

// ==================== v5.1: IOHIDUserDevice虚拟触摸设备 ====================

// ★ v5.2: 初始化虚拟键盘设备
static bool initVirtualKeyboardDevice() {
    if (g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] 虚拟键盘设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // 构建设备属性字典
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // Report Descriptor
    NSData *descriptorData = [NSData dataWithBytes:g_keyboard_descriptor length:sizeof(g_keyboard_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    
    // 设备信息
    properties[@"Product"] = @"StarCore Virtual Keyboard";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0002);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    
    // HID设备类型 - 键盘
    properties[@"PrimaryUsagePage"] = @(0x07);
    properties[@"PrimaryUsage"] = @(0x06);
    properties[@"DeviceUsagePage"] = @(0x01);
    properties[@"DeviceUsage"] = @(0x06);
    
    // 转为CFDictionary
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    
    // 创建虚拟键盘设备
    g_virtualKeyboardDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualKeyboardDevice) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate键盘设备失败 (可能缺少HID entitlements)");
        return false;
    }
    
    g_virtualKeyboardReady = true;
    NSLog(@"[StarCoreTweak] ✅ 虚拟键盘设备创建成功");
    
    return true;
}

// ★ v5.2: 发送键盘报告
// Report格式（9字节）：
// Byte 0: Report ID = 2
// Byte 1: Modifiers (bit flags)
// Byte 2: Reserved = 0
// Bytes 3-8: Key codes (最多6个同时按键)
static bool sendKeyboardReport(uint8_t modifiers, const uint8_t *keyCodes, int keyCodeCount) {
    if (!g_virtualKeyboardReady || !IOHIDUserDeviceHandleReportFunc) {
        return false;
    }
    
    uint8_t report[9] = {0};
    report[0] = 0x02;  // Report ID = 2
    report[1] = modifiers;
    report[2] = 0;  // Reserved
    
    // 填充key codes（最多6个）
    int count = (keyCodeCount > 6) ? 6 : keyCodeCount;
    for (int i = 0; i < count; i++) {
        report[3 + i] = keyCodes[i];
    }
    
    IOReturn result = IOHIDUserDeviceHandleReportFunc(g_virtualKeyboardDevice, report, sizeof(report));
    
    if (result != kIOReturnSuccess) {
        NSLog(@"[StarCoreTweak] ⚠️ 键盘HandleReport返回: 0x%x", result);
        return false;
    }
    
    return true;
}

// ★ v5.2: 通过虚拟键盘设备发送按键
static void handleKeyPressViaVirtualDevice(uint32_t page, uint32_t usage) {
    if (!g_virtualKeyboardReady) return;
    
    // key down - 发送usage code
    uint8_t keys[1] = { (uint8_t)usage };
    sendKeyboardReport(0, keys, 1);
    usleep(50000);
    
    // key up - 发送0表示无按键
    uint8_t noKeys[1] = { 0 };
    sendKeyboardReport(0, noKeys, 0);
    
    resetIdleTimer();
}

// ★ v5.2: 创建虚拟触摸设备（并尝试创建键盘设备）
static bool initVirtualTouchDevice() {
    // 如果两个设备都已就绪，直接返回
    if (g_virtualDeviceReady && g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] 虚拟设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        g_virtualDeviceError = @"IOHIDUserDevice函数未加载";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // ★ v5.2: 先创建键盘设备（比触摸设备简单，优先创建）
    if (!g_virtualKeyboardReady) {
        initVirtualKeyboardDevice();
        // 键盘设备创建失败不阻止触摸设备创建
    }
    
    // 创建触摸设备
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // Report Descriptor (CFDataRef)
    NSData *descriptorData = [NSData dataWithBytes:g_multitouch_descriptor length:sizeof(g_multitouch_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    
    // 设备信息
    properties[@"Product"] = @"StarCore Virtual Touch";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0001);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    
    // HID设备类型 - 触摸屏
    properties[@"PrimaryUsagePage"] = @(0x0D);
    properties[@"PrimaryUsage"] = @(0x04);
    properties[@"DeviceUsagePage"] = @(0x0D);
    properties[@"DeviceUsage"] = @(0x04);
    
    // 转为CFDictionary
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    
    // 创建虚拟设备
    g_virtualDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualDevice) {
        g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL (可能缺少HID entitlements)";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate触摸设备失败 (可能缺少HID entitlements)");
        // 不返回false，让键盘设备继续工作
    } else {
        g_virtualDeviceReady = true;
        g_virtualDeviceError = @"";
        NSLog(@"[StarCoreTweak] ✅ 虚拟触摸设备创建成功");
    }
    
    // ★ v5.2: 返回任一设备就绪即可
    return g_virtualDeviceReady || g_virtualKeyboardReady;
}

// ★ v5.1 修复：HID触摸报告 - 字节对齐版本
// Report格式（17字节 = 1 Report ID + 16 data）：
// Byte 0: Report ID = 1
// Byte 1: Tip Switch (1字节，0或1)
// Byte 2-8: Padding (7字节常量)
// Byte 9: Contact Identifier
// Byte 10-11: Tip Pressure (uint16 LE)
// Byte 12-13: X (uint16 LE, 0-32767)
// Byte 14-15: Y (uint16 LE, 0-32767)
// Byte 16: Contact Count
static bool sendTouchReport(bool tipSwitch, uint8_t contactId, uint16_t pressure, uint16_t xNorm, uint16_t yNorm, uint8_t contactCount) {
    if (!g_virtualDeviceReady || !IOHIDUserDeviceHandleReportFunc) {
        return false;
    }
    
    // Report buffer (17字节: 1 byte report ID + 16 bytes data)
    uint8_t report[17] = {0};
    report[0] = 0x01;  // Report ID
    report[1] = tipSwitch ? 0x01 : 0x00;  // Tip Switch (8-bit aligned)
    // Bytes 2-8: Padding (已初始化为0)
    report[9] = contactId;  // Contact Identifier
    // Tip Pressure (uint16_t LE)
    report[10] = pressure & 0xFF;
    report[11] = (pressure >> 8) & 0xFF;
    // X (uint16_t LE, 0-32767)
    report[12] = xNorm & 0xFF;
    report[13] = (xNorm >> 8) & 0xFF;
    // Y (uint16_t LE, 0-32767)
    report[14] = yNorm & 0xFF;
    report[15] = (yNorm >> 8) & 0xFF;
    // Contact Count
    report[16] = contactCount;
    
    IOReturn result = IOHIDUserDeviceHandleReportFunc(g_virtualDevice, report, sizeof(report));
    
    if (result != kIOReturnSuccess) {
        NSLog(@"[StarCoreTweak] ⚠️ HandleReport返回: 0x%x", result);
        return false;
    }
    
    return true;
}

// 坐标归一化 (0.0-1.0) -> (0-32767)
static inline uint16_t normalizeCoord(float coord) {
    if (coord < 0) coord = 0;
    if (coord > 1) coord = 1;
    return (uint16_t)(coord * 32767.0f);
}

// ★ v5.1: 虚拟设备tap
static void virtualTap(float x, float y) {
    if (!g_virtualDeviceReady) {
        NSLog(@"[StarCoreTweak] ⚠️ 虚拟设备未就绪，使用旧方案");
        return;
    }
    
    uint16_t xN = normalizeCoord(x);
    uint16_t yN = normalizeCoord(y);
    
    // touch down
    sendTouchReport(true, 0, 200, xN, yN, 1);
    usleep(50000);
    // touch up
    sendTouchReport(false, 0, 0, xN, yN, 0);
}

// ★ v5.1: 虚拟设备swipe
static void virtualSwipe(float startX, float startY, float endX, float endY, float duration) {
    if (!g_virtualDeviceReady) {
        NSLog(@"[StarCoreTweak] ⚠️ 虚拟设备未就绪，使用旧方案");
        return;
    }
    
    int steps = (int)(duration * 60);
    if (steps < 2) steps = 2;
    
    uint16_t startXN = normalizeCoord(startX);
    uint16_t startYN = normalizeCoord(startY);
    uint16_t endXN = normalizeCoord(endX);
    uint16_t endYN = normalizeCoord(endY);
    
    // touch down
    sendTouchReport(true, 0, 200, startXN, startYN, 1);
    
    // 移动动画
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        uint16_t xN = startXN + (int)((endXN - startXN) * t);
        uint16_t yN = startYN + (int)((endYN - startYN) * t);
        sendTouchReport(true, 0, 200, xN, yN, 1);
        usleep(16667);
    }
    
    // touch up
    sendTouchReport(false, 0, 0, endXN, endYN, 0);
}

// ★ v5.1: 虚拟设备longPress
static void virtualLongPress(float x, float y, float duration) {
    if (!g_virtualDeviceReady) {
        NSLog(@"[StarCoreTweak] ⚠️ 虚拟设备未就绪，使用旧方案");
        return;
    }
    
    uint16_t xN = normalizeCoord(x);
    uint16_t yN = normalizeCoord(y);
    uint32_t sleepTimeUs = (uint32_t)(duration * 1000000);
    uint32_t elapsed = 0;
    uint32_t stepInterval = 50000;
    
    // touch down
    sendTouchReport(true, 0, 200, xN, yN, 1);
    
    // 保持触摸状态
    while (elapsed < sleepTimeUs) {
        usleep(stepInterval);
        elapsed += stepInterval;
        uint16_t jitterX = xN + (elapsed / stepInterval) % 3 - 1;
        uint16_t jitterY = yN + (elapsed / stepInterval) % 3 - 1;
        sendTouchReport(true, 0, 200, jitterX, jitterY, 1);
    }
    
    // touch up
    sendTouchReport(false, 0, 0, xN, yN, 0);
}

// ==================== v5.1: 键盘字符输入 ====================

// 键名到HID Usage映射
static bool keyToUsage(NSString *key, uint32_t *page, uint32_t *usage) {
    static NSDictionary *keyMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keyMap = @{
            // 功能键
            @"return": @(0x28),
            @"enter": @(0x28),
            @"tab": @(0x2B),
            @"space": @(0x2C),
            @"delete": @(0x2A),
            @"backspace": @(0x2A),
            @"escape": @(0x29),
            @"esc": @(0x29),
            
            // 字母键 (a-z -> 0x04-0x1D)
            @"a": @(0x04), @"b": @(0x05), @"c": @(0x06), @"d": @(0x07),
            @"e": @(0x08), @"f": @(0x09), @"g": @(0x0A), @"h": @(0x0B),
            @"i": @(0x0C), @"j": @(0x0D), @"k": @(0x0E), @"l": @(0x0F),
            @"m": @(0x10), @"n": @(0x11), @"o": @(0x12), @"p": @(0x13),
            @"q": @(0x14), @"r": @(0x15), @"s": @(0x16), @"t": @(0x17),
            @"u": @(0x18), @"v": @(0x19), @"w": @(0x1A), @"x": @(0x1B),
            @"y": @(0x1C), @"z": @(0x1D),
            
            // 数字键 (1-0 -> 0x1E-0x27)
            @"1": @(0x1E), @"2": @(0x1F), @"3": @(0x20), @"4": @(0x21),
            @"5": @(0x22), @"6": @(0x23), @"7": @(0x24), @"8": @(0x25),
            @"9": @(0x26), @"0": @(0x27),
            
            // 特殊符号键
            @"-": @(0x2D), @"=": @(0x2E),
            @"[": @(0x2F), @"]": @(0x30),
            @"\\": @(0x31), @";": @(0x33),
            @"'": @(0x34), @"`": @(0x35),
            @",": @(0x36), @".": @(0x37),
            @"/": @(0x38),
            
            // F键
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
            if (c >= 'a' && c <= 'z') {
                *usage = 0x04 + (c - 'a');
                *page = kHIDPage_KeyboardOrKeypad;
                return true;
            } else if (c >= 'A' && c <= 'Z') {
                *usage = 0x04 + (c - 'A');
                *page = kHIDPage_KeyboardOrKeypad;
                return true;
            } else if (c >= '0' && c <= '9') {
                *usage = 0x1E + (c - '0');
                *page = kHIDPage_KeyboardOrKeypad;
                return true;
            }
        }
        NSLog(@"[StarCoreTweak] ⚠️ 未知键: %@", key);
        return false;
    }
    
    *usage = [usageNum unsignedIntValue];
    *page = kHIDPage_KeyboardOrKeypad;
    return true;
}

// ★ v5.2: 键盘字符输入（只通过虚拟键盘设备，禁用IOHIDEventSystemClient）
static void handleKeyPress(NSString *key) {
    uint32_t page = 0, usage = 0;
    if (!keyToUsage(key, &page, &usage)) {
        NSLog(@"[StarCoreTweak] ⚠️ 无法映射键: %@", key);
        return;
    }
    
    // ★ v5.2: 只通过虚拟键盘设备发送
    if (g_virtualKeyboardReady) {
        handleKeyPressViaVirtualDevice(page, usage);
        return;
    }
    
    // ⚠️ 不再通过IOHIDEventSystemClient发送键盘事件（会崩溃）
    NSLog(@"[StarCoreTweak] ⚠️ 键盘输入需要虚拟键盘设备，请先调用initDevice");
}

// ★ v5.2: 带文本输入的键盘输入（通过虚拟键盘设备）
static void handleTextInput(NSString *text) {
    if (!text || text.length == 0) return;
    
    // ★ v5.2: 检查虚拟键盘设备就绪
    if (!g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] ⚠️ 文本输入需要虚拟键盘设备");
        return;
    }
    
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        NSString *charStr = [NSString stringWithCharacters:&c length:1];
        uint32_t page = 0, usage = 0;
        if (keyToUsage(charStr, &page, &usage)) {
            handleKeyPressViaVirtualDevice(page, usage);
        }
        usleep(30000);
    }
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
    NSLog(@"[StarCoreTweak] TCP :6000 v5.9 (BKHIDSystemInterface触摸注入修复)");
}
- (void)acceptLoop {
    while(_sock>=0) { struct sockaddr_in ca; socklen_t cl=sizeof(ca); int fd=accept((int)_sock,(struct sockaddr*)&ca,&cl); if(fd<0) continue;
        @synchronized(_fds){[_fds addObject:@(fd)];} dispatch_async(dispatch_get_global_queue(0,0),^{[self handleClient:fd];}); }
}
- (void)handleClient:(int)fd {
    // ★ v5.7: 添加最大缓冲区限制防止内存爆炸
    NSMutableData *buf=[NSMutableData new]; uint8_t b[4096];
    const NSUInteger kMaxBufSize = 1048576; // 1MB上限
    while(YES) { ssize_t l=read(fd,b,sizeof(b)); if(l<=0) break; [buf appendBytes:b length:l];
        // ★ v5.7: 缓冲区溢出保护
        if (buf.length > kMaxBufSize) {
            NSLog(@"[StarCoreTweak] ⚠️ TCP缓冲区超过1MB，丢弃并断开");
            [buf setLength:0];
            break;
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
    
    if([action isEqualToString:@"ping"]) { resp[@"success"]=@YES; resp[@"message"]=@"pong"; }
    
    // ★ v5.1: tap - 优先使用虚拟设备
    else if([action isEqualToString:@"tap"]) {
        float x=[req[@"x"] floatValue],y=[req[@"y"] floatValue];
        // ★ v5.7: UIScreen访问在主线程
        if(x>1.0f||y>1.0f){
            CGRect b=getScreenBoundsSafe();
            x/=b.size.width;y/=b.size.height;if(x>1)x=1;if(y>1)y=1;
        }
        
        if (g_virtualDeviceReady) {
            virtualTap(x, y);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateTap_old(x, y);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    // ★ v5.1: swipe - 优先使用虚拟设备
    else if([action isEqualToString:@"swipe"]) {
        float fX=[req[@"fromX"] floatValue], fY=[req[@"fromY"] floatValue];
        float tX=[req[@"toX"] floatValue], tY=[req[@"toY"] floatValue];
        float dur=[req[@"duration"] floatValue] ?: 0.5f;
        
        if (g_virtualDeviceReady) {
            virtualSwipe(fX, fY, tX, tY, dur);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateSwipe_old(fX, fY, tX, tY, dur);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    // ★ v5.1: longPress - 优先使用虚拟设备
    else if([action isEqualToString:@"longPress"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        float d=[req[@"duration"] floatValue] ?: 1.0f;
        
        if (g_virtualDeviceReady) {
            virtualLongPress(x, y, d);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDUserDevice";
        } else {
            simulateLongPress_old(x, y, d);
            resp[@"success"]=@YES;
            resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    else if([action isEqualToString:@"pressHome"]) { simulateHomeButton(); resp[@"success"]=@YES; }
    
    // ★ v5.2: keyPress - 键盘字符输入（需要虚拟键盘设备）
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"key required";
        } else if (!g_virtualKeyboardReady) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"virtual keyboard not ready, call initDevice first";
        } else {
            uint32_t page = 0, usage = 0;
            if (keyToUsage(key, &page, &usage)) {
                handleKeyPressViaVirtualDevice(page, usage);
                resp[@"success"]=@YES;
            } else {
                resp[@"success"]=@NO;
                resp[@"error"]=[NSString stringWithFormat:@"unknown key: %@", key];
            }
        }
    }
    
    // ★ v5.2: textInput - 文本输入（需要虚拟键盘设备）
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"text required";
        } else if (!g_virtualKeyboardReady) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"virtual keyboard not ready, call initDevice first";
        } else {
            handleTextInput(text);
            resp[@"success"]=@YES;
        }
    }
    
    // ★ v5.4: shell - 使用posix_spawn执行命令（绕过SpringBoard沙盒限制）
    else if([action isEqualToString:@"shell"]) {
        NSString *cmd = req[@"command"];
        if (!cmd || cmd.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"command required";
        } else {
            const char *tmpPath = "/tmp/starcore_shell_out";
            remove(tmpPath); // 清理旧文件
            
            posix_spawn_file_actions_t actions;
            posix_spawn_file_actions_init(&actions);
            posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, tmpPath, O_WRONLY|O_CREAT|O_TRUNC, 0644);
            posix_spawn_file_actions_adddup2(&actions, STDOUT_FILENO, STDERR_FILENO);
            
            // 使用/bin/sh -c执行，带完整PATH和root权限
            char *argv[] = {(char*)"/bin/sh", (char*)"-c", (char*)[cmd UTF8String], NULL};
            char *envp[] = {
                (char*)"PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin",
                (char*)"HOME=/var/mobile",
                NULL
            };
            
            // setuid(0)获取root权限（Dopamine越狱环境允许）
            setuid(0);
            
            pid_t pid;
            int spawnResult = posix_spawn(&pid, "/bin/sh", &actions, NULL, argv, envp);
            posix_spawn_file_actions_destroy(&actions);
            
            if (spawnResult != 0) {
                resp[@"success"]=@NO;
                resp[@"error"]=[NSString stringWithFormat:@"posix_spawn failed: %s", strerror(spawnResult)];
            } else {
                // 等待子进程结束（最多10秒）
                int status = 0;
                int waitCount = 0;
                while (waitCount < 100) {
                    pid_t result = waitpid(pid, &status, WNOHANG);
                    if (result > 0) break;
                    if (result < 0) break;
                    usleep(100000); // 100ms
                    waitCount++;
                }
                if (waitCount >= 100) {
                    kill(pid, SIGKILL);
                    resp[@"error"]=@"timeout (10s)";
                }
                
                // 读取输出文件
                NSString *output = @"";
                FILE *fp = fopen(tmpPath, "r");
                if (fp) {
                    NSMutableData *outData = [NSMutableData data];
                    char buf[4096];
                    while (fgets(buf, sizeof(buf), fp)) {
                        [outData appendBytes:buf length:strlen(buf)];
                    }
                    fclose(fp);
                    if (outData.length > 65536) {
                        [outData replaceBytesInRange:NSMakeRange(65536, outData.length - 65536) withBytes:"" length:0];
                        output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding];
                        output = [output stringByAppendingString:@"\n... [truncated]"];
                    } else {
                        output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
                    }
                }
                remove(tmpPath); // 清理临时文件
                
                resp[@"success"] = @(WIFEXITED(status) && WEXITSTATUS(status) == 0);
                resp[@"output"] = output;
                resp[@"exitCode"] = @(WIFEXITED(status) ? WEXITSTATUS(status) : -1);
            }
        }
    }
    
    // ★ v5.7: openApp - 在主线程执行（UIKit/BackBoard操作）
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"bundleId required";
        } else {
            __block BOOL ok = NO;
            __block NSString *errMsg = @"no workspace";
            runOnMainThreadSync(^{
                Class wc = objc_getClass("LSApplicationWorkspace");
                if (wc) {
                    id ws = [wc performSelector:@selector(defaultWorkspace)];
                    if (ws) {
                        // ★ v5.7修复：openApplicationWithBundleID:返回BOOL(原始类型)
                        // 旧代码也用了objc_msgSend，但这里确认安全
                        ok = (BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), bid);
                        if (!ok) errMsg = @"openApplication returned NO";
                    } else {
                        errMsg = @"defaultWorkspace returned nil";
                    }
                }
            });
            resp[@"success"]=@(ok);
            if (!ok) resp[@"error"]=errMsg;
        }
    }
    
    // ★ v5.7: getScreenSize - 在主线程获取屏幕尺寸
    else if([action isEqualToString:@"getScreenSize"]) {
        CGRect b = getScreenBoundsSafe();
        CGFloat scale = getScreenScaleSafe();
        resp[@"success"]=@YES;
        resp[@"width"]=@(b.size.width);
        resp[@"height"]=@(b.size.height);
        resp[@"scale"]=@(scale);
    }
    
    // ★ v5.4: initDevice - 手动初始化虚拟设备（触摸+键盘）
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady ? @"OK" : @"FAILED";
        resp[@"virtualKeyboardDevice"]=g_virtualKeyboardReady ? @"OK" : @"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
        if (!g_virtualDeviceReady || !g_virtualKeyboardReady) {
            resp[@"hint"]=@"IOHIDUserDeviceCreate返回NULL通常因为缺少HID entitlements，v5.4已添加entitlements plist，请重新安装deb";
        }
    }
    
    // ★ v5.7: diagnose - 所有UIKit操作已通过getTargetContextID()等函数线程安全
    else if([action isEqualToString:@"diagnose"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        NSString *ctxSrc = SAFE_GET_GLOBAL(g_contextSource);
        NSString *frontApp = SAFE_GET_GLOBAL(g_frontmostApp);
        
        resp[@"success"]=@YES; 
        resp[@"diagnostics"]=@{
            @"version": @"5.9",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"BKHIDSystemInterface": (bksSharedInstance() != nil) ? @"OK":@"NULL",
            @"createDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"eventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@"OK":@"NULL",
            @"BKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@"OK":@"NULL",
            // ★ v5.2: IOHIDUserDevice
            @"IOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualKeyboardDevice": g_virtualKeyboardReady?@"OK":@"FAILED",
            @"virtualDeviceError": g_virtualDeviceError ?: @"",
            // ★ v5.4: shell命令状态
            @"shellCommand": @"OK",
            @"frontmostApp": frontApp ?: @"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": ctxSrc ?: @"none",
            // ★ v5.9: 派发路径
            @"dispatchPath": (bksSharedInstance() != nil) ? @"BKHIDSystemInterface":@"IOHIDEventSystemClient(fallback)",
        };
    }
    
    // ★ v5.7: validate - 所有UIKit操作已线程安全
    else if([action isEqualToString:@"validate"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        bool canInjectTouch = (BKSHIDEventSetDigitizerInfoFunc != NULL) && (frontmostCID != 0 || springCID != 0);
        
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"BKHIDSystemInterfaceAvailable": (bksSharedInstance() != nil) ? @YES:@NO,
            @"functionIOHIDEventCreateDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@YES:@NO,
            @"functionIOHIDEventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@YES:@NO,
            @"functionBKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@YES:@NO,
            // ★ v5.2: IOHIDUserDevice
            @"functionIOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@YES:@NO,
            @"functionIOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
            // ★ v5.9: BKS注入能力
            @"canInjectTouchToApp": @((bksSharedInstance() != nil)),
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

// ==================== SpringBoard Hook ====================

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动 v5.9 (BKHIDSystemInterface触摸注入修复)");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    NSLog(@"[StarCoreTweak] v5.9: BKHIDSystemInterface优先派发, 虚拟设备需手动调用initDevice");
}
%end

%ctor { %init; NSLog(@"[StarCoreTweak] v5.9 loading... (BKHIDSystemInterface触摸注入修复)"); }
%dtor { [_server stop]; }
