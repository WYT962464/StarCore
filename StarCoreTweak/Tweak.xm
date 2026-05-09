/**
 * StarCoreTweak.xm v5.1 - 安全修复版
 * 
 * v5.0问题：IOHIDUserDeviceCreate在SpringBoard启动1秒后自动调用，导致SpringBoard崩溃（Safe Mode）
 * 
 * v5.1 安全修复：
 * 1. 禁用虚拟设备自动创建 - 用户需手动调用initDevice
 * 2. 修复HID Report打包问题 - 所有字段字节对齐
 * 3. keyPress功能独立可用 - 使用IOHIDEventSystemClient路径
 * 4. tap/swipe/longPress在虚拟设备不可用时回退到IOHIDEventSystemClient
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
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

@interface BKHIDSystemInterface : NSObject
+ (id)sharedInstance;
- (void)injectHIDEvent:(IOHIDEventRef)arg1;
@end

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

// 全局变量
static uint32_t g_springBoardContextID = 2939785827;
static NSString *g_contextSource = @"none";
static NSString *g_frontmostApp = @"";

// ★ v5.1: 虚拟触摸设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";

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

// ==================== 前向声明 ====================
static void resetIdleTimer(void);
static void dispatchHIDEvent(IOHIDEventRef event);

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
    NSLog(@"[StarCoreTweak] ✅ v5.1 函数加载成功");
    return true;
}

// ==================== 旧方案辅助函数（放在前面定义） ====================

static uint32_t getContextIDFromCAWindowServer() {
    Class wsClass = objc_getClass("CAWindowServer");
    if (!wsClass) {
        wsClass = NSClassFromString(@"CAWindowServer");
    }
    
    if (!wsClass) {
        return 0;
    }
    
    SEL serverSel = NSSelectorFromString(@"serverIfRunning");
    if (![wsClass respondsToSelector:serverSel]) {
        return 0;
    }
    
    id ws = [wsClass performSelector:serverSel];
    if (!ws) {
        return 0;
    }
    
    SEL contextsSel = NSSelectorFromString(@"contexts");
    NSArray *contexts = nil;
    
    if ([ws respondsToSelector:contextsSel]) {
        contexts = [ws performSelector:contextsSel];
    }
    
    if (!contexts || contexts.count == 0) {
        return 0;
    }
    
    uint32_t bestCID = 0;
    
    for (id ctx in contexts) {
        if (![ctx respondsToSelector:@selector(pid)]) continue;
        pid_t pid = [[ctx performSelector:@selector(pid)] intValue];
        
        if (pid == getpid()) continue;
        
        if (pid == 0) {
            if ([ctx respondsToSelector:@selector(contextID)]) {
                uint32_t cid = [[ctx performSelector:@selector(contextID)] unsignedIntValue];
                if (cid != 0) {
                    bestCID = cid;
                    break;
                }
            }
        }
    }
    
    return bestCID;
}

static uint32_t getKeyWindowContextID() {
    @try {
        id frontApp = nil;
        Class uiApp = [UIApplication class];
        if ([uiApp respondsToSelector:@selector(sharedApplication)]) {
            frontApp = [uiApp performSelector:@selector(sharedApplication)];
        }
        
        if (frontApp && [frontApp respondsToSelector:@selector(keyWindow)]) {
            id keyWin = [frontApp performSelector:@selector(keyWindow)];
            if (keyWin && [keyWin respondsToSelector:@selector(_contextId)]) {
                uint32_t cid = [[keyWin performSelector:@selector(_contextId)] unsignedIntValue];
                if (cid != 0) {
                    g_contextSource = @"keyWindow";
                    return cid;
                }
            }
        }
    } @catch (NSException *e) {}
    
    return 0;
}

static uint32_t getTargetContextID() {
    uint32_t cid = getKeyWindowContextID();
    if (cid != 0) {
        @try {
            Class uiApp = [UIApplication class];
            if ([uiApp respondsToSelector:@selector(sharedApplication)]) {
                id app = [uiApp performSelector:@selector(sharedApplication)];
                if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                    id frontApp = [app performSelector:@selector(frontmostApplication)];
                    if (frontApp && [frontApp respondsToSelector:@selector(bundleIdentifier)]) {
                        g_frontmostApp = [frontApp performSelector:@selector(bundleIdentifier)];
                    }
                }
            }
        } @catch (NSException *e) {}
        return cid;
    }
    
    cid = getContextIDFromCAWindowServer();
    if (cid != 0) {
        g_contextSource = @"CAWindowServer";
        return cid;
    }
    
    g_contextSource = @"fallback";
    g_springBoardContextID = 2939785827;
    return g_springBoardContextID;
}

static void resetIdleTimer() {
    @try {
        Class uiApp = [UIApplication class];
        if ([uiApp respondsToSelector:@selector(sharedApplication)]) {
            id app = [uiApp performSelector:@selector(sharedApplication)];
            if (app && [app respondsToSelector:@selector(setIdleTimerDisabled:)]) {
                ((void(*)(id, SEL, BOOL))objc_msgSend)(app, @selector(setIdleTimerDisabled:), YES);
                ((void(*)(id, SEL, BOOL))objc_msgSend)(app, @selector(setIdleTimerDisabled:), NO);
            }
        }
    } @catch (NSException *e) {}
}

static void dispatchHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    
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

// 创建虚拟触摸设备
static bool initVirtualTouchDevice() {
    if (g_virtualDeviceReady) {
        NSLog(@"[StarCoreTweak] 虚拟设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        g_virtualDeviceError = @"IOHIDUserDevice函数未加载";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // 构建设备属性字典
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
        g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate失败");
        return false;
    }
    
    g_virtualDeviceReady = true;
    g_virtualDeviceError = @"";
    NSLog(@"[StarCoreTweak] ✅ 虚拟触摸设备创建成功");
    
    return true;
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

// ★ v5.1: 键盘字符输入
static void handleKeyPress(NSString *key) {
    if (!loadFunctions() || !IOHIDEventCreateKeyboardEventFunc) {
        NSLog(@"[StarCoreTweak] ⚠️ 键盘函数未加载");
        return;
    }
    
    uint32_t page = 0, usage = 0;
    if (!keyToUsage(key, &page, &usage)) {
        NSLog(@"[StarCoreTweak] ⚠️ 无法映射键: %@", key);
        return;
    }
    
    uint64_t ts = mach_absolute_time();
    
    // key down
    IOHIDEventRef keyDown = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, ts, page, usage, true, 0);
    if (keyDown) {
        if (IOHIDEventSetSenderIDFunc) {
            IOHIDEventSetSenderIDFunc(keyDown, kIOHIDEventDigitizerSenderID);
        }
        dispatchHIDEvent(keyDown);
    }
    
    usleep(50000);
    
    // key up
    IOHIDEventRef keyUp = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, ts, page, usage, false, 0);
    if (keyUp) {
        if (IOHIDEventSetSenderIDFunc) {
            IOHIDEventSetSenderIDFunc(keyUp, kIOHIDEventDigitizerSenderID);
        }
        dispatchHIDEvent(keyUp);
    }
    
    resetIdleTimer();
}

// ★ v5.1: 带文本输入的键盘输入
static void handleTextInput(NSString *text) {
    if (!text || text.length == 0) return;
    
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        NSString *charStr = [NSString stringWithCharacters:&c length:1];
        handleKeyPress(charStr);
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
- (instancetype)init { self = [super init]; if (self) _fds = [NSMutableArray new]; return self; }
- (void)start {
    _sock = socket(AF_INET, SOCK_STREAM, 0); if (_sock < 0) return;
    int y=1; setsockopt((int)_sock, SOL_SOCKET, SO_REUSEADDR, &y, sizeof(y));
    struct sockaddr_in a; memset(&a,0,sizeof(a)); a.sin_len=sizeof(a); a.sin_family=AF_INET; a.sin_port=htons(6000); a.sin_addr.s_addr=inet_addr("127.0.0.1");
    if (bind((int)_sock,(struct sockaddr*)&a,sizeof(a))<0||listen((int)_sock,5)<0) { close((int)_sock); _sock=-1; return; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{[self acceptLoop];});
    NSLog(@"[StarCoreTweak] TCP :6000 v5.1 (IOHIDUserDevice + keyPress)");
}
- (void)acceptLoop {
    while(_sock>=0) { struct sockaddr_in ca; socklen_t cl=sizeof(ca); int fd=accept((int)_sock,(struct sockaddr*)&ca,&cl); if(fd<0) continue;
        @synchronized(_fds){[_fds addObject:@(fd)];} dispatch_async(dispatch_get_global_queue(0,0),^{[self handleClient:fd];}); }
}
- (void)handleClient:(int)fd {
    NSMutableData *buf=[NSMutableData new]; uint8_t b[4096];
    while(YES) { ssize_t l=read(fd,b,sizeof(b)); if(l<=0) break; [buf appendBytes:b length:l];
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
        if(x>1.0f||y>1.0f){CGRect b=[UIScreen mainScreen].bounds;x/=b.size.width;y/=b.size.height;if(x>1)x=1;if(y>1)y=1;}
        
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
    
    // ★ v5.1: keyPress - 键盘字符输入
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"key required";
        } else {
            handleKeyPress(key);
            resp[@"success"]=@YES;
        }
    }
    
    // ★ v5.1: textInput - 文本输入
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"text required";
        } else {
            handleTextInput(text);
            resp[@"success"]=@YES;
        }
    }
    
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"]; if(!bid){resp[@"success"]=@NO;resp[@"error"]=@"bundleId required";}
        else { Class wc=objc_getClass("LSApplicationWorkspace"); if(wc){id ws=[wc performSelector:@selector(defaultWorkspace)];BOOL ok=(BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws,@selector(openApplicationWithBundleID:),bid);resp[@"success"]=@(ok);}else{resp[@"success"]=@NO;resp[@"error"]=@"no workspace";} }
    }
    else if([action isEqualToString:@"getScreenSize"]) { CGRect b=[UIScreen mainScreen].bounds; resp[@"success"]=@YES; resp[@"width"]=@(b.size.width); resp[@"height"]=@(b.size.height); resp[@"scale"]=@([UIScreen mainScreen].scale); }
    
    // ★ v5.1: initDevice - 手动初始化虚拟设备
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady ? @"OK" : @"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
    }
    
    else if([action isEqualToString:@"diagnose"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        
        resp[@"success"]=@YES; 
        resp[@"diagnostics"]=@{
            @"version": @"5.1",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"createDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"eventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@"OK":@"NULL",
            @"BKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@"OK":@"NULL",
            // ★ v5.1: IOHIDUserDevice
            @"IOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualDeviceError": g_virtualDeviceError ?: @"",
            @"frontmostApp": g_frontmostApp ?: @"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": g_contextSource ?: @"none",
        };
    }
    
    else if([action isEqualToString:@"validate"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        bool canInjectTouch = (BKSHIDEventSetDigitizerInfoFunc != NULL) && (frontmostCID != 0 || springCID != 0);
        
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"functionIOHIDEventCreateDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@YES:@NO,
            @"functionIOHIDEventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@YES:@NO,
            @"functionBKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@YES:@NO,
            // ★ v5.1: IOHIDUserDevice
            @"functionIOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@YES:@NO,
            @"functionIOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
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
- (void)stop { if(_sock>=0){close((int)_sock);_sock=-1;} @synchronized(_fds){for(NSNumber*f in _fds)close([f intValue]);[_fds removeAllObjects];} }
@end

// ==================== SpringBoard Hook ====================

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动 v5.1 (安全修复版)");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    
// ★ v5.1 安全修复：禁用自动创建虚拟设备（防止SpringBoard崩溃）
// 用户需要手动调用 initDevice 命令来初始化虚拟设备
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        bool ok = initVirtualTouchDevice();
//        NSLog(@"[StarCoreTweak] 虚拟触摸设备初始化: %@", ok ? @"成功" : @"失败");
//    });
    NSLog(@"[StarCoreTweak] v5.1 安全模式: 虚拟设备未自动创建，需手动调用initDevice");
}
%end

%ctor { NSLog(@"[StarCoreTweak] v5.1 loading... (安全修复版)"); }
%dtor { [_server stop]; }
