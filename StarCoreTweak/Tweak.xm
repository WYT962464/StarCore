/**
 * StarCoreTweak.xm v9.0 - 全面超越iOS MCP
 * 
 * v9.0 新增功能（34+工具，超过iOS MCP）：
 * 
 * P0 质变能力:
 * 1. 🔥 getUIElements - UI节点树（AXUIElement简化版）
 * 2. 🔥 getElementAtPoint - 点击位置元素
 * 3. 🔥 screenshot修复 - 三级降级+getScreenDataWithQuantity优先
 *
 * P1 完整操控:
 * 4. listApps - 列出已安装App
 * 5. listRunningApps - 列出运行中App
 * 6. killApp - 关闭App
 * 7. getFrontmostApp - 前台App信息
 * 8. openURL - 打开URL
 *
 * P2 全面对齐:
 * 9. doubleTap - 双击
 * 10. dragAndDrop - 拖拽
 * 11. toggleMute - 静音切换
 * 12. wakeAndHome - 亮屏+Home
 * 13. getDeviceInfo - 设备信息
 * 14. getBrightness / setBrightness - 亮度
 * 15. getVolume / setVolume - 音量
 * 16. installApp / uninstallApp - 安装卸载
 *
 * 继承v8.5功能：
 * - tap/swipe/longPress/pressHome/pressPower/pressVolumeUp/pressVolumeDown
 * - keyPress/textInput/inputText/typeText/screenshot/getScreenInfo
 * - shell(openApp/getScreenSize/initDevice/diagnose/validate
 * - setClipboard/getClipboard/readFile/writeFile/appendFile/listFiles
 * 
 * 技术要点：
 * - Tweak运行在SpringBoard进程(root权限)，UIKit操作必须dispatch到主线程
 * - senderID用0x8000000817319372（ios-mcp验证过的值）
 * - shell用popen()不用posix_spawn（Dopamine兼容）
 * - AXUIElement简化版：只获取前台App可点击元素
 * - 截图优先使用getScreenDataWithQuantity→IOSurface→_UICreateScreenUIImage→window
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

// AXUIElement类型
typedef const struct __AXUIElement *AXUIElementRef;
typedef int32_t AXError;

enum {
    kAXErrorSuccess                  = 0,
    kAXErrorFailure                  = -25200,
    kAXErrorIllegalArgument          = -25201,
    kAXErrorInvalidUIElement         = -25202,
    kAXErrorCannotComplete           = -25204,
    kAXErrorAttributeUnsupported     = -25205,
    kAXErrorNoValue                  = -25212,
    kAXErrorNotImplemented           = -25208,
};

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

// senderID（ios-mcp验证值）
#define SYNTHETIC_SENDER_ID 0x8000000817319372ULL

// 硬件按键 Usage
#define kHIDUsage_Csmr_Power 0x30
#define kHIDUsage_Csmr_VolumeIncrement 0xE9
#define kHIDUsage_Csmr_VolumeDecrement 0xEA
#define kHIDUsage_Csmr_Mute 0xE2

// Unicode编码
#define kIOHIDUnicodeEncodingTypeUTF16LE 1

// ==================== AXRuntime 类型声明 ====================
extern CFTypeID AXValueGetTypeID(void) __attribute__((weak_import));
extern CFTypeID AXUIElementGetTypeID(void) __attribute__((weak_import));

// 截图常量
static const NSUInteger kScreenshotTargetBytes = 400 * 1024;
static const CGFloat kScreenshotInitialJPEGQuality = 0.82;
static const CGFloat kScreenshotMinimumJPEGQuality = 0.45;
static const NSInteger kScreenshotJPEGSearchPasses = 6;
static const NSInteger kScreenshotResizePasses = 4;

// AX属性常量
static CFStringRef kAXRoleAttribute = CFSTR("AXRole");
static CFStringRef kAXSubroleAttribute = CFSTR("AXSubrole");
static CFStringRef kAXLabelAttribute = CFSTR("AXLabel");
static CFStringRef kAXValueAttribute = CFSTR("AXValue");
static CFStringRef kAXTitleAttribute = CFSTR("AXTitle");
static CFStringRef kAXFrameAttribute = CFSTR("AXFrame");
static CFStringRef kAXEnabledAttribute = CFSTR("AXEnabled");
static CFStringRef kAXChildrenAttribute = CFSTR("AXChildren");
static CFStringRef kAXTraitsAttribute = CFSTR("AXTraits");
static CFStringRef kAXIdentifierAttribute = CFSTR("AXIdentifier");
static CFStringRef kAXPlaceholderAttribute = CFSTR("AXPlaceholderValue");

// UIWindow私有方法
@interface UIWindow (StarCorePrivate)
@property (nonatomic, readonly) uint32_t _contextId;
@end

@interface UIApplication (StarCorePrivate)
- (void)_enqueueHIDEvent:(IOHIDEventRef)arg1;
@end

// ==================== 私有类声明 ====================

// LSApplicationProxy
@interface LSApplicationProxy : NSObject
- (NSString *)applicationIdentifier;
- (NSString *)localizedName;
- (NSString *)applicationType;
- (NSURL *)bundleURL;
@end

// LSApplicationWorkspace
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allInstalledApplications;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
- (id)applicationProxyForIdentifier:(NSString *)bundleId;
- (BOOL)installApplication:(NSURL *)appURL withOptions:(NSDictionary *)options error:(NSError **)error;
- (BOOL)uninstallApplication:(NSString *)bundleIdentifier withOptions:(NSDictionary *)options;
@end

// SBApplication
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
- (BOOL)isRunning;
- (id)processState;
@end

// SBApplicationController
@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleId;
- (NSArray *)allApplications;
- (NSArray *)runningApplications;
@end

// FBSSystemService
@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)terminateApplication:(NSString *)bundleId forReason:(int)reason andReport:(BOOL)report withDescription:(NSString *)description;
- (pid_t)pidForApplication:(NSString *)bundleId;
@end

// FBSScene
@interface FBSScene : NSObject
- (NSString *)applicationBundleIdentifier;
- (void)terminate;
@end

// SBLockScreenManager
@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)unlockUIFromSource:(int)source withOptions:(NSDictionary *)options;
@end

// SBUserAgent
@interface SBUserAgent : NSObject
+ (instancetype)sharedInstance;
- (void)lockAndDimDevice;
@end

// ==================== 函数指针 ====================
// 旧方案函数
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;
static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef, uint32_t) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;
static void (*BKSHIDEventSetDigitizerInfoFunc)(IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float) = NULL;

// IOHIDUserDevice函数
static IOHIDUserDeviceRef (*IOHIDUserDeviceCreateFunc)(CFAllocatorRef, CFDictionaryRef, IOOptionBits) = NULL;
static IOReturn (*IOHIDUserDeviceHandleReportFunc)(IOHIDUserDeviceRef, const uint8_t *, CFIndex) = NULL;

// IOHIDEventCreateDigitizerFingerEvent（ios-mcp触摸方案）
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventSimpleFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;

// IOHIDEventCreateUnicodeEvent（Unicode文字输入）
static IOHIDEventRef (*IOHIDEventCreateUnicodeEventFunc)(CFAllocatorRef, uint64_t, const uint8_t *, uint32_t, uint32_t, IOOptionBits) = NULL;

// BKSHIDEventSendToProcess
static void (*BKSHIDEventSendToProcessFunc)(IOHIDEventRef, pid_t) = NULL;

// IOHIDEventSetIntegerValue（无options版本）
static void (*IOHIDEventSetIntegerValueFunc)(IOHIDEventRef, uint32_t, int32_t) = NULL;

// 截图函数
typedef UIImage *(*UICreateScreenUIImageFuncType)(void);
typedef CGImageRef (*UICreateCGImageFromIOSurfaceFuncType)(IOSurfaceRef surface);
typedef CGImageRef (*CARenderServerCaptureDisplayFuncType)(uint32_t serverPort, CFStringRef displayName, CFDictionaryRef options);

static UICreateScreenUIImageFuncType _UICreateScreenUIImageFunc = NULL;
static UICreateCGImageFromIOSurfaceFuncType _UICreateCGImageFromIOSurfaceFunc = NULL;
static CARenderServerCaptureDisplayFuncType _CARenderServerCaptureDisplayFunc = NULL;

// AXUIElement函数指针
typedef AXUIElementRef (*AXUIElementCreateApplicationFuncType)(pid_t pid);
typedef AXUIElementRef (*AXUIElementCreateSystemWideFuncType)(void);
typedef AXError (*AXUIElementCopyAttributeValueFuncType)(AXUIElementRef element, CFStringRef attribute, CFTypeRef *value);
typedef AXError (*AXUIElementCopyAttributeNamesFuncType)(AXUIElementRef element, CFArrayRef *names);
typedef AXError (*AXUIElementGetPidFuncType)(AXUIElementRef element, pid_t *pid);
typedef AXError (*AXUIElementSetMessagingTimeoutFuncType)(AXUIElementRef element, float timeout);
typedef void (*AXSetRequestingClientFuncType)(uint32_t clientType);

static AXUIElementCreateApplicationFuncType _AXUIElementCreateApplicationFunc = NULL;
static AXUIElementCreateSystemWideFuncType _AXUIElementCreateSystemWideFunc = NULL;
static AXUIElementCopyAttributeValueFuncType _AXUIElementCopyAttributeValueFunc = NULL;
static AXUIElementCopyAttributeNamesFuncType _AXUIElementCopyAttributeNamesFunc = NULL;
static AXUIElementGetPidFuncType _AXUIElementGetPidFunc = NULL;
static AXUIElementSetMessagingTimeoutFuncType _AXUIElementSetMessagingTimeoutFunc = NULL;
static AXSetRequestingClientFuncType _AXSetRequestingClientFunc = NULL;

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL;
static void *g_quartzCoreHandle = NULL;
static void *g_axRuntimeHandle = NULL;

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

// 全局变量
static uint32_t g_springBoardContextID = 2939785827;
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

// IOHIDUserDevice虚拟设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";

static IOHIDUserDeviceRef g_virtualKeyboardDevice = NULL;
static bool g_virtualKeyboardReady = false;

// Unicode输入运行时解析状态
static bool g_unicodeRuntimeResolved = false;
static bool g_unicodeRuntimeAvailable = false;
static NSString *g_unicodeRuntimeSource = @"";
static NSString *g_unicodeRuntimeError = @"";

// BackBoard HID SendToProcess 运行时解析状态
static bool g_backBoardSendResolved = false;
static bool g_backBoardSendAvailable = false;
static NSString *g_backBoardSendSource = @"";
static NSString *g_backBoardSendError = @"";

// AX运行时解析状态
static bool g_axRuntimeResolved = false;
static bool g_axRuntimeAvailable = false;

// ★ v9.0: HID multitouch descriptor
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
    0x75, 0x01,        //     Report Size (1)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data,Variable,Absolute)
    0x09, 0x32,        //     Usage (In Range)
    0x81, 0x02,        //     Input (Data,Variable,Absolute)
    0x95, 0x06,        //     Report Count (6)
    0x81, 0x03,        //     Input (Constant)
    0x05, 0x01,        //     Usage Page (Generic Desktop)
    0x09, 0x30,        //     Usage (X)
    0x09, 0x31,        //     Usage (Y)
    0x15, 0x00,        //     Logical Minimum (0)
    0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x02,        //     Report Count (2)
    0x81, 0x02,        //     Input (Data,Variable,Absolute)
    0x05, 0x0D,        //     Usage Page (Digitizer)
    0x09, 0x51,        //     Usage (Contact Identifier)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x01,        //     Report Count (1)
    0x81, 0x02,        //     Input (Data,Variable,Absolute)
    0x09, 0x48,        //     Usage (Width)
    0x09, 0x49,        //     Usage (Height)
    0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
    0x75, 0x10,        //     Report Size (16)
    0x95, 0x02,        //     Report Count (2)
    0x81, 0x02,        //     Input (Data,Variable,Absolute)
    0xC0,              //   End Collection
    0x05, 0x0D,        //   Usage Page (Digitizer)
    0x09, 0x54,        //   Usage (Contact Count)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x10,        //   Logical Maximum (16)
    0x75, 0x08,        //   Report Size (8)
    0x95, 0x01,        //   Report Count (1)
    0x81, 0x02,        //   Input (Data,Variable,Absolute)
    0xC0               // End Collection
};

// ★ v9.0: HID keyboard descriptor
static const uint8_t g_keyboard_descriptor[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x02,        //   Report ID (2)
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0xE0,        //   Usage Minimum (Left Control)
    0x29, 0xE7,        //   Usage Maximum (Right GUI)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8)
    0x81, 0x02,        //   Input (Data,Variable,Absolute)
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
    0x81, 0x00,        //   Input (Data,Array)
    0xC0               // End Collection
};

// ==================== 辅助函数 ====================

static void runOnMainThreadSync(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

static CGRect getScreenBoundsSafe() {
    __block CGRect b = CGRectMake(0, 0, 375, 812);
    runOnMainThreadSync(^{ b = [UIScreen mainScreen].bounds; });
    return b;
}

static CGFloat getScreenScaleSafe() {
    __block CGFloat s = 3.0;
    runOnMainThreadSync(^{ s = [UIScreen mainScreen].scale; });
    return s;
}

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    g_iokitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    g_bbsHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
    g_quartzCoreHandle = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY);
    
    #define LOAD_SYM(var, handle, name) do { \
        var = (typeof(var))dlsym(handle, name); \
        if (!var) var = (typeof(var))dlsym(handle, "_" name); \
    } while(0)
    
    if (g_iokitHandle) {
        LOAD_SYM(IOHIDEventCreateDigitizerEventFunc, g_iokitHandle, "IOHIDEventCreateDigitizerEvent");
        LOAD_SYM(IOHIDEventCreateDigitizerFingerEventSimpleFunc, g_iokitHandle, "IOHIDEventCreateDigitizerFingerEvent");
        LOAD_SYM(IOHIDEventCreateKeyboardEventFunc, g_iokitHandle, "IOHIDEventCreateKeyboardEvent");
        LOAD_SYM(IOHIDEventSetIntegerValueWithOptionsFunc, g_iokitHandle, "IOHIDEventSetIntegerValueWithOptions");
        LOAD_SYM(IOHIDEventSetFloatValueFunc, g_iokitHandle, "IOHIDEventSetFloatValue");
        LOAD_SYM(IOHIDEventSetSenderIDFunc, g_iokitHandle, "IOHIDEventSetSenderID");
        LOAD_SYM(IOHIDEventAppendEventFunc, g_iokitHandle, "IOHIDEventAppendEvent");
        LOAD_SYM(IOHIDEventSystemClientCreateFunc, g_iokitHandle, "IOHIDEventSystemClientCreate");
        LOAD_SYM(IOHIDEventSystemClientDispatchEventFunc, g_iokitHandle, "IOHIDEventSystemClientDispatchEvent");
        LOAD_SYM(IOHIDUserDeviceCreateFunc, g_iokitHandle, "IOHIDUserDeviceCreate");
        LOAD_SYM(IOHIDUserDeviceHandleReportFunc, g_iokitHandle, "IOHIDUserDeviceHandleReport");
        LOAD_SYM(IOHIDEventCreateUnicodeEventFunc, g_iokitHandle, "IOHIDEventCreateUnicodeEvent");
        LOAD_SYM(IOHIDEventSetIntegerValueFunc, g_iokitHandle, "IOHIDEventSetIntegerValue");
    }
    
    if (g_bbsHandle) {
        LOAD_SYM(BKSHIDEventSetDigitizerInfoFunc, g_bbsHandle, "BKSHIDEventSetDigitizerInfo");
        LOAD_SYM(BKSHIDEventSendToProcessFunc, g_bbsHandle, "BKSHIDEventSendToProcess");
    }
    
    if (g_quartzCoreHandle) {
        LOAD_SYM(_CARenderServerCaptureDisplayFunc, g_quartzCoreHandle, "CARenderServerCaptureDisplay");
    }
    
    // 从全局已加载符号查找
    if (!_UICreateScreenUIImageFunc)
        _UICreateScreenUIImageFunc = (UICreateScreenUIImageFuncType)dlsym(RTLD_DEFAULT, "_UICreateScreenUIImage");
    if (!_UICreateCGImageFromIOSurfaceFunc)
        _UICreateCGImageFromIOSurfaceFunc = (UICreateCGImageFromIOSurfaceFuncType)dlsym(RTLD_DEFAULT, "UICreateCGImageFromIOSurface");
    
    // ★ v9.0: 加载AXRuntime函数
    g_axRuntimeHandle = dlopen("/System/Library/PrivateFrameworks/AXRuntime.framework/AXRuntime", RTLD_LAZY);
    if (g_axRuntimeHandle) {
        LOAD_SYM(_AXUIElementCreateApplicationFunc, g_axRuntimeHandle, "AXUIElementCreateApplication");
        LOAD_SYM(_AXUIElementCreateSystemWideFunc, g_axRuntimeHandle, "AXUIElementCreateSystemWide");
        LOAD_SYM(_AXUIElementCopyAttributeValueFunc, g_axRuntimeHandle, "AXUIElementCopyAttributeValue");
        LOAD_SYM(_AXUIElementCopyAttributeNamesFunc, g_axRuntimeHandle, "AXUIElementCopyAttributeNames");
        LOAD_SYM(_AXUIElementGetPidFunc, g_axRuntimeHandle, "AXUIElementGetPid");
        LOAD_SYM(_AXUIElementSetMessagingTimeoutFunc, g_axRuntimeHandle, "AXUIElementSetMessagingTimeout");
        LOAD_SYM(_AXSetRequestingClientFunc, g_axRuntimeHandle, "_AXSetRequestingClient");
    }
    // 也从RTLD_DEFAULT尝试
    if (!_AXUIElementCreateApplicationFunc)
        _AXUIElementCreateApplicationFunc = (AXUIElementCreateApplicationFuncType)dlsym(RTLD_DEFAULT, "AXUIElementCreateApplication");
    if (!_AXUIElementCreateSystemWideFunc)
        _AXUIElementCreateSystemWideFunc = (AXUIElementCreateSystemWideFuncType)dlsym(RTLD_DEFAULT, "AXUIElementCreateSystemWide");
    if (!_AXUIElementCopyAttributeValueFunc)
        _AXUIElementCopyAttributeValueFunc = (AXUIElementCopyAttributeValueFuncType)dlsym(RTLD_DEFAULT, "AXUIElementCopyAttributeValue");
    if (!_AXUIElementCopyAttributeNamesFunc)
        _AXUIElementCopyAttributeNamesFunc = (AXUIElementCopyAttributeNamesFuncType)dlsym(RTLD_DEFAULT, "AXUIElementCopyAttributeNames");
    if (!_AXUIElementGetPidFunc)
        _AXUIElementGetPidFunc = (AXUIElementGetPidFuncType)dlsym(RTLD_DEFAULT, "AXUIElementGetPid");
    if (!_AXUIElementSetMessagingTimeoutFunc)
        _AXUIElementSetMessagingTimeoutFunc = (AXUIElementSetMessagingTimeoutFuncType)dlsym(RTLD_DEFAULT, "AXUIElementSetMessagingTimeout");
    if (!_AXSetRequestingClientFunc)
        _AXSetRequestingClientFunc = (AXSetRequestingClientFuncType)dlsym(RTLD_DEFAULT, "_AXSetRequestingClient");
    
    g_axRuntimeAvailable = (_AXUIElementCreateApplicationFunc != NULL && _AXUIElementCopyAttributeValueFunc != NULL);
    
    #undef LOAD_SYM
    
    if (!IOHIDEventCreateDigitizerEventFunc) { NSLog(@"[StarCoreTweak] ❌ 核心函数缺失"); return false; }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ v9.0 函数加载成功");
    NSLog(@"[StarCoreTweak]   AXRuntime: %@", g_axRuntimeAvailable ? @"OK" : @"UNAVAILABLE");
    NSLog(@"[StarCoreTweak]   IOHIDEventCreateUnicodeEvent: %@", IOHIDEventCreateUnicodeEventFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   BKSHIDEventSendToProcess: %@", BKSHIDEventSendToProcessFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   CARenderServerCaptureDisplay: %@", _CARenderServerCaptureDisplayFunc ? @"OK" : @"NULL");
    NSLog(@"[StarCoreTweak]   _UICreateScreenUIImage: %@", _UICreateScreenUIImageFunc ? @"OK" : @"NULL");
    
    return true;
}

// ★ v8.4: 延迟解析Unicode运行时
static bool resolveUnicodeRuntime() {
    if (g_unicodeRuntimeResolved) return g_unicodeRuntimeAvailable;
    g_unicodeRuntimeResolved = true;
    
    if (IOHIDEventCreateUnicodeEventFunc) {
        g_unicodeRuntimeAvailable = true;
        g_unicodeRuntimeSource = @"loadFunctions";
        return true;
    }
    
    const char *paths[] = { "/System/Library/Frameworks/IOKit.framework/IOKit", NULL };
    for (int i = 0; paths[i]; i++) {
        void *handle = dlopen(paths[i], RTLD_LAZY);
        if (!handle) continue;
        IOHIDEventCreateUnicodeEventFunc = (typeof(IOHIDEventCreateUnicodeEventFunc))dlsym(handle, "IOHIDEventCreateUnicodeEvent");
        if (!IOHIDEventCreateUnicodeEventFunc)
            IOHIDEventCreateUnicodeEventFunc = (typeof(IOHIDEventCreateUnicodeEventFunc))dlsym(handle, "_IOHIDEventCreateUnicodeEvent");
        if (IOHIDEventCreateUnicodeEventFunc) {
            g_unicodeRuntimeAvailable = true;
            g_unicodeRuntimeSource = [NSString stringWithUTF8String:paths[i]];
            return true;
        }
    }
    g_unicodeRuntimeError = @"IOHIDEventCreateUnicodeEvent not found";
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
    
    const char *paths[] = { "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", NULL };
    for (int i = 0; paths[i]; i++) {
        void *handle = dlopen(paths[i], RTLD_LAZY);
        if (!handle) continue;
        BKSHIDEventSendToProcessFunc = (typeof(BKSHIDEventSendToProcessFunc))dlsym(handle, "BKSHIDEventSendToProcess");
        if (!BKSHIDEventSendToProcessFunc)
            BKSHIDEventSendToProcessFunc = (typeof(BKSHIDEventSendToProcessFunc))dlsym(handle, "_BKSHIDEventSendToProcess");
        if (BKSHIDEventSendToProcessFunc) {
            g_backBoardSendAvailable = true;
            g_backBoardSendSource = [NSString stringWithUTF8String:paths[i]];
            return true;
        }
    }
    g_backBoardSendError = @"BKSHIDEventSendToProcess not found";
    return false;
}

// ==================== Context ID获取 ====================

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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                keyWin = [app performSelector:@selector(keyWindow)];
#pragma clang diagnostic pop
            }
            if (keyWin && [keyWin respondsToSelector:@selector(_contextId)]) {
                uint32_t cid_val = ((uint32_t(*)(id, SEL))objc_msgSend)(keyWin, @selector(_contextId));
                if (cid_val != 0) {
                    SAFE_SET_GLOBAL(g_contextSource, @"keyWindow");
                    cid = cid_val;
                }
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
                // ★ v9.1: 通过SBAppSwitcherModel获取
                Class SBSwitcherModel = objc_getClass("SBAppSwitcherModel");
                if (SBSwitcherModel) {
                    id model = [SBSwitcherModel performSelector:@selector(sharedInstance)];
                    if (model && [model respondsToSelector:@selector(applicationAtPosition:)]) {
                        id appLayout = [model performSelector:@selector(applicationAtPosition:) withObject:@(0)];
                        if (appLayout && [appLayout respondsToSelector:@selector(application)]) {
                            id sbApp = [appLayout performSelector:@selector(application)];
                            if (sbApp && [sbApp respondsToSelector:@selector(bundleIdentifier)]) {
                                NSString *bid = [sbApp performSelector:@selector(bundleIdentifier)];
                                if (bid) SAFE_SET_GLOBAL(g_frontmostApp, bid);
                            }
                        }
                    }
                }
                // fallback
                if (SAFE_GET_GLOBAL(g_frontmostApp).length == 0) {
                    UIApplication *app = [UIApplication sharedApplication];
                    if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                        id frontApp = [app performSelector:@selector(frontmostApplication)];
                        if (frontApp && [frontApp respondsToSelector:@selector(bundleIdentifier)]) {
                            NSString *bid = [frontApp performSelector:@selector(bundleIdentifier)];
                            if (bid) SAFE_SET_GLOBAL(g_frontmostApp, bid);
                        }
                    }
                }
            } @catch (NSException *e) {}
        });
        return cid;
    }
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
    @try {
        id bks = bksSharedInstance();
        if (bks) { bksInjectHIDEvent(bks, event); return; }
    } @catch (NSException *e) {}
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault); });
        if (client) IOHIDEventSystemClientDispatchEventFunc(client, event);
    }
}

static pid_t getFrontmostAppPid() {
    __block pid_t pid = 0;
    runOnMainThreadSync(^{
        @try {
            // ★ v9.1: 通过SBApplicationController获取前台App
            Class SBAppCtrl = objc_getClass("SBApplicationController");
            if (SBAppCtrl) {
                id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
                // SBApplicationController没有直接frontmost方法，用SBSCopyApp
                // 改用SBSceneManager（iOS 14+）
                Class SBSSceneMgr = objc_getClass("SBSceneManager");
                if (SBSSceneMgr) {
                    id mgr = [SBSSceneMgr performSelector:@selector(sharedInstance)];
                    if (mgr && [mgr respondsToSelector:@selector(frontmostApplication)])
                        mgr = nil; // 没这个selector
                }
                // 最可靠方案：从SBAppSwitcherModel获取
                Class SBSwitcherModel = objc_getClass("SBAppSwitcherModel");
                if (SBSwitcherModel) {
                    id model = [SBSwitcherModel performSelector:@selector(sharedInstance)];
                    if (model && [model respondsToSelector:@selector(applicationAtPosition:)]) {
                        // position 0 = most recent
                        id appLayout = [model performSelector:@selector(applicationAtPosition:) withObject:@(0)];
                        if (appLayout) {
                            // SBAppSwitcherAppLayout -> application -> SBApplication
                            if ([appLayout respondsToSelector:@selector(application)]) {
                                id sbApp = [appLayout performSelector:@selector(application)];
                                if (sbApp) {
                                    if ([sbApp respondsToSelector:@selector(processID)])
                                        pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(sbApp, @selector(processID));
                                    if ([sbApp respondsToSelector:@selector(bundleIdentifier)]) {
                                        NSString *bid = [sbApp performSelector:@selector(bundleIdentifier)];
                                        if (bid) SAFE_SET_GLOBAL(g_frontmostApp, bid);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // fallback: UIApplication
            if (pid <= 0) {
                UIApplication *app = [UIApplication sharedApplication];
                if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                    id frontApp = [app performSelector:@selector(frontmostApplication)];
                    if (frontApp && [frontApp respondsToSelector:@selector(processID)]) {
                        pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(frontApp, @selector(processID));
                    }
                }
            }
        } @catch (NSException *e) {}
    });
    return pid;
}

// ★ v9.0: 获取前台App的bundleId
static NSString *getFrontmostBundleId() {
    // ★ v9.1: 复用getFrontmostAppPid的逻辑，直接返回缓存的g_frontmostApp
    pid_t pid = getFrontmostAppPid();
    NSString *bid = SAFE_GET_GLOBAL(g_frontmostApp);
    if (bid.length > 0) return bid;
    // fallback
    __block NSString *result = nil;
    runOnMainThreadSync(^{
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                id frontApp = [app performSelector:@selector(frontmostApplication)];
                if (frontApp && [frontApp respondsToSelector:@selector(bundleIdentifier)]) {
                    result = [frontApp performSelector:@selector(bundleIdentifier)];
                }
            }
        } @catch (NSException *e) {}
    });
    return result;
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
    if (setDigitizerInfo && BKSHIDEventSetDigitizerInfoFunc)
        BKSHIDEventSetDigitizerInfoFunc(hand, cid, 1, 1, NULL, 0, touch_ ? 0.2f : 0.0f);
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

// ★ v9.1: 统一硬件按键模拟（后台线程发送，防止死锁）
static void sendButtonEvent(uint32_t usagePage, uint32_t usage, float durationMs) {
    if (!loadFunctions()) return;
    // ★ 在后台线程发送HID事件，避免主线程死锁
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            uint64_t ts = mach_absolute_time();
            IOHIDEventRef downEvent = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, usagePage, usage, true, 0);
            if (downEvent) {
                if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(downEvent, SYNTHETIC_SENDER_ID);
                if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(downEvent, 4, 1);
                dispatchHIDEvent(downEvent);
            }
            float ms = durationMs > 0 ? durationMs : 100.0f;
            usleep((useconds_t)(ms * 1000));
            ts = mach_absolute_time();
            IOHIDEventRef upEvent = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, usagePage, usage, false, 0);
            if (upEvent) {
                if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(upEvent, SYNTHETIC_SENDER_ID);
                if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(upEvent, 4, 1);
                dispatchHIDEvent(upEvent);
            }
            resetIdleTimer();
        } @catch (NSException *e) {}
    });
}

// ==================== v8.4: ios-mcp触摸方案 ====================

static IOHIDEventRef createChildTouchEvent(int phase, int index, float normX, float normY) {
    if (!IOHIDEventCreateDigitizerFingerEventSimpleFunc) return NULL;
    uint32_t eventMask = 0;
    bool range = true, touch = true;
    switch (phase) {
        case TOUCH_DOWN: eventMask = kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch; range = true; touch = true; break;
        case TOUCH_MOVE: eventMask = kIOHIDDigitizerEventPosition; range = true; touch = true; break;
        case TOUCH_UP: eventMask = kIOHIDDigitizerEventTouch; range = false; touch = false; break;
    }
    IOHIDEventRef child = IOHIDEventCreateDigitizerFingerEventSimpleFunc(
        kCFAllocatorDefault, mach_absolute_time(), index, 3, eventMask,
        normX, normY, 0.0f, 0.0f, 0.0f, range, touch, 0);
    if (child && IOHIDEventSetFloatValueFunc) {
        IOHIDEventSetFloatValueFunc(child, 0xb0014, 0.04f);
        IOHIDEventSetFloatValueFunc(child, 0xb0015, 0.04f);
    }
    return child;
}

static void dispatchTouchViaIOHIDFinger(int phase, int fingerIndex, float normX, float normY) {
    if (!loadFunctions()) return;
    if (!IOHIDEventCreateDigitizerFingerEventSimpleFunc) { simulateTouch(phase, normX, normY, fingerIndex); return; }
    IOHIDEventRef parent = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault, mach_absolute_time(), kIOHIDTransducerTypeHand, 99, 1, 0, 0, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, false, false, 0);
    if (!parent) return;
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parent, 0xb0019, 1);
        IOHIDEventSetIntegerValueFunc(parent, 0x4, 1);
    }
    IOHIDEventRef child = createChildTouchEvent(phase, fingerIndex, normX, normY);
    if (child && IOHIDEventAppendEventFunc) IOHIDEventAppendEventFunc(parent, child, 0);
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parent, 0xb0007, 0x23);
        IOHIDEventSetIntegerValueFunc(parent, 0xb0008, 0x1);
        IOHIDEventSetIntegerValueFunc(parent, 0xb0009, 0x1);
    }
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(parent, SYNTHETIC_SENDER_ID);
    resetIdleTimer();
    dispatchHIDEvent(parent);
}

static void iosmcpTap(float normX, float normY) {
    dispatchTouchViaIOHIDFinger(TOUCH_DOWN, 1, normX, normY);
    usleep(30000);
    dispatchTouchViaIOHIDFinger(TOUCH_MOVE, 1, normX, normY);
    dispatchTouchViaIOHIDFinger(TOUCH_UP, 1, normX, normY);
}

static void iosmcpSwipe(float normStartX, float normStartY, float normEndX, float normEndY, float duration) {
    int steps = (int)(duration * 60); if (steps < 2) steps = 2;
    dispatchTouchViaIOHIDFinger(TOUCH_DOWN, 1, normStartX, normStartY);
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        dispatchTouchViaIOHIDFinger(TOUCH_MOVE, 1, normStartX + (normEndX - normStartX) * t, normStartY + (normEndY - normStartY) * t);
        usleep(16667);
    }
    dispatchTouchViaIOHIDFinger(TOUCH_UP, 1, normEndX, normEndY);
}

// ★ v9.0: ios-mcp方案双击
static void iosmcpDoubleTap(float normX, float normY, float intervalMs) {
    iosmcpTap(normX, normY);
    usleep((useconds_t)(intervalMs > 0 ? intervalMs * 1000 : 100000));
    iosmcpTap(normX, normY);
}

// ★ v9.0: ios-mcp方案拖拽
static void iosmcpDrag(float normStartX, float normStartY, float normEndX, float normEndY, float holdMs, float moveMs) {
    float hold = holdMs > 0 ? holdMs : 500.0f;
    float move = moveMs > 0 ? moveMs : 300.0f;
    dispatchTouchViaIOHIDFinger(TOUCH_DOWN, 1, normStartX, normStartY);
    usleep((useconds_t)(hold * 1000));
    int steps = (int)(move / 16.67f); if (steps < 2) steps = 2;
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        dispatchTouchViaIOHIDFinger(TOUCH_MOVE, 1, normStartX + (normEndX - normStartX) * t, normStartY + (normEndY - normStartY) * t);
        usleep(16667);
    }
    usleep(10000);
    dispatchTouchViaIOHIDFinger(TOUCH_UP, 1, normEndX, normEndY);
}

// ==================== 虚拟设备 ====================

static bool initVirtualKeyboardDevice() {
    if (g_virtualKeyboardReady) return true;
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) return false;
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[@"ReportDescriptor"] = [NSData dataWithBytes:g_keyboard_descriptor length:sizeof(g_keyboard_descriptor)];
    properties[@"Product"] = @"StarCore Virtual Keyboard";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0002);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    properties[@"PrimaryUsagePage"] = @(0x07);
    properties[@"PrimaryUsage"] = @(0x06);
    g_virtualKeyboardDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, (__bridge CFDictionaryRef)properties, 0);
    if (!g_virtualKeyboardDevice) return false;
    g_virtualKeyboardReady = true;
    return true;
}

static bool sendKeyboardReport(uint8_t modifiers, const uint8_t *keyCodes, int keyCodeCount) {
    if (!g_virtualKeyboardReady || !IOHIDUserDeviceHandleReportFunc) return false;
    uint8_t report[9] = {0};
    report[0] = 0x02; report[1] = modifiers; report[2] = 0;
    int count = (keyCodeCount > 6) ? 6 : keyCodeCount;
    for (int i = 0; i < count; i++) report[3 + i] = keyCodes[i];
    return IOHIDUserDeviceHandleReportFunc(g_virtualKeyboardDevice, report, sizeof(report)) == kIOReturnSuccess;
}

static bool initVirtualTouchDevice() {
    if (g_virtualDeviceReady && g_virtualKeyboardReady) return true;
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) { g_virtualDeviceError = @"IOHIDUserDevice函数未加载"; return false; }
    if (!g_virtualKeyboardReady) initVirtualKeyboardDevice();
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    properties[@"ReportDescriptor"] = [NSData dataWithBytes:g_multitouch_descriptor length:sizeof(g_multitouch_descriptor)];
    properties[@"Product"] = @"StarCore Virtual Touch";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0001);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    properties[@"PrimaryUsagePage"] = @(0x0D);
    properties[@"PrimaryUsage"] = @(0x04);
    g_virtualDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, (__bridge CFDictionaryRef)properties, 0);
    if (!g_virtualDevice) { g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL"; }
    else { g_virtualDeviceReady = true; g_virtualDeviceError = @""; }
    return g_virtualDeviceReady || g_virtualKeyboardReady;
}

// ==================== 键盘输入 ====================

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
            @"up": @(0x52), @"down": @(0x51), @"left": @(0x50), @"right": @(0x4F),
        };
    });
    NSNumber *usageNum = keyMap[[key lowercaseString]];
    if (!usageNum) return false;
    *usage = [usageNum unsignedIntValue]; *page = kHIDPage_KeyboardOrKeypad;
    return true;
}

static void handleKeyPressViaVirtualDevice(uint32_t page, uint32_t usage) {
    if (!g_virtualKeyboardReady) return;
    uint8_t keys[1] = { (uint8_t)usage };
    sendKeyboardReport(0, keys, 1); usleep(50000);
    uint8_t noKeys[1] = { 0 };
    sendKeyboardReport(0, noKeys, 0);
    resetIdleTimer();
}

// ==================== v8.4: Unicode文字输入 ====================

static bool textCanUseHIDKeyboard(NSString *text) {
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar ch = [text characterAtIndex:i];
        if (ch >= 128) return false;
    }
    return true;
}

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
            [chunks addObject:substring]; return;
        }
        if (current.length > 0 && current.length + substring.length > maxUTF16Units) {
            [chunks addObject:[current copy]]; [current setString:@""];
        }
        [current appendString:substring];
    }];
    if (current.length > 0) [chunks addObject:[current copy]];
    return chunks;
}

static bool dispatchUnicodeTextChunk(NSString *chunk, pid_t targetPid, NSString **outError) {
    if (!resolveUnicodeRuntime() || !IOHIDEventCreateUnicodeEventFunc) {
        if (outError) *outError = g_unicodeRuntimeError;
        return false;
    }
    NSData *payload = [chunk dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    if (payload.length == 0) { if (outError) *outError = @"Failed to encode text as UTF-16LE"; return false; }
    IOHIDEventRef event = IOHIDEventCreateUnicodeEventFunc(
        kCFAllocatorDefault, mach_absolute_time(), (const uint8_t *)payload.bytes,
        (uint32_t)payload.length, kIOHIDUnicodeEncodingTypeUTF16LE, 0);
    if (!event) { if (outError) *outError = @"IOHIDEventCreateUnicodeEvent returned nil"; return false; }
    if (IOHIDEventSetIntegerValueFunc) IOHIDEventSetIntegerValueFunc(event, 4, 1);
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(event, SYNTHETIC_SENDER_ID);
    
    if (resolveBackBoardSendRuntime() && BKSHIDEventSendToProcessFunc && targetPid > 0) {
        BKSHIDEventSendToProcessFunc(event, targetPid); CFRelease(event); return true;
    }
    @try {
        id bks = bksSharedInstance();
        if (bks) { bksInjectHIDEvent(bks, event); CFRelease(event); return true; }
    } @catch (NSException *e) {}
    if (IOHIDEventSystemClientDispatchEventFunc) {
        static IOHIDEventSystemClientRef client = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{ client = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault); });
        if (client) { IOHIDEventSystemClientDispatchEventFunc(client, event); CFRelease(event); return true; }
    }
    CFRelease(event);
    if (outError) *outError = @"No dispatch path available for unicode event";
    return false;
}

static NSDictionary *doInputText(NSString *text) {
    if (!text || text.length == 0) return @{@"success": @NO, @"error": @"text required"};
    pid_t targetPid = getFrontmostAppPid();
    if (resolveUnicodeRuntime() && IOHIDEventCreateUnicodeEventFunc) {
        NSArray<NSString *> *chunks = textChunks(text, 64);
        bool allOk = true; NSString *firstError = nil;
        for (NSString *chunk in chunks) {
            NSString *chunkError = nil;
            if (!dispatchUnicodeTextChunk(chunk, targetPid, &chunkError)) { allOk = false; if (!firstError) firstError = chunkError; break; }
            usleep(50000);
        }
        if (allOk) return @{@"success": @YES, @"method": @"IOHIDEventCreateUnicodeEvent", @"chunks": @(chunks.count)};
    }
    // 降级：clipboard + paste
    runOnMainThreadSync(^{ [UIPasteboard generalPasteboard].string = text; });
    if (g_virtualKeyboardReady) {
        uint8_t vKey[1] = { 0x19 }; sendKeyboardReport(0x08, vKey, 1); usleep(30000);
        uint8_t noKeys[1] = { 0 }; sendKeyboardReport(0, noKeys, 0); usleep(50000);
    }
    return @{@"success": @YES, @"method": @"clipboard_paste", @"warning": @"Unicode HID unavailable, used clipboard fallback"};
}

static NSDictionary *doTypeText(NSString *text, float delayMs) {
    if (!text || text.length == 0) return @{@"success": @NO, @"error": @"text required"};
    if (delayMs <= 0) delayMs = 50;
    useconds_t delay = (useconds_t)(delayMs * 1000);
    pid_t targetPid = getFrontmostAppPid();
    if (resolveUnicodeRuntime() && IOHIDEventCreateUnicodeEventFunc) {
        NSArray<NSString *> *chunks = textChunks(text, 1);
        bool allOk = true;
        for (NSString *chunk in chunks) {
            NSString *chunkError = nil;
            if (!dispatchUnicodeTextChunk(chunk, targetPid, &chunkError)) { allOk = false; break; }
            if (delay > 0) usleep(delay);
        }
        if (allOk) return @{@"success": @YES, @"method": @"IOHIDEventCreateUnicodeEvent_charByChar", @"chunks": @(chunks.count)};
    }
    if (textCanUseHIDKeyboard(text) && g_virtualKeyboardReady) {
        for (NSUInteger i = 0; i < text.length; i++) {
            unichar c = [text characterAtIndex:i];
            uint32_t page = 0, usage = 0;
            NSString *charStr = [NSString stringWithCharacters:&c length:1];
            if (keyToUsage(charStr, &page, &usage)) handleKeyPressViaVirtualDevice(page, usage);
            usleep(delay);
        }
        return @{@"success": @YES, @"method": @"HID_keyboard_ASCII"};
    }
    // 最终降级
    runOnMainThreadSync(^{ [UIPasteboard generalPasteboard].string = text; });
    return @{@"success": @YES, @"method": @"clipboard_paste", @"warning": @"Unicode and ASCII keyboard unavailable"};
}

// ==================== v9.0: 截图功能（修复版）====================

// 从CGImage创建UIImage（通过bitmap）
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

// JPEG压缩
static NSData *JPEGDataForImage(UIImage *image, NSUInteger maxBytes) {
    NSData *bestData = UIImageJPEGRepresentation(image, kScreenshotInitialJPEGQuality);
    if (!bestData) return nil;
    if (bestData.length <= maxBytes) return bestData;
    NSData *minimumData = UIImageJPEGRepresentation(image, kScreenshotMinimumJPEGQuality);
    if (!minimumData) return bestData;
    if (minimumData.length > maxBytes) return minimumData;
    CGFloat low = kScreenshotMinimumJPEGQuality, high = kScreenshotInitialJPEGQuality;
    for (NSInteger pass = 0; pass < kScreenshotJPEGSearchPasses; pass++) {
        CGFloat quality = (low + high) / 2.0;
        NSData *candidate = UIImageJPEGRepresentation(image, quality);
        if (!candidate) break;
        if (candidate.length > maxBytes) high = quality;
        else { low = quality; bestData = candidate; }
    }
    return bestData;
}

static UIImage *resizedImageToFitBytes(UIImage *image, NSUInteger currentBytes) {
    CGImageRef cgImage = image.CGImage;
    if (!cgImage || currentBytes == 0) return nil;
    CGFloat ratio = sqrt((double)kScreenshotTargetBytes / (double)currentBytes) * 0.98;
    ratio = MIN(ratio, 0.9); ratio = MAX(ratio, 0.55);
    size_t width = CGImageGetWidth(cgImage), height = CGImageGetHeight(cgImage);
    CGSize targetSize = CGSizeMake(MAX((CGFloat)floor(width * ratio), 1.0), MAX((CGFloat)floor(height * ratio), 1.0));
    if (targetSize.width >= width || targetSize.height >= height) return nil;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    }];
}

static NSDictionary *encodedPayloadForImage(UIImage *image) {
    if (!image) return nil;
    // 先试PNG（小图）
    NSData *pngData = UIImagePNGRepresentation(image);
    if (pngData.length > 0 && pngData.length <= kScreenshotTargetBytes)
        return @{@"data": [pngData base64EncodedStringWithOptions:0], @"mimeType": @"image/png"};
    // JPEG多轮压缩+缩放
    UIImage *workingImage = image;
    NSData *bestJPEGData = nil;
    for (NSInteger attempt = 0; attempt < kScreenshotResizePasses; attempt++) {
        NSData *jpegData = JPEGDataForImage(workingImage, kScreenshotTargetBytes);
        if (!jpegData) break;
        bestJPEGData = jpegData;
        if (jpegData.length <= kScreenshotTargetBytes)
            return @{@"data": [jpegData base64EncodedStringWithOptions:0], @"mimeType": @"image/jpeg"};
        UIImage *scaledImage = resizedImageToFitBytes(workingImage, jpegData.length);
        if (!scaledImage) break;
        workingImage = scaledImage;
    }
    if (bestJPEGData.length > 0)
        return @{@"data": [bestJPEGData base64EncodedStringWithOptions:0], @"mimeType": @"image/jpeg"};
    return nil;
}

// ★ v9.0: 截图方法0 - getScreenDataWithQuantity（优先，参考ios-mcp的ScreenManager）
static NSDictionary *screenshotFromGetScreenData() {
    if (!_UICreateCGImageFromIOSurfaceFunc) return nil;
    SEL selector = NSSelectorFromString(@"createScreenIOSurface");
    if (![UIWindow respondsToSelector:selector]) return nil;
    
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            IOSurfaceRef ioSurfaceRef = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            ioSurfaceRef = (__bridge IOSurfaceRef)[UIWindow performSelector:selector];
#pragma clang diagnostic pop
            if (!ioSurfaceRef) return;
            
            CGImageRef cgImageRef = _UICreateCGImageFromIOSurfaceFunc(ioSurfaceRef);
            CFRelease(ioSurfaceRef);
            if (!cgImageRef) return;
            
            CGFloat scale = getScreenScaleSafe();
            UIImage *screenImage = [UIImage imageWithCGImage:cgImageRef scale:scale orientation:UIImageOrientationUp];
            CGImageRelease(cgImageRef);
            if (!screenImage) return;
            
            // 先PNG再JPEG（ios-mcp的ScreenManager方案）
            NSData *pngData = UIImagePNGRepresentation(screenImage);
            UIImage *rehydratedImage = (pngData.length > 0) ? [UIImage imageWithData:pngData] : screenImage;
            CGFloat quality = kScreenshotInitialJPEGQuality;
            NSData *jpegData = UIImageJPEGRepresentation(rehydratedImage, quality);
            if (jpegData && jpegData.length > 0) {
                if (jpegData.length <= kScreenshotTargetBytes) {
                    result = @{@"data": [jpegData base64EncodedStringWithOptions:0], @"mimeType": @"image/jpeg", @"source": @"getScreenDataWithQuantity"};
                } else {
                    // 需要压缩
                    NSDictionary *payload = encodedPayloadForImage(rehydratedImage);
                    if (payload) {
                        NSMutableDictionary *m = [payload mutableCopy];
                        m[@"source"] = @"getScreenDataWithQuantity_compressed";
                        result = [m copy];
                    }
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] getScreenData exception: %@", e);
        }
    });
    return result;
}

// 截图方法1 - CARenderServerCaptureDisplay
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

// 截图方法2 - _UICreateScreenUIImage
static UIImage *screenshotFromUICreateScreenUIImage() {
    if (!_UICreateScreenUIImageFunc) return nil;
    return _UICreateScreenUIImageFunc();
}

// 截图方法3 - IOSurface
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
    UIImage *image = bitmapImageFromCGImage(cgImage, getScreenScaleSafe());
    CGImageRelease(cgImage);
    return image;
}

// 截图方法4 - Window capture
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
        } @catch (NSException *e) {}
    });
    return image;
}

// ★ v9.0: 截图主函数 - 四级降级（优先getScreenDataWithQuantity）
static NSDictionary *doScreenshot() {
    __block NSDictionary *result = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // ★ v9.0: 优先方法0 - getScreenDataWithQuantity（直接获取JPEG，最高效）
            NSDictionary *payload = screenshotFromGetScreenData();
            if (payload) {
                NSMutableDictionary *m = [payload mutableCopy];
                m[@"success"] = @YES;
                result = [m copy];
                NSLog(@"[StarCoreTweak] 📸 Screenshot via getScreenDataWithQuantity");
                dispatch_semaphore_signal(sema);
                return;
            }
            
            // 方法1: CARenderServerCaptureDisplay
            UIImage *image = screenshotFromRenderServer();
            NSString *source = @"CARenderServerCaptureDisplay";
            
            // 方法2: _UICreateScreenUIImage
            if (!image) { image = screenshotFromUICreateScreenUIImage(); source = @"_UICreateScreenUIImage"; }
            // 方法3: IOSurface
            if (!image) { image = screenshotFromIOSurface(); source = @"IOSurface"; }
            // 方法4: Window capture
            if (!image) { image = screenshotFromWindowCapture(); source = @"window_capture"; }
            
            if (!image) {
                result = @{@"success": @NO, @"error": @"All screenshot methods failed"};
                dispatch_semaphore_signal(sema);
                return;
            }
            
            NSDictionary *imgPayload = encodedPayloadForImage(image);
            if (!imgPayload) {
                result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"Failed to encode screenshot (%.0fx%.0f)", image.size.width, image.size.height]};
                dispatch_semaphore_signal(sema);
                return;
            }
            
            NSMutableDictionary *m = [imgPayload mutableCopy];
            m[@"success"] = @YES;
            m[@"source"] = source;
            result = [m copy];
            NSLog(@"[StarCoreTweak] 📸 Screenshot via %@, base64: %lu", source, (unsigned long)[imgPayload[@"data"] length]);
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"Screenshot exception: %@", e]};
        }
        dispatch_semaphore_signal(sema);
    });
    
    long waitResult = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC));
    if (waitResult != 0) return @{@"success": @NO, @"error": @"Screenshot timed out (8s)"};
    return result ?: @{@"success": @NO, @"error": @"Screenshot returned nil"};
}

// ==================== v9.0: AXUIElement - getUIElements ====================

static NSDictionary *doGetUIElements(BOOL clickableOnly, NSInteger maxElements) {
    // ★ v9.1: AX不可用时用shell fallback
    if (!g_axRuntimeAvailable || !_AXUIElementCreateApplicationFunc || !_AXUIElementCopyAttributeValueFunc) {
        NSString *fallbackCmd = @"plutil -p /var/mobile/Library/SpringBoard/applicationState.plist 2>/dev/null | head -50";
        FILE *pipe = popen(fallbackCmd.UTF8String, "r");
        if (pipe) {
            NSMutableString *output = [NSMutableString string];
            char buf[4096];
            while (fgets(buf, sizeof(buf), pipe)) [output appendString:[NSString stringWithUTF8String:buf]];
            pclose(pipe);
            return @{@"success": @YES, @"method": @"shell_fallback", @"rawOutput": output, @"note": @"AXRuntime not available, showing app state"};
        }
        return @{@"success": @NO, @"error": @"AXRuntime not available"};
    }
    
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            // 获取前台App PID
            pid_t pid = getFrontmostAppPid();
            if (pid <= 0) {
                result = @{@"success": @NO, @"error": @"No frontmost application"};
                return;
            }
            
            // 设置请求客户端类型（帮助AXRuntime识别我们有权限）
            if (_AXSetRequestingClientFunc) _AXSetRequestingClientFunc(2);
            
            // 创建AXUIElement
            AXUIElementRef appElement = _AXUIElementCreateApplicationFunc(pid);
            if (!appElement) {
                result = @{@"success": @NO, @"error": @"AXUIElementCreateApplication returned nil"};
                return;
            }
            
            // 设置超时
            if (_AXUIElementSetMessagingTimeoutFunc)
                _AXUIElementSetMessagingTimeoutFunc(appElement, 5.0);
            
            // 获取子元素
            CFTypeRef childrenValue = NULL;
            AXError err = _AXUIElementCopyAttributeValueFunc(appElement, kAXChildrenAttribute, &childrenValue);
            
            if (err != kAXErrorSuccess || !childrenValue) {
                CFRelease(appElement);
                result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"Failed to get children (error=%d)", (int)err]};
                return;
            }
            
            NSArray *children = (__bridge_transfer NSArray *)childrenValue;
            NSMutableArray *elements = [NSMutableArray array];
            
            CGRect screenBounds = getScreenBoundsSafe();
            NSInteger maxEl = maxElements > 0 ? maxElements : 200;
            
            // 递归获取可交互元素
            void (^collectElements)(AXUIElementRef, NSInteger) = nil;
            collectElements = ^(AXUIElementRef element, NSInteger depth) {
                if (elements.count >= maxEl || depth > 8) return;
                
                @try {
                    // 获取role
                    CFTypeRef roleValue = NULL;
                    NSString *role = @"";
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXRoleAttribute, &roleValue) == kAXErrorSuccess && roleValue) {
                        role = (__bridge_transfer NSString *)roleValue;
                    }
                    
                    // 获取label/title
                    CFTypeRef labelValue = NULL;
                    NSString *label = @"";
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXLabelAttribute, &labelValue) == kAXErrorSuccess && labelValue) {
                        label = (__bridge_transfer NSString *)labelValue;
                    } else {
                        CFTypeRef titleValue = NULL;
                        if (_AXUIElementCopyAttributeValueFunc(element, kAXTitleAttribute, &titleValue) == kAXErrorSuccess && titleValue) {
                            label = (__bridge_transfer NSString *)titleValue;
                        }
                    }
                    
                    // 获取value
                    CFTypeRef valueRef = NULL;
                    NSString *value = @"";
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXValueAttribute, &valueRef) == kAXErrorSuccess && valueRef) {
                        if (CFGetTypeID(valueRef) == CFStringGetTypeID())
                            value = (__bridge_transfer NSString *)valueRef;
                        else {
                            value = [(__bridge id)valueRef description];
                            CFRelease(valueRef);
                        }
                    }
                    
                    // 获取frame
                    CFTypeRef frameValue = NULL;
                    CGRect frame = CGRectNull;
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXFrameAttribute, &frameValue) == kAXErrorSuccess && frameValue) {
                        if (CFGetTypeID(frameValue) == AXValueGetTypeID()) {
                            // AXValue → CGRect
                            typedef AXError (*AXValueGetValueFuncType)(CFTypeRef, uint32_t, void *);
                            static AXValueGetValueFuncType axValueGetValue = NULL;
                            static dispatch_once_t onceToken;
                            dispatch_once(&onceToken, ^{
                                void *handle = dlopen("/System/Library/PrivateFrameworks/AXRuntime.framework/AXRuntime", RTLD_LAZY);
                                if (handle) axValueGetValue = (AXValueGetValueFuncType)dlsym(handle, "AXValueGetValue");
                                if (!axValueGetValue) axValueGetValue = (AXValueGetValueFuncType)dlsym(RTLD_DEFAULT, "AXValueGetValue");
                            });
                            if (axValueGetValue) {
                                // kAXValueCGRectType = 1
                                axValueGetValue(frameValue, 1, &frame);
                            }
                        }
                        CFRelease(frameValue);
                    }
                    
                    // 获取enabled
                    CFTypeRef enabledValue = NULL;
                    BOOL enabled = YES;
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXEnabledAttribute, &enabledValue) == kAXErrorSuccess && enabledValue) {
                        enabled = [(__bridge NSNumber *)enabledValue boolValue];
                        CFRelease(enabledValue);
                    }
                    
                    // 获取identifier
                    CFTypeRef identValue = NULL;
                    NSString *identifier = @"";
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXIdentifierAttribute, &identValue) == kAXErrorSuccess && identValue) {
                        identifier = (__bridge_transfer NSString *)identValue;
                    }
                    
                    // 获取traits
                    CFTypeRef traitsValue = NULL;
                    uint64_t traits = 0;
                    if (_AXUIElementCopyAttributeValueFunc(element, kAXTraitsAttribute, &traitsValue) == kAXErrorSuccess && traitsValue) {
                        if (CFGetTypeID(traitsValue) == CFNumberGetTypeID())
                            [(__bridge NSNumber *)traitsValue getValue:&traits];
                        CFRelease(traitsValue);
                    }
                    
                    // 判断是否可交互
                    // UIAccessibilityTraits: Button=1, Link=2, TextField=4, StaticText=8, Image=16, SearchField=32, etc.
                    BOOL isButton = (traits & (1ULL << 0)) != 0;
                    BOOL isLink = (traits & (1ULL << 1)) != 0;
                    BOOL isTextField = (traits & (1ULL << 2)) != 0;
                    BOOL isSearchField = (traits & (1ULL << 5)) != 0;
                    BOOL isInteractive = isButton || isLink || isTextField || isSearchField || enabled;
                    
                    // 有frame且在屏幕内
                    BOOL hasValidFrame = !CGRectIsNull(frame) && frame.size.width > 0 && frame.size.height > 0;
                    BOOL isInScreen = hasValidFrame && CGRectIntersectsRect(frame, screenBounds);
                    
                    // 根据role判断是否是可点击类型
                    BOOL isClickableRole = [role containsString:@"Button"] || [role containsString:@"Link"] ||
                                           [role containsString:@"TextField"] || [role containsString:@"SearchField"] ||
                                           [role containsString:@"Cell"] || [role containsString:@"Tab"] ||
                                           [role containsString:@"Switch"] || [role containsString:@"Slider"] ||
                                           [role containsString:@"MenuItem"] || [role containsString:@"StatusBar"];
                    
                    // 如果clickableOnly模式，过滤掉不可交互的
                    BOOL shouldInclude = !clickableOnly || (isClickableRole || isInteractive);
                    
                    if (shouldInclude && hasValidFrame && isInScreen) {
                        CGFloat centerX = frame.origin.x + frame.size.width / 2.0;
                        CGFloat centerY = frame.origin.y + frame.size.height / 2.0;
                        
                        NSMutableDictionary *el = [NSMutableDictionary dictionary];
                        if (label.length > 0) el[@"text"] = label;
                        if (value.length > 0) el[@"value"] = value;
                        if (role.length > 0) el[@"type"] = role;
                        if (identifier.length > 0) el[@"identifier"] = identifier;
                        el[@"tap"] = @{@"x": @(centerX), @"y": @(centerY)};
                        el[@"frame"] = @{@"x": @(frame.origin.x), @"y": @(frame.origin.y),
                                         @"width": @(frame.size.width), @"height": @(frame.size.height)};
                        if (!enabled) el[@"enabled"] = @NO;
                        
                        [elements addObject:el];
                    }
                    
                    // 递归子元素（不管当前元素是否被包含，子元素可能需要）
                    if (!clickableOnly || depth < 3) {
                        CFTypeRef subChildren = NULL;
                        if (_AXUIElementCopyAttributeValueFunc(element, kAXChildrenAttribute, &subChildren) == kAXErrorSuccess && subChildren) {
                            NSArray *kids = (__bridge_transfer NSArray *)subChildren;
                            for (id kid in kids) {
                                if (elements.count >= maxEl) break;
                                if (CFGetTypeID((__bridge CFTypeRef)kid) == AXUIElementGetTypeID()) {
                                    collectElements((__bridge AXUIElementRef)kid, depth + 1);
                                }
                            }
                        }
                    }
                } @catch (NSException *e) {
                    // Skip problematic elements
                }
            };
            
            for (id child in children) {
                if (elements.count >= maxEl) break;
                if (CFGetTypeID((__bridge CFTypeRef)child) == AXUIElementGetTypeID()) {
                    collectElements((__bridge AXUIElementRef)child, 0);
                }
            }
            
            CFRelease(appElement);
            
            NSString *bundleId = getFrontmostBundleId() ?: @"";
            
            result = @{
                @"success": @YES,
                @"screen": @{@"width": @(screenBounds.size.width), @"height": @(screenBounds.size.height)},
                @"processName": bundleId,
                @"elements": elements,
                @"count": @(elements.count),
                @"clickableOnly": @(clickableOnly)
            };
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"getUIElements exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"getUIElements returned nil"};
}

// ★ v9.0: getElementAtPoint
static NSDictionary *doGetElementAtPoint(float x, float y) {
    if (!g_axRuntimeAvailable || !_AXUIElementCreateApplicationFunc || !_AXUIElementCopyAttributeValueFunc) {
        return @{@"success": @NO, @"error": @"AXRuntime not available"};
    }
    
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            pid_t pid = getFrontmostAppPid();
            if (pid <= 0) { result = @{@"success": @NO, @"error": @"No frontmost application"}; return; }
            
            if (_AXSetRequestingClientFunc) _AXSetRequestingClientFunc(2);
            
            AXUIElementRef appElement = _AXUIElementCreateApplicationFunc(pid);
            if (!appElement) { result = @{@"success": @NO, @"error": @"AXUIElementCreateApplication failed"}; return; }
            
            if (_AXUIElementSetMessagingTimeoutFunc) _AXUIElementSetMessagingTimeoutFunc(appElement, 3.0);
            
            // 尝试使用系统级hit test
            AXUIElementRef elementAtPoint = NULL;
            
            // 方法1: 使用AXUIElementCreateSystemWide + elementAtPosition
            if (_AXUIElementCreateSystemWideFunc) {
                AXUIElementRef systemWide = _AXUIElementCreateSystemWideFunc();
                if (systemWide) {
                    // AXUIElementCopyElementAtPosition - 尝试动态加载
                    typedef AXError (*AXUIElementCopyElementAtPositionFuncType)(AXUIElementRef, float, float, AXUIElementRef *);
                    static AXUIElementCopyElementAtPositionFuncType copyElementAtPos = NULL;
                    static dispatch_once_t onceToken;
                    dispatch_once(&onceToken, ^{
                        void *handle = dlopen("/System/Library/PrivateFrameworks/AXRuntime.framework/AXRuntime", RTLD_LAZY);
                        if (handle) copyElementAtPos = (AXUIElementCopyElementAtPositionFuncType)dlsym(handle, "AXUIElementCopyElementAtPosition");
                        if (!copyElementAtPos) copyElementAtPos = (AXUIElementCopyElementAtPositionFuncType)dlsym(RTLD_DEFAULT, "AXUIElementCopyElementAtPosition");
                    });
                    
                    if (copyElementAtPos) {
                        AXError posErr = copyElementAtPos(systemWide, x, y, &elementAtPoint);
                        if (posErr != kAXErrorSuccess) elementAtPoint = NULL;
                    }
                    CFRelease(systemWide);
                }
            }
            
            AXUIElementRef targetElement = elementAtPoint ?: appElement;
            
            // 读取元素属性
            NSMutableDictionary *el = [NSMutableDictionary dictionary];
            
            CFTypeRef roleValue = NULL;
            if (_AXUIElementCopyAttributeValueFunc(targetElement, kAXRoleAttribute, &roleValue) == kAXErrorSuccess && roleValue) {
                el[@"type"] = (__bridge_transfer NSString *)roleValue;
            }
            
            CFTypeRef labelValue = NULL;
            if (_AXUIElementCopyAttributeValueFunc(targetElement, kAXLabelAttribute, &labelValue) == kAXErrorSuccess && labelValue) {
                el[@"text"] = (__bridge_transfer NSString *)labelValue;
            } else {
                CFTypeRef titleValue = NULL;
                if (_AXUIElementCopyAttributeValueFunc(targetElement, kAXTitleAttribute, &titleValue) == kAXErrorSuccess && titleValue) {
                    el[@"text"] = (__bridge_transfer NSString *)titleValue;
                }
            }
            
            CFTypeRef valueRef = NULL;
            if (_AXUIElementCopyAttributeValueFunc(targetElement, kAXValueAttribute, &valueRef) == kAXErrorSuccess && valueRef) {
                if (CFGetTypeID(valueRef) == CFStringGetTypeID())
                    el[@"value"] = (__bridge_transfer NSString *)valueRef;
                else {
                    el[@"value"] = [(__bridge id)valueRef description];
                    CFRelease(valueRef);
                }
            }
            
            CFTypeRef frameValue = NULL;
            if (_AXUIElementCopyAttributeValueFunc(targetElement, kAXFrameAttribute, &frameValue) == kAXErrorSuccess && frameValue) {
                typedef AXError (*AXValueGetValueFuncType)(CFTypeRef, uint32_t, void *);
                static AXValueGetValueFuncType axValueGetValue = NULL;
                static dispatch_once_t onceToken2;
                dispatch_once(&onceToken2, ^{
                    void *handle = dlopen("/System/Library/PrivateFrameworks/AXRuntime.framework/AXRuntime", RTLD_LAZY);
                    if (handle) axValueGetValue = (AXValueGetValueFuncType)dlsym(handle, "AXValueGetValue");
                    if (!axValueGetValue) axValueGetValue = (AXValueGetValueFuncType)dlsym(RTLD_DEFAULT, "AXValueGetValue");
                });
                if (axValueGetValue) {
                    CGRect frame;
                    if (axValueGetValue(frameValue, 1, &frame)) {
                        el[@"frame"] = @{@"x": @(frame.origin.x), @"y": @(frame.origin.y),
                                         @"width": @(frame.size.width), @"height": @(frame.size.height)};
                    }
                }
                CFRelease(frameValue);
            }
            
            el[@"point"] = @{@"x": @(x), @"y": @(y)};
            
            if (elementAtPoint) CFRelease(elementAtPoint);
            CFRelease(appElement);
            
            result = @{@"success": @YES, @"element": el};
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"getElementAtPoint exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"getElementAtPoint returned nil"};
}

// ==================== v9.0: App管理 ====================

static NSDictionary *doListApps(NSString *filter) {
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            NSMutableArray *apps = [NSMutableArray array];
            
            // 策略1: LSApplicationWorkspace
            Class LSWorkspaceClass = objc_getClass("LSApplicationWorkspace");
            if (LSWorkspaceClass) {
                id workspace = [LSWorkspaceClass performSelector:@selector(defaultWorkspace)];
                if (workspace && [workspace respondsToSelector:@selector(allInstalledApplications)]) {
                    NSArray *allApps = [workspace performSelector:@selector(allInstalledApplications)];
                    for (id proxy in allApps) {
                        NSString *bundleId = @"";
                        NSString *displayName = @"";
                        NSString *appType = @"User";
                        
                        if ([proxy respondsToSelector:@selector(applicationIdentifier)])
                            bundleId = [proxy performSelector:@selector(applicationIdentifier)] ?: @"";
                        if ([proxy respondsToSelector:@selector(localizedName)])
                            displayName = [proxy performSelector:@selector(localizedName)] ?: @"";
                        if ([proxy respondsToSelector:@selector(applicationType)])
                            appType = [proxy performSelector:@selector(applicationType)] ?: @"System";
                        
                        // 过滤
                        if (filter.length > 0 && ![bundleId.lowercaseString containsString:filter.lowercaseString] && ![displayName.lowercaseString containsString:filter.lowercaseString])
                            continue;
                        
                        // 归一化类型
                        NSString *normalizedType = [appType isEqualToString:@"User"] ? @"User" : appType;
                        
                        [apps addObject:@{
                            @"bundleId": bundleId,
                            @"name": displayName,
                            @"type": normalizedType
                        }];
                    }
                }
            }
            
            // 策略2: SBApplicationController（补充displayName）
            if (apps.count == 0) {
                Class SBAppCtrl = objc_getClass("SBApplicationController");
                if (SBAppCtrl) {
                    id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
                    if ([appCtrl respondsToSelector:@selector(allApplications)]) {
                        NSArray *allApps = [appCtrl performSelector:@selector(allApplications)];
                        for (id app in allApps) {
                            NSString *bundleId = @"";
                            NSString *displayName = @"";
                            if ([app respondsToSelector:@selector(bundleIdentifier)])
                                bundleId = [app performSelector:@selector(bundleIdentifier)] ?: @"";
                            if ([app respondsToSelector:@selector(displayName)])
                                displayName = [app performSelector:@selector(displayName)] ?: @"";
                            
                            if (filter.length > 0 && ![bundleId.lowercaseString containsString:filter.lowercaseString] && ![displayName.lowercaseString containsString:filter.lowercaseString])
                                continue;
                            
                            [apps addObject:@{@"bundleId": bundleId, @"name": displayName, @"type": @"User"}];
                        }
                    }
                }
            }
            
            result = @{@"success": @YES, @"apps": apps, @"count": @(apps.count)};
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"listApps exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"listApps returned nil"};
}

static NSDictionary *doListRunningApps() {
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            NSMutableArray *apps = [NSMutableArray array];
            
            Class SBAppCtrl = objc_getClass("SBApplicationController");
            if (SBAppCtrl) {
                id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
                if ([appCtrl respondsToSelector:@selector(runningApplications)]) {
                    NSArray *running = [appCtrl performSelector:@selector(runningApplications)];
                    for (id app in running) {
                        NSString *bundleId = @"";
                        NSString *displayName = @"";
                        BOOL isRunning = NO;
                        if ([app respondsToSelector:@selector(bundleIdentifier)])
                            bundleId = [app performSelector:@selector(bundleIdentifier)] ?: @"";
                        if ([app respondsToSelector:@selector(displayName)])
                            displayName = [app performSelector:@selector(displayName)] ?: @"";
                        if ([app respondsToSelector:@selector(isRunning)])
                            isRunning = ((BOOL(*)(id, SEL))objc_msgSend)(app, @selector(isRunning));
                        
                        [apps addObject:@{
                            @"bundleId": bundleId,
                            @"name": displayName,
                            @"running": @(isRunning)
                        }];
                    }
                }
            }
            
            result = @{@"success": @YES, @"apps": apps, @"count": @(apps.count)};
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"listRunningApps exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"listRunningApps returned nil"};
}

static NSDictionary *doKillApp(NSString *bundleId) {
    if (!bundleId || bundleId.length == 0) return @{@"success": @NO, @"error": @"bundleId required"};
    
    __block BOOL ok = NO;
    __block NSString *method = @"";
    __block NSString *errMsg = @"";
    
    runOnMainThreadSync(^{
        // 策略1: FBSSystemService terminateApplication
        Class fbsClass = objc_getClass("FBSSystemService");
        if (fbsClass) {
            id fbs = [fbsClass performSelector:@selector(sharedService)];
            SEL terminateSel = @selector(terminateApplication:forReason:andReport:withDescription:);
            if (fbs && [fbs respondsToSelector:terminateSel]) {
                ((void(*)(id, SEL, NSString*, int, BOOL, NSString*))objc_msgSend)(fbs, terminateSel, bundleId, 1, YES, @"StarCore kill");
                ok = YES; method = @"FBSSystemService"; return;
            }
        }
        
        // 策略2: SBApplicationController + processState
        Class SBAppCtrl = objc_getClass("SBApplicationController");
        if (SBAppCtrl) {
            id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
            id sbApp = [appCtrl performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundleId];
            if (sbApp) {
                // 尝试通过FBSScene terminate
                id processState = nil;
                if ([sbApp respondsToSelector:@selector(processState)])
                    processState = [sbApp performSelector:@selector(processState)];
                if (processState && [processState respondsToSelector:@selector(terminate)]) {
                    [processState performSelector:@selector(terminate)];
                    ok = YES; method = @"FBSScene"; return;
                }
            }
        }
        
        // 策略3: kill进程（通过shell）
        errMsg = @"FBSSystemService not available";
    });
    
    if (!ok) {
        // 最终降级：shell kill
        NSString *cmd = [NSString stringWithFormat:@"killall '%@' 2>/dev/null || true", bundleId];
        FILE *fp = popen([cmd UTF8String], "r");
        if (fp) { pclose(fp); ok = YES; method = @"shell_killall"; }
    }
    
    if (ok) return @{@"success": @YES, @"method": method};
    return @{@"success": @NO, @"error": errMsg};
}

// ★ v9.1: getFrontmostApp - 用SBAppSwitcherModel替代frontmostApplication
static NSDictionary *doGetFrontmostApp() {
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            NSString *bundleId = @"";
            NSString *displayName = @"";
            pid_t pid = 0;
            
            // ★ 用SBAppSwitcherModel获取最前台App
            Class SBSwitcherModel = objc_getClass("SBAppSwitcherModel");
            if (SBSwitcherModel) {
                id model = [SBSwitcherModel performSelector:@selector(sharedInstance)];
                if (model && [model respondsToSelector:@selector(applicationAtPosition:)]) {
                    id appLayout = [model performSelector:@selector(applicationAtPosition:) withObject:@(0)];
                    if (appLayout && [appLayout respondsToSelector:@selector(application)]) {
                        id sbApp = [appLayout performSelector:@selector(application)];
                        if (sbApp) {
                            if ([sbApp respondsToSelector:@selector(bundleIdentifier)])
                                bundleId = [sbApp performSelector:@selector(bundleIdentifier)] ?: @"";
                            if ([sbApp respondsToSelector:@selector(displayName)])
                                displayName = [sbApp performSelector:@selector(displayName)] ?: @"";
                            if ([sbApp respondsToSelector:@selector(processID)])
                                pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(sbApp, @selector(processID));
                            if (bundleId.length > 0) SAFE_SET_GLOBAL(g_frontmostApp, bundleId);
                        }
                    }
                }
            }
            
            // fallback: UIApplication + SBApplicationController
            if (bundleId.length == 0) {
                UIApplication *app = [UIApplication sharedApplication];
                if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                    id frontApp = [app performSelector:@selector(frontmostApplication)];
                    if (frontApp) {
                        if ([frontApp respondsToSelector:@selector(bundleIdentifier)])
                            bundleId = [frontApp performSelector:@selector(bundleIdentifier)] ?: @"";
                    }
                }
            }
            // 补充displayName和pid
            if (bundleId.length > 0 && (displayName.length == 0 || pid == 0)) {
                Class SBAppCtrl = objc_getClass("SBApplicationController");
                if (SBAppCtrl) {
                    id appCtrl = [SBAppCtrl performSelector:@selector(sharedInstance)];
                    id sbApp = [appCtrl performSelector:@selector(applicationWithBundleIdentifier:) withObject:bundleId];
                    if (sbApp) {
                        if (displayName.length == 0 && [sbApp respondsToSelector:@selector(displayName)])
                            displayName = [sbApp performSelector:@selector(displayName)] ?: @"";
                        if (pid == 0 && [sbApp respondsToSelector:@selector(processID)])
                            pid = (pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(sbApp, @selector(processID));
                    }
                }
            }
            
            result = @{@"success": @YES, @"bundleId": bundleId, @"name": displayName, @"pid": @(pid)};
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"getFrontmostApp returned nil"};
}

// ★ v9.0: openURL
static NSDictionary *doOpenURL(NSString *urlStr) {
    if (!urlStr || urlStr.length == 0) return @{@"success": @NO, @"error": @"url required"};
    
    __block BOOL ok = NO;
    __block NSString *method = @"";
    
    runOnMainThreadSync(^{
        @try {
            NSURL *url = [NSURL URLWithString:urlStr];
            if (!url) return;
            
            // 策略1: UIApplication openURL
            UIApplication *app = [UIApplication sharedApplication];
            if ([app respondsToSelector:@selector(openURL:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                ok = [app openURL:url];
#pragma clang diagnostic pop
                if (ok) method = @"openURL";
            }
            
            // 策略2: LSApplicationWorkspace
            if (!ok) {
                Class wc = objc_getClass("LSApplicationWorkspace");
                if (wc) {
                    id ws = [wc performSelector:@selector(defaultWorkspace)];
                    if (ws && [ws respondsToSelector:@selector(openApplicationWithBundleID:)]) {
                        // 对于prefs: URL等，使用LSApplicationWorkspace
                        SEL openSel = NSSelectorFromString(@"openSensitiveURL:withOptions:");
                        if ([ws respondsToSelector:openSel]) {
                            ((void(*)(id, SEL, NSURL*, id))objc_msgSend)(ws, openSel, url, nil);
                            ok = YES; method = @"LSApplicationWorkspace_openSensitiveURL";
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    });
    
    if (ok) return @{@"success": @YES, @"method": method};
    return @{@"success": @NO, @"error": @"Failed to open URL"};
}

// ★ v9.0: installApp
static NSDictionary *doInstallApp(NSString *ipaPath) {
    if (!ipaPath || ipaPath.length == 0) return @{@"success": @NO, @"error": @"ipaPath required"};
    
    __block BOOL ok = NO;
    __block NSString *errMsg = @"";
    
    runOnMainThreadSync(^{
        Class LSWorkspaceClass = objc_getClass("LSApplicationWorkspace");
        if (!LSWorkspaceClass) { errMsg = @"LSApplicationWorkspace not available"; return; }
        
        id workspace = [LSWorkspaceClass performSelector:@selector(defaultWorkspace)];
        NSURL *appURL = [NSURL fileURLWithPath:ipaPath];
        
        SEL installSel = @selector(installApplication:withOptions:error:);
        if ([workspace respondsToSelector:installSel]) {
            NSMethodSignature *sig = [workspace methodSignatureForSelector:installSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            inv.target = workspace;
            inv.selector = installSel;
            [inv setArgument:(void *)&appURL atIndex:2];
            NSDictionary *opts = @{@"PackageType": @"Customer"};
            [inv setArgument:(void *)&opts atIndex:3];
            __autoreleasing NSError *installError = nil;
            [inv setArgument:(void *)&installError atIndex:4];
            [inv invoke];
            
            BOOL result = NO;
            if (strcmp(sig.methodReturnType, @encode(BOOL)) == 0)
                [inv getReturnValue:&result];
            
            if (result) ok = YES;
            else errMsg = installError ? installError.localizedDescription : @"installApplication returned NO";
        } else {
            errMsg = @"installApplication selector not found";
        }
    });
    
    if (ok) return @{@"success": @YES};
    return @{@"success": @NO, @"error": errMsg};
}

// ★ v9.0: uninstallApp
static NSDictionary *doUninstallApp(NSString *bundleId) {
    if (!bundleId || bundleId.length == 0) return @{@"success": @NO, @"error": @"bundleId required"};
    
    __block BOOL ok = NO;
    __block NSString *errMsg = @"";
    
    runOnMainThreadSync(^{
        Class LSWorkspaceClass = objc_getClass("LSApplicationWorkspace");
        if (!LSWorkspaceClass) { errMsg = @"LSApplicationWorkspace not available"; return; }
        
        id workspace = [LSWorkspaceClass performSelector:@selector(defaultWorkspace)];
        SEL uninstallSel = @selector(uninstallApplication:withOptions:);
        if ([workspace respondsToSelector:uninstallSel]) {
            NSMethodSignature *sig = [workspace methodSignatureForSelector:uninstallSel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            inv.target = workspace;
            inv.selector = uninstallSel;
            [inv setArgument:(void *)&bundleId atIndex:2];
            NSDictionary *opts = @{};
            [inv setArgument:(void *)&opts atIndex:3];
            [inv invoke];
            
            BOOL result = NO;
            if (strcmp(sig.methodReturnType, @encode(BOOL)) == 0)
                [inv getReturnValue:&result];
            
            if (result) ok = YES;
            else errMsg = @"uninstallApplication returned NO";
        } else {
            errMsg = @"uninstallApplication selector not found";
        }
    });
    
    if (ok) return @{@"success": @YES};
    return @{@"success": @NO, @"error": errMsg};
}

// ==================== v9.0: 设备信息 ====================

static NSDictionary *doGetDeviceInfo() {
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            UIDevice *device = [UIDevice currentDevice];
            UIScreen *screen = [UIScreen mainScreen];
            CGRect bounds = screen.bounds;
            
            NSMutableDictionary *info = [@{
                @"deviceName": device.name ?: @"",
                @"systemName": device.systemName ?: @"",
                @"systemVersion": device.systemVersion ?: @"",
                @"model": device.model ?: @"",
                @"localizedModel": device.localizedModel ?: @"",
                @"userInterfaceIdiom": @(device.userInterfaceIdiom),
                @"screenWidth": @(bounds.size.width),
                @"screenHeight": @(bounds.size.height),
                @"screenScale": @(screen.scale),
                @"tweakVersion": @"9.0",
            } mutableCopy];
            
            // 电池信息
            [device setBatteryMonitoringEnabled:YES];
            info[@"batteryLevel"] = @(device.batteryLevel);
            info[@"batteryState"] = @(device.batteryState);
            [device setBatteryMonitoringEnabled:NO];
            
            // 内存信息
            NSURL *memURL = [NSURL fileURLWithPath:@"/proc/meminfo"];
            NSString *memInfo = [NSString stringWithContentsOfURL:memURL encoding:NSUTF8StringEncoding error:nil];
            if (memInfo) info[@"memInfo"] = memInfo;
            
            // 存储信息
            NSDictionary *fsAttrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:nil];
            if (fsAttrs) {
                info[@"totalDiskSpace"] = fsAttrs[NSFileSystemSize];
                info[@"freeDiskSpace"] = fsAttrs[NSFileSystemFreeSize];
            }
            
            result = @{@"success": @YES, @"device": [info copy]};
        } @catch (NSException *e) {
            result = @{@"success": @NO, @"error": [NSString stringWithFormat:@"exception: %@", e]};
        }
    });
    return result ?: @{@"success": @NO, @"error": @"getDeviceInfo returned nil"};
}

// ==================== v9.0: 亮度/音量 ====================

static NSDictionary *doGetBrightness() {
    __block CGFloat brightness = 0;
    runOnMainThreadSync(^{ brightness = [UIScreen mainScreen].brightness; });
    return @{@"success": @YES, @"brightness": @(brightness)};
}

static NSDictionary *doSetBrightness(float brightness) {
    if (brightness < 0) brightness = 0;
    if (brightness > 1) brightness = 1;
    runOnMainThreadSync(^{ [UIScreen mainScreen].brightness = brightness; });
    return @{@"success": @YES, @"brightness": @(brightness)};
}

static NSDictionary *doGetVolume() {
    __block float volume = -1;
    runOnMainThreadSync(^{
        @try {
            // MPMusicPlayerController (deprecated but works on jailbroken)
            Class mpc = NSClassFromString(@"MPMusicPlayerController");
            if (mpc) {
                id player = [mpc performSelector:@selector(systemMusicPlayer)];
                if (player && [player respondsToSelector:@selector(volume)])
                    volume = ((float(*)(id, SEL))objc_msgSend)(player, @selector(volume));
            }
            // fallback: shell
            if (volume < 0) {
                FILE *fp = popen("osascript -e 'output volume of (get volume settings)' 2>/dev/null", "r");
                if (fp) {
                    char buf[32];
                    if (fgets(buf, sizeof(buf), fp)) volume = atof(buf) / 100.0f;
                    pclose(fp);
                }
            }
        } @catch (NSException *e) {}
    });
    if (volume >= 0) return @{@"success": @YES, @"volume": @(volume)};
    return @{@"success": @NO, @"error": @"Could not get volume"};
}

static NSDictionary *doSetVolume(float volume) {
    if (volume < 0) volume = 0;
    if (volume > 1) volume = 1;
    
    runOnMainThreadSync(^{
        @try {
            // 通过MPMusicPlayerController设置
            Class mpc = NSClassFromString(@"MPMusicPlayerController");
            if (mpc) {
                id player = [mpc performSelector:@selector(systemMusicPlayer)];
                if (player && [player respondsToSelector:@selector(setVolume:)])
                    ((void(*)(id, SEL, float))objc_msgSend)(player, @selector(setVolume:), volume);
            }
        } @catch (NSException *e) {}
    });
    
    return @{@"success": @YES, @"volume": @(volume)};
}

// ==================== v9.0: 屏幕状态辅助 ====================

static BOOL readBoolSelector(id target, SEL selector) {
    if (!target || !selector || ![target respondsToSelector:selector]) return NO;
    @try { return ((BOOL (*)(id, SEL))objc_msgSend)(target, selector); }
    @catch (NSException *e) { return NO; }
}

static BOOL readIntegerSelector(id target, SEL selector, NSInteger *outValue) {
    if (!target || !selector || ![target respondsToSelector:selector]) return NO;
    @try { NSInteger value = ((NSInteger (*)(id, SEL))objc_msgSend)(target, selector); if (outValue) *outValue = value; return YES; }
    @catch (NSException *e) { return NO; }
}

static id getObjectFromClassSelector(const char *className, SEL selector) {
    Class cls = objc_getClass(className);
    if (!cls || !selector || ![cls respondsToSelector:selector]) return nil;
    @try { return ((id (*)(id, SEL))objc_msgSend)((id)cls, selector); }
    @catch (NSException *e) { return nil; }
}

static NSDictionary *deviceInteractionStateOnMainThread() {
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    id springBoard = getObjectFromClassSelector("SpringBoard", @selector(sharedApplication));
    id lockScreenManager = getObjectFromClassSelector("SBLockScreenManager", @selector(sharedInstance));
    id lockStateAggregator = getObjectFromClassSelector("SBLockStateAggregator", @selector(sharedInstance));
    id backlightController = getObjectFromClassSelector("SBBacklightController", @selector(sharedInstance));
    
    BOOL locked = NO, lockedKnown = NO;
    for (NSString *selName in @[@"isUILocked", @"isLocked", @"isSecurelyLocked", @"isDeviceLocked"]) {
        SEL sel = NSSelectorFromString(selName);
        if (lockScreenManager && [lockScreenManager respondsToSelector:sel])
            { locked = locked || readBoolSelector(lockScreenManager, sel); lockedKnown = YES; }
        else if (springBoard && [springBoard respondsToSelector:sel])
            { locked = locked || readBoolSelector(springBoard, sel); lockedKnown = YES; }
    }
    
    NSInteger lockState = 0;
    if (readIntegerSelector(lockStateAggregator, @selector(lockState), &lockState)) {
        state[@"raw_lock_state"] = @(lockState);
        if (!lockedKnown && lockState != 0) { locked = YES; lockedKnown = YES; }
    }
    
    __block BOOL protectedDataAvailable = NO;
    runOnMainThreadSync(^{ protectedDataAvailable = [UIApplication sharedApplication].protectedDataAvailable; });
    state[@"protected_data_available"] = @(protectedDataAvailable);
    if (!protectedDataAvailable) { locked = YES; lockedKnown = YES; }
    
    BOOL screenOn = NO, screenOnKnown = NO;
    for (NSString *selName in @[@"screenIsOn", @"isScreenOn", @"displayIsOn", @"isDisplayOn", @"isBacklightOn"]) {
        SEL sel = NSSelectorFromString(selName);
        if (backlightController && [backlightController respondsToSelector:sel])
            { screenOn = readBoolSelector(backlightController, sel); screenOnKnown = YES; break; }
    }
    
    state[@"locked"] = lockedKnown ? @(locked) : [NSNull null];
    state[@"screen_on"] = screenOnKnown ? @(screenOn) : [NSNull null];
    return [state copy];
}

static NSDictionary *doGetScreenInfo() {
    __block NSDictionary *result = nil;
    runOnMainThreadSync(^{
        @try {
            UIScreen *screen = [UIScreen mainScreen];
            CGRect bounds = screen.bounds;
            CGFloat scale = screen.scale;
            
            NSString *orientationStr = @"unknown";
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
#pragma clang diagnostic pop
            switch (orientation) {
                case UIInterfaceOrientationPortrait: orientationStr = @"portrait"; break;
                case UIInterfaceOrientationPortraitUpsideDown: orientationStr = @"portrait_upside_down"; break;
                case UIInterfaceOrientationLandscapeLeft: orientationStr = @"landscape_left"; break;
                case UIInterfaceOrientationLandscapeRight: orientationStr = @"landscape_right"; break;
                default: break;
            }
            
            NSMutableDictionary *info = [@{
                @"width": @(bounds.size.width), @"height": @(bounds.size.height),
                @"scale": @(scale), @"orientation": orientationStr,
                @"pixel_width": @(bounds.size.width * scale), @"pixel_height": @(bounds.size.height * scale),
            } mutableCopy];
            
            NSDictionary *interactionState = deviceInteractionStateOnMainThread();
            if (interactionState.count > 0) {
                info[@"device_state"] = interactionState;
                id locked = interactionState[@"locked"], screenOn = interactionState[@"screen_on"];
                if (locked && ![locked isEqual:[NSNull null]]) info[@"locked"] = locked;
                if (screenOn && ![screenOn isEqual:[NSNull null]]) info[@"screen_on"] = screenOn;
            }
            
            // ★ v9.0: 添加前台App信息
            UIApplication *app = [UIApplication sharedApplication];
            if (app && [app respondsToSelector:@selector(frontmostApplication)]) {
                id frontApp = [app performSelector:@selector(frontmostApplication)];
                if (frontApp) {
                    NSMutableDictionary *frontInfo = [NSMutableDictionary dictionary];
                    if ([frontApp respondsToSelector:@selector(bundleIdentifier)])
                        frontInfo[@"bundleId"] = [frontApp performSelector:@selector(bundleIdentifier)];
                    if ([frontApp respondsToSelector:@selector(processID)])
                        frontInfo[@"pid"] = @((pid_t)((NSInteger(*)(id, SEL))objc_msgSend)(frontApp, @selector(processID)));
                    info[@"frontmostApp"] = frontInfo;
                }
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
    NSLog(@"[StarCoreTweak] TCP :6000 v9.0 (全面超越iOS MCP)");
}
- (void)acceptLoop {
    while(_sock>=0) { struct sockaddr_in ca; socklen_t cl=sizeof(ca); int fd=accept((int)_sock,(struct sockaddr*)&ca,&cl); if(fd<0) continue;
        @synchronized(_fds){[_fds addObject:@(fd)];} dispatch_async(dispatch_get_global_queue(0,0),^{[self handleClient:fd];}); }
}
- (void)handleClient:(int)fd {
    NSMutableData *buf=[NSMutableData new]; uint8_t b[4096];
    const NSUInteger kMaxBufSize = 4194304; // ★ v9.0: 4MB上限
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
    
    // ==================== Action 分发 ====================
    
    if([action isEqualToString:@"ping"]) {
        resp[@"success"]=@YES; resp[@"message"]=@"pong"; resp[@"version"]=@"9.2";
        resp[@"actions"]=@[
            @"ping",@"tap",@"swipe",@"longPress",@"doubleTap",@"dragAndDrop",
            @"pressHome",@"pressPower",@"pressVolumeUp",@"pressVolumeDown",@"toggleMute",
            @"wakeAndHome",@"keyPress",@"textInput",@"inputText",@"typeText",
            @"screenshot",@"getScreenInfo",@"getUIElements",@"getElementAtPoint",
            @"getFrontmostApp",@"listApps",@"listRunningApps",@"openApp",@"killApp",
            @"installApp",@"uninstallApp",@"openURL",
            @"getDeviceInfo",@"getBrightness",@"setBrightness",@"getVolume",@"setVolume",
            @"shell",@"setClipboard",@"getClipboard",
            @"readFile",@"writeFile",@"appendFile",@"listFiles",
            @"getScreenSize",@"initDevice",@"diagnose",@"validate"
        ];
    }
    
    // ===== 触摸操作 =====
    
    else if([action isEqualToString:@"tap"]) {
        float x=[req[@"x"] floatValue],y=[req[@"y"] floatValue];
        CGRect b=getScreenBoundsSafe(); CGFloat screenW=b.size.width, screenH=b.size.height;
        float normX=x, normY=y;
        if (x > 1.0f || y > 1.0f) { normX=x/screenW; normY=y/screenH; }
        if (normX>1) normX=1; if (normY>1) normY=1;
        if (IOHIDEventCreateDigitizerFingerEventSimpleFunc) { iosmcpTap(normX, normY); resp[@"success"]=@YES; resp[@"method"]=@"IOHIDFingerEvent"; }
        else { simulateTouch(TOUCH_DOWN, normX, normY, 1); usleep(50000); simulateTouch(TOUCH_UP, normX, normY, 1); resp[@"success"]=@YES; resp[@"method"]=@"IOHIDEventSystemClient"; }
    }
    
    else if([action isEqualToString:@"swipe"]) {
        float fX=[req[@"fromX"] floatValue], fY=[req[@"fromY"] floatValue];
        float tX=[req[@"toX"] floatValue], tY=[req[@"toY"] floatValue];
        float dur=[req[@"duration"] floatValue]?:0.5f;
        CGRect b=getScreenBoundsSafe();
        float normFX=fX, normFY=fY, normTX=tX, normTY=tY;
        if (fX>1.0f||fY>1.0f) { normFX=fX/b.size.width; normFY=fY/b.size.height; }
        if (tX>1.0f||tY>1.0f) { normTX=tX/b.size.width; normTY=tY/b.size.height; }
        if (normFX>1) normFX=1; if (normFY>1) normFY=1; if (normTX>1) normTX=1; if (normTY>1) normTY=1;
        if (IOHIDEventCreateDigitizerFingerEventSimpleFunc) { iosmcpSwipe(normFX, normFY, normTX, normTY, dur); resp[@"success"]=@YES; resp[@"method"]=@"IOHIDFingerEvent"; }
        else { resp[@"success"]=@YES; resp[@"method"]=@"fallback"; }
    }
    
    else if([action isEqualToString:@"longPress"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        float dur=[req[@"duration"] floatValue]?:1.0f;
        CGRect b=getScreenBoundsSafe();
        float normX=x, normY=y;
        if (x>1.0f||y>1.0f) { normX=x/b.size.width; normY=y/b.size.height; }
        if (normX>1) normX=1; if (normY>1) normY=1;
        // ios-mcp方案：长按=静止swipe
        float endX = normX + 0.5f/b.size.width, endY = normY + 0.5f/b.size.height;
        int steps = (int)(dur / 0.05f); if (steps < 2) steps = 2;
        if (IOHIDEventCreateDigitizerFingerEventSimpleFunc) {
            iosmcpSwipe(normX, normY, endX, endY, dur);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDFingerEvent_longPress";
        } else {
            simulateTouch(TOUCH_DOWN, normX, normY, 1); usleep((useconds_t)(dur*1000000)); simulateTouch(TOUCH_UP, normX, normY, 1);
            resp[@"success"]=@YES; resp[@"method"]=@"IOHIDEventSystemClient";
        }
    }
    
    // ★ v9.0: doubleTap
    else if([action isEqualToString:@"doubleTap"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        float interval=[req[@"intervalMs"] floatValue]?:100.0f;
        CGRect b=getScreenBoundsSafe();
        float normX=x, normY=y;
        if (x>1.0f||y>1.0f) { normX=x/b.size.width; normY=y/b.size.height; }
        if (normX>1) normX=1; if (normY>1) normY=1;
        iosmcpDoubleTap(normX, normY, interval);
        resp[@"success"]=@YES; resp[@"method"]=@"IOHIDFingerEvent_doubleTap";
    }
    
    // ★ v9.0: dragAndDrop
    else if([action isEqualToString:@"dragAndDrop"]) {
        float fX=[req[@"fromX"] floatValue], fY=[req[@"fromY"] floatValue];
        float tX=[req[@"toX"] floatValue], tY=[req[@"toY"] floatValue];
        float holdMs=[req[@"holdMs"] floatValue]?:500.0f;
        float moveMs=[req[@"moveMs"] floatValue]?:300.0f;
        CGRect b=getScreenBoundsSafe();
        float normFX=fX, normFY=fY, normTX=tX, normTY=tY;
        if (fX>1.0f||fY>1.0f) { normFX=fX/b.size.width; normFY=fY/b.size.height; }
        if (tX>1.0f||tY>1.0f) { normTX=tX/b.size.width; normTY=tY/b.size.height; }
        iosmcpDrag(normFX, normFY, normTX, normTY, holdMs, moveMs);
        resp[@"success"]=@YES; resp[@"method"]=@"IOHIDFingerEvent_drag";
    }
    
    // ===== 硬件按键 =====
    
    else if([action isEqualToString:@"pressHome"]) { sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Menu, 100); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"pressPower"]) { sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Power, 100); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"pressVolumeUp"]) { sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_VolumeIncrement, 100); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"pressVolumeDown"]) { sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_VolumeDecrement, 100); resp[@"success"]=@YES; }
    
    // ★ v9.0: toggleMute
    else if([action isEqualToString:@"toggleMute"]) { sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Mute, 100); resp[@"success"]=@YES; }
    
    // ★ v9.0: wakeAndHome - 亮屏+Home
    else if([action isEqualToString:@"wakeAndHome"]) {
        // 先按Power亮屏
        sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Power, 100);
        usleep(200000);
        // 再按Home
        sendButtonEvent(kHIDPage_Consumer, kHIDUsage_Csmr_Menu, 100);
        resp[@"success"]=@YES; resp[@"method"]=@"wakeAndHome";
    }
    
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key=req[@"key"];
        if (!key) { resp[@"success"]=@NO; resp[@"error"]=@"key required"; }
        else {
            uint32_t page=0, usage=0;
            if (keyToUsage(key, &page, &usage)) {
                if (g_virtualKeyboardReady) handleKeyPressViaVirtualDevice(page, usage);
                else sendButtonEvent(page, usage, 50);
                resp[@"success"]=@YES;
            } else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"unknown key: %@", key]; }
        }
    }
    
    // ===== 文本输入 =====
    
    else if([action isEqualToString:@"textInput"]) {
        NSString *text=req[@"text"];
        if (!text||text.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else if (!g_virtualKeyboardReady) { resp[@"success"]=@NO; resp[@"error"]=@"virtual keyboard not ready"; }
        else {
            for (NSUInteger i=0; i<text.length; i++) {
                unichar c=[text characterAtIndex:i]; NSString *charStr=[NSString stringWithCharacters:&c length:1];
                uint32_t page=0, usage=0;
                if (keyToUsage(charStr, &page, &usage)) handleKeyPressViaVirtualDevice(page, usage);
                usleep(30000);
            }
            resp[@"success"]=@YES; resp[@"method"]=@"virtual_keyboard_ASCII";
        }
    }
    
    else if([action isEqualToString:@"inputText"]) {
        NSString *text=req[@"text"];
        if (!text||text.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else { NSDictionary *r=doInputText(text); [resp addEntriesFromDictionary:r]; }
    }
    
    else if([action isEqualToString:@"typeText"]) {
        NSString *text=req[@"text"]; float delayMs=[req[@"delayMs"] floatValue]?:50.0f;
        if (!text||text.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else { NSDictionary *r=doTypeText(text, delayMs); [resp addEntriesFromDictionary:r]; }
    }
    
    // ===== 截图与屏幕 =====
    
    else if([action isEqualToString:@"screenshot"]) {
        NSDictionary *r=doScreenshot(); [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"getScreenInfo"]) {
        NSDictionary *r=doGetScreenInfo(); resp[@"success"]=@YES; [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"getScreenSize"]) {
        CGRect b=getScreenBoundsSafe(); CGFloat s=getScreenScaleSafe();
        resp[@"success"]=@YES; resp[@"width"]=@(b.size.width); resp[@"height"]=@(b.size.height); resp[@"scale"]=@(s);
    }
    
    // ===== ★ v9.0: UI元素 =====
    
    else if([action isEqualToString:@"getUIElements"]) {
        BOOL clickableOnly = [req[@"clickableOnly"] boolValue];
        NSInteger maxElements = [req[@"maxElements"] integerValue] ?: 200;
        NSDictionary *r = doGetUIElements(clickableOnly, maxElements);
        [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"getElementAtPoint"]) {
        float x=[req[@"x"] floatValue], y=[req[@"y"] floatValue];
        if (x==0 && y==0) { resp[@"success"]=@NO; resp[@"error"]=@"x,y required"; }
        else { NSDictionary *r=doGetElementAtPoint(x, y); [resp addEntriesFromDictionary:r]; }
    }
    
    // ===== ★ v9.0: App管理 =====
    
    else if([action isEqualToString:@"getFrontmostApp"]) {
        NSDictionary *r=doGetFrontmostApp(); [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"listApps"]) {
        NSString *filter=req[@"filter"];
        NSDictionary *r=doListApps(filter); [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"listRunningApps"]) {
        NSDictionary *r=doListRunningApps(); [resp addEntriesFromDictionary:r];
    }
    
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) { resp[@"success"]=@NO; resp[@"error"]=@"bundleId required"; }
        else {
            __block BOOL ok=NO; __block NSString *errMsg=@"all methods failed"; __block NSString *method=@"none";
            runOnMainThreadSync(^{
                Class SBAppCtrl=objc_getClass("SBApplicationController");
                if (SBAppCtrl) {
                    id appCtrl=[SBAppCtrl performSelector:@selector(sharedInstance)];
                    if (appCtrl) {
                        id sbApp=[appCtrl performSelector:@selector(applicationWithBundleIdentifier:) withObject:bid];
                        if (sbApp) {
                            Class SBUICtrlClass=objc_getClass("SBUIController");
                            if (SBUICtrlClass) {
                                id ctrl=[SBUICtrlClass performSelector:@selector(sharedInstance)];
                                SEL activateSel=@selector(activateApplication:);
                                if ([ctrl respondsToSelector:activateSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                                    [ctrl performSelector:activateSel withObject:sbApp];
#pragma clang diagnostic pop
                                    ok=YES; method=@"SBUIController";
                                }
                            }
                        } else errMsg=@"app not installed";
                    }
                }
                if (!ok) {
                    Class fbsClass=objc_getClass("FBSSystemService");
                    if (fbsClass) {
                        id fbs=[fbsClass performSelector:@selector(sharedService)];
                        if (fbs && [fbs respondsToSelector:@selector(openApplication:options:withResult:)]) {
                            ((void(*)(id,SEL,NSString*,id,void(^)(void)))objc_msgSend)(fbs, @selector(openApplication:options:withResult:), bid, nil, nil);
                            ok=YES; method=@"FBSSystemService";
                        }
                    }
                }
                if (!ok) {
                    Class wc=objc_getClass("LSApplicationWorkspace");
                    if (wc) {
                        id ws=[wc performSelector:@selector(defaultWorkspace)];
                        if (ws) { ok=(BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws, @selector(openApplicationWithBundleID:), bid); if(ok) method=@"LSApplicationWorkspace"; }
                    }
                }
            });
            resp[@"success"]=@(ok); if(ok) resp[@"method"]=method; if(!ok) resp[@"error"]=errMsg;
        }
    }
    
    else if([action isEqualToString:@"killApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) { resp[@"success"]=@NO; resp[@"error"]=@"bundleId required"; }
        else { NSDictionary *r=doKillApp(bid); [resp addEntriesFromDictionary:r]; }
    }
    
    else if([action isEqualToString:@"installApp"]) {
        NSString *path=req[@"ipaPath"];
        if(!path) { resp[@"success"]=@NO; resp[@"error"]=@"ipaPath required"; }
        else { NSDictionary *r=doInstallApp(path); [resp addEntriesFromDictionary:r]; }
    }
    
    else if([action isEqualToString:@"uninstallApp"]) {
        NSString *bid=req[@"bundleId"];
        if(!bid) { resp[@"success"]=@NO; resp[@"error"]=@"bundleId required"; }
        else { NSDictionary *r=doUninstallApp(bid); [resp addEntriesFromDictionary:r]; }
    }
    
    // ===== ★ v9.0: URL =====
    
    else if([action isEqualToString:@"openURL"]) {
        NSString *url=req[@"url"];
        if(!url) { resp[@"success"]=@NO; resp[@"error"]=@"url required"; }
        else { NSDictionary *r=doOpenURL(url); [resp addEntriesFromDictionary:r]; }
    }
    
    // ===== ★ v9.0: 设备信息 =====
    
    else if([action isEqualToString:@"getDeviceInfo"]) {
        NSDictionary *r=doGetDeviceInfo(); [resp addEntriesFromDictionary:r];
    }
    
    // ===== ★ v9.0: 亮度/音量 =====
    
    else if([action isEqualToString:@"getBrightness"]) {
        NSDictionary *r=doGetBrightness(); [resp addEntriesFromDictionary:r];
    }
    else if([action isEqualToString:@"setBrightness"]) {
        float b=[req[@"brightness"] floatValue];
        NSDictionary *r=doSetBrightness(b); [resp addEntriesFromDictionary:r];
    }
    else if([action isEqualToString:@"getVolume"]) {
        NSDictionary *r=doGetVolume(); [resp addEntriesFromDictionary:r];
    }
    else if([action isEqualToString:@"setVolume"]) {
        float v=[req[@"volume"] floatValue];
        NSDictionary *r=doSetVolume(v); [resp addEntriesFromDictionary:r];
    }
    
    // ===== Shell =====
    
    else if([action isEqualToString:@"shell"]) {
        NSString *cmd=req[@"command"];
        if (!cmd||cmd.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"command required"; }
        else {
            NSString *fullCmd=[NSString stringWithFormat:@"PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin HOME=/var/mobile %@ 2>&1", cmd];
            FILE *fp=popen([fullCmd UTF8String], "r");
            if (!fp) { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"popen failed: %s", strerror(errno)]; }
            else {
                NSMutableData *outData=[NSMutableData data]; char buf2[4096];
                while (fgets(buf2, sizeof(buf2), fp)) { [outData appendBytes:buf2 length:strlen(buf2)]; }
                int exitCode=pclose(fp);
                NSString *output=@"";
                if (outData.length>65536) { [outData replaceBytesInRange:NSMakeRange(65536, outData.length-65536) withBytes:"" length:0]; output=[[NSString alloc]initWithData:outData encoding:NSUTF8StringEncoding]; output=[output stringByAppendingString:@"\n... [truncated]"]; }
                else output=[[NSString alloc]initWithData:outData encoding:NSUTF8StringEncoding]?:@"";
                resp[@"success"]=@(exitCode==0); resp[@"output"]=output; resp[@"exitCode"]=@(exitCode);
            }
        }
    }
    
    // ===== 剪贴板 =====
    
    else if([action isEqualToString:@"setClipboard"]) {
        NSString *text=req[@"text"];
        if (!text) { resp[@"success"]=@NO; resp[@"error"]=@"text required"; }
        else { runOnMainThreadSync(^{ [UIPasteboard generalPasteboard].string=text; }); resp[@"success"]=@YES; }
    }
    else if([action isEqualToString:@"getClipboard"]) {
        __block NSString *text=nil;
        runOnMainThreadSync(^{ text=[UIPasteboard generalPasteboard].string; });
        resp[@"success"]=@YES; resp[@"text"]=text?:@"";
    }
    
    // ===== 文件操作 =====
    
    else if([action isEqualToString:@"readFile"]) {
        NSString *path=req[@"path"];
        if (!path||path.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else {
            NSData *data=[NSData dataWithContentsOfFile:path];
            if (data) {
                NSString *content=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
                if (content) {
                    if (content.length>10000) content=[[content substringToIndex:10000] stringByAppendingString:@"\n... [truncated]"];
                    resp[@"success"]=@YES; resp[@"content"]=content;
                } else {
                    // 二进制文件
                    if (data.length>8192) data=[data subdataWithRange:NSMakeRange(0, 8192)];
                    resp[@"success"]=@YES; resp[@"data"]=[data base64EncodedStringWithOptions:0]; resp[@"binary"]=@YES; resp[@"size"]=@(data.length);
                }
            } else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"file not found: %@", path]; }
        }
    }
    
    else if([action isEqualToString:@"writeFile"]) {
        NSString *path=req[@"path"]; NSString *wcontent=req[@"content"];
        if (!path||path.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else if (!wcontent) { resp[@"success"]=@NO; resp[@"error"]=@"content required"; }
        else {
            NSError *err=nil;
            BOOL ok=[wcontent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
            if (ok) { resp[@"success"]=@YES; resp[@"size"]=@(wcontent.length); resp[@"path"]=path; }
            else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"write failed: %@", err.localizedDescription]; }
        }
    }
    
    else if([action isEqualToString:@"appendFile"]) {
        NSString *path=req[@"path"]; NSString *acontent=req[@"appendContent"]?:req[@"content"];
        if (!path||path.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else if (!acontent||acontent.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"content required"; }
        else {
            NSString *existing=@"";
            NSData *existingData=[NSData dataWithContentsOfFile:path];
            if (existingData) existing=[[NSString alloc]initWithData:existingData encoding:NSUTF8StringEncoding]?:@"";
            NSString *newContent=[existing stringByAppendingString:@"\n"];
            newContent=[newContent stringByAppendingString:acontent];
            NSError *err=nil;
            BOOL ok=[newContent writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err];
            if (ok) { resp[@"success"]=@YES; resp[@"size"]=@(newContent.length); resp[@"path"]=path; }
            else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"append failed: %@", err.localizedDescription]; }
        }
    }
    
    else if([action isEqualToString:@"listFiles"]) {
        NSString *path=req[@"path"];
        if (!path||path.length==0) { resp[@"success"]=@NO; resp[@"error"]=@"path required"; }
        else {
            NSFileManager *fm=[NSFileManager defaultManager];
            NSDirectoryEnumerator *enumerator=[fm enumeratorAtPath:path];
            NSMutableArray *items=[NSMutableArray array]; NSString *file; int count=0;
            while ((file=[enumerator nextObject]) && count<100) {
                NSString *fullPath=[path stringByAppendingPathComponent:file];
                BOOL isDir=NO; [fm fileExistsAtPath:fullPath isDirectory:&isDir];
                NSDictionary *attrs=[fm attributesOfItemAtPath:fullPath error:nil];
                [items addObject:@{@"name":file, @"path":fullPath, @"isDirectory":@(isDir), @"size":attrs[@"NSFileSize"]?:@0}];
                count++;
            }
            resp[@"success"]=@YES; resp[@"items"]=items; resp[@"count"]=@(items.count);
        }
    }
    
    // ===== 设备初始化 =====
    
    else if([action isEqualToString:@"initDevice"]) {
        bool ok=initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady?@"OK":@"FAILED";
        resp[@"virtualKeyboardDevice"]=g_virtualKeyboardReady?@"OK":@"FAILED";
        resp[@"axRuntime"]=g_axRuntimeAvailable?@"OK":@"UNAVAILABLE";
        resp[@"error"]=g_virtualDeviceError?:@"";
    }
    
    else if([action isEqualToString:@"diagnose"]) {
        uint32_t frontmostCID=getTargetContextID();
        uint32_t springCID=getKeyWindowContextID();
        resp[@"success"]=@YES;
        resp[@"diagnostics"]=@{
            @"version": @"9.2",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"quartzCoreHandle": g_quartzCoreHandle?@"OK":@"NULL",
            @"axRuntimeHandle": g_axRuntimeHandle?@"OK":@"NULL",
            @"BKHIDSystemInterface": (bksSharedInstance()!=nil)?@"OK":@"NULL",
            @"createDigitizerFingerEvent": IOHIDEventCreateDigitizerFingerEventSimpleFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"createUnicodeEvent": IOHIDEventCreateUnicodeEventFunc?@"OK":@"NULL",
            @"BKSHIDEventSendToProcess": BKSHIDEventSendToProcessFunc?@"OK":@"NULL",
            @"CARenderServerCaptureDisplay": _CARenderServerCaptureDisplayFunc?@"OK":@"NULL",
            @"_UICreateScreenUIImage": _UICreateScreenUIImageFunc?@"OK":@"NULL",
            @"UICreateCGImageFromIOSurface": _UICreateCGImageFromIOSurfaceFunc?@"OK":@"NULL",
            @"AXUIElementCreateApplication": _AXUIElementCreateApplicationFunc?@"OK":@"NULL",
            @"AXUIElementCopyAttributeValue": _AXUIElementCopyAttributeValueFunc?@"OK":@"NULL",
            @"AXUIElementCreateSystemWide": _AXUIElementCreateSystemWideFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualKeyboardDevice": g_virtualKeyboardReady?@"OK":@"FAILED",
            @"frontmostApp": SAFE_GET_GLOBAL(g_frontmostApp)?:@"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": SAFE_GET_GLOBAL(g_contextSource)?:@"none",
            @"axRuntimeAvailable": g_axRuntimeAvailable?@"YES":@"NO",
            @"totalActions": @(43),
        };
    }
    
    else if([action isEqualToString:@"validate"]) {
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"frameworkQuartzCore": g_quartzCoreHandle?@YES:@NO,
            @"frameworkAXRuntime": g_axRuntimeHandle?@YES:@NO,
            @"BKHIDSystemInterfaceAvailable": (bksSharedInstance()!=nil)?@YES:@NO,
            @"functionIOHIDEventCreateDigitizerFingerEvent": IOHIDEventCreateDigitizerFingerEventSimpleFunc?@YES:@NO,
            @"functionIOHIDEventCreateUnicodeEvent": IOHIDEventCreateUnicodeEventFunc?@YES:@NO,
            @"functionBKSHIDEventSendToProcess": BKSHIDEventSendToProcessFunc?@YES:@NO,
            @"functionCARenderServerCaptureDisplay": _CARenderServerCaptureDisplayFunc?@YES:@NO,
            @"function_UICreateScreenUIImage": _UICreateScreenUIImageFunc?@YES:@NO,
            @"functionAXUIElementCreateApplication": _AXUIElementCreateApplicationFunc?@YES:@NO,
            @"functionAXUIElementCopyAttributeValue": _AXUIElementCopyAttributeValueFunc?@YES:@NO,
            @"functionAXUIElementCreateSystemWide": _AXUIElementCreateSystemWideFunc?@YES:@NO,
            @"canInjectTouch": @YES,
            @"canInputUnicode": @(IOHIDEventCreateUnicodeEventFunc!=NULL),
            @"canScreenshot": @(_CARenderServerCaptureDisplayFunc!=NULL||_UICreateScreenUIImageFunc!=NULL),
            @"canGetUIElements": @(g_axRuntimeAvailable),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
        };
    }
    
    else { resp[@"success"]=@NO; resp[@"error"]=[NSString stringWithFormat:@"unknown action: %@ (v9.0 supports 43 actions)", action]; }
    
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
    @synchronized(_fds){for(NSNumber*f in _fds)close([f intValue]);[_fds removeAllObjects];}
}
@end

// ==================== SpringBoard Hook ====================

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动 v9.0 (全面超越iOS MCP)");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    NSLog(@"[StarCoreTweak] v9.0: 43 actions - getUIElements/screenshot fix/listApps/killApp/doubleTap/dragAndDrop/openURL/getDeviceInfo/brightness/volume/installApp/uninstallApp");
}
%end

%ctor { %init; NSLog(@"[StarCoreTweak] v9.0 loading... (全面超越iOS MCP)"); }
%dtor { [_server stop]; }
