/**
 * StarCoreTweak.xm v4.3 - 动态contextID修复触摸注入
 * 
 * v4.2问题：tap/swipe无效，因为BKSHIDEventSetDigitizerInfo用的是SpringBoard的contextID
 * 修复：动态获取前台app的contextID，而不是使用SpringBoard的contextID
 * 
 * v4.3修改：
 * 1. 添加getTargetContextID()动态获取前台app contextID
 * 2. 添加testTouch诊断命令
 * 3. 更新diagnose命令显示更多contextID信息
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

// ==================== 私有类型 ====================
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

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
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, float, float, float, float, float, bool, bool, uint32_t) = NULL;
static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;
static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;

// ★ v4.3: BKSHIDEventSetDigitizerInfo（触摸路由必需）
// 签名：void BKSHIDEventSetDigitizerInfo(IOHIDEventRef event, uint32_t contextID, uint8_t defaultDigitizer, uint8_t systemGestureisPossible, CFStringRef context, CFTimeInterval timestamp, float initialPressure)
static void (*BKSHIDEventSetDigitizerInfoFunc)(IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float) = NULL;

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL;

// ★ v4.3: 全局存储contextID来源信息
static uint32_t g_springBoardContextID = 2939785827; // 已验证的SpringBoard contextID
static NSString *g_contextSource = @"none";
static NSString *g_frontmostApp = @"";

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
    
    #undef LOAD_SYM
    
    if (!IOHIDEventCreateDigitizerEventFunc) { NSLog(@"[StarCoreTweak] ❌ 核心函数缺失"); return false; }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ v4.3 函数加载成功 (BKSHIDEventSetDigitizerInfo=%@)", BKSHIDEventSetDigitizerInfoFunc ? @"OK" : @"NULL");
    return true;
}

// ==================== v4.3: 动态获取前台app的contextID ====================

// 方法1: 通过CAWindowServer枚举获取contextID
static uint32_t getContextIDFromCAWindowServer() {
    // 尝试获取CAWindowServer类
    Class wsClass = objc_getClass("CAWindowServer");
    if (!wsClass) {
        wsClass = NSClassFromString(@"CAWindowServer");
    }
    
    if (!wsClass) {
        NSLog(@"[StarCoreTweak] ⚠️ CAWindowServer class not found");
        return 0;
    }
    
    // 获取CAWindowServer单例
    SEL serverSel = NSSelectorFromString(@"serverIfRunning");
    if (![wsClass respondsToSelector:serverSel]) {
        NSLog(@"[StarCoreTweak] ⚠️ CAWindowServer serverIfRunning not available");
        return 0;
    }
    
    id ws = [wsClass performSelector:serverSel];
    if (!ws) {
        NSLog(@"[StarCoreTweak] ⚠️ CAWindowServer instance is nil");
        return 0;
    }
    
    // 获取context列表
    SEL contextsSel = NSSelectorFromString(@"contexts");
    NSArray *contexts = nil;
    
    if ([ws respondsToSelector:contextsSel]) {
        contexts = [ws performSelector:contextsSel];
    } else {
        // 尝试其他可能的选择器
        NSLog(@"[StarCoreTweak] contexts selector not available, trying alternatives");
        
        // 尝试通过实例变量或其他方法获取
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(object_getClass(ws), &ivarCount);
        for (unsigned int i = 0; i < ivarCount; i++) {
            NSLog(@"[StarCoreTweak] CAWindowServer ivar: %s", ivar_getName(ivars[i]));
        }
        if (ivars) free(ivars);
        
        return 0;
    }
    
    if (!contexts || contexts.count == 0) {
        NSLog(@"[StarCoreTweak] ⚠️ No contexts found in CAWindowServer");
        return 0;
    }
    
    pid_t myPid = getpid();
    pid_t springBoardPid = 0;
    uint32_t bestCID = 0;
    int bestLayer = -1;
    
    for (id ctx in contexts) {
        pid_t ctxPid = 0;
        uint32_t cid = 0;
        int layer = 0;
        
        // 获取pid
        if ([ctx respondsToSelector:@selector(pid)]) {
            ctxPid = (pid_t)(long)[ctx performSelector:@selector(pid)];
        }
        
        // 获取contextId
        if ([ctx respondsToSelector:@selector(contextId)]) {
            cid = (uint32_t)(long)[ctx performSelector:@selector(contextId)];
        }
        
        // 获取layer（用于判断是否是前台窗口）
        if ([ctx respondsToSelector:@selector(layer)]) {
            layer = (int)(long)[ctx performSelector:@selector(layer)];
        }
        
        // 跳过SpringBoard进程和无效contextID
        if (cid == 0) continue;
        
        // 记录SpringBoard的PID
        if (cid == g_springBoardContextID) {
            NSLog(@"[StarCoreTweak] Found SpringBoard contextID=%u", cid);
            continue;
        }
        
        // 找非SpringBoard进程且layer最大的contextID
        if (ctxPid != myPid && layer > bestLayer) {
            bestLayer = layer;
            bestCID = cid;
            NSLog(@"[StarCoreTweak] Found frontmost contextID=%u pid=%d layer=%d", cid, ctxPid, layer);
        }
    }
    
    return bestCID;
}

// 方法2: 通过SBS获取前台app
static uint32_t getContextIDFromSBS() {
    // 尝试获取前台app的bundleID
    Class sbAppClass = objc_getClass("SBApplication");
    if (!sbAppClass) {
        NSLog(@"[StarCoreTweak] ⚠️ SBApplication class not found");
        return 0;
    }
    
    // 获取前台应用
    Class sbCtrlClass = objc_getClass("SBApplicationController");
    if (!sbCtrlClass) {
        NSLog(@"[StarCoreTweak] ⚠️ SBApplicationController class not found");
        return 0;
    }
    
    id ctrl = [sbCtrlClass performSelector:@selector(sharedInstance)];
    if (!ctrl) {
        NSLog(@"[StarCoreTweak] ⚠️ SBApplicationController sharedInstance is nil");
        return 0;
    }
    
    // 尝试获取frontmostApplication
    id frontApp = nil;
    if ([ctrl respondsToSelector:@selector(frontmostApplication)]) {
        frontApp = [ctrl performSelector:@selector(frontmostApplication)];
    }
    
    if (!frontApp) {
        NSLog(@"[StarCoreTweak] ⚠️ frontmostApplication is nil");
        return 0;
    }
    
    NSString *bundleID = nil;
    if ([frontApp respondsToSelector:@selector(bundleIdentifier)]) {
        bundleID = [frontApp performSelector:@selector(bundleIdentifier)];
        g_frontmostApp = bundleID ?: @"";
        NSLog(@"[StarCoreTweak] frontmost app: %@", bundleID);
    }
    
    // 尝试从frontApp获取contextID
    if ([frontApp respondsToSelector:@selector(contextIdentifier)]) {
        uint32_t cid = (uint32_t)(long)[frontApp performSelector:@selector(contextIdentifier)];
        if (cid != 0) {
            NSLog(@"[StarCoreTweak] contextID from SBApplication.contextIdentifier: %u", cid);
            return cid;
        }
    }
    
    // 尝试获取mainScene
    if ([frontApp respondsToSelector:@selector(mainScene)]) {
        id scene = [frontApp performSelector:@selector(mainScene)];
        if (scene && [scene respondsToSelector:@selector(contextIdentifier)]) {
            uint32_t cid = (uint32_t)(long)[scene performSelector:@selector(contextIdentifier)];
            if (cid != 0) {
                NSLog(@"[StarCoreTweak] contextID from mainScene: %u", cid);
                return cid;
            }
        }
    }
    
    return 0;
}

// 方法3: 通过UIWindow获取（备选）
static uint32_t getContextIDFromUIWindow() {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return 0;
    
    // 遍历所有window找前台app的window
    for (UIWindow *window in app.windows) {
        // 跳过keyWindow（通常是SpringBoard的）
        // 尝试找非keyWindow
        if (window.isKeyWindow) continue;
        
        uint32_t ctxId = 0;
        @try { 
            if ([window respondsToSelector:@selector(_contextId)]) {
                ctxId = (uint32_t)(long)[window performSelector:@selector(_contextId)];
            }
        } @catch (NSException *e) {}
        
        if (ctxId && ctxId != g_springBoardContextID) {
            NSLog(@"[StarCoreTweak] contextID=%u from non-keyWindow", ctxId);
            return ctxId;
        }
    }
    
    // 如果没找到，返回keyWindow的contextID
    UIWindow *keyWindow = [app keyWindow];
    if (keyWindow) {
        uint32_t ctxId = 0;
        @try {
            if ([keyWindow respondsToSelector:@selector(_contextId)]) {
                ctxId = (uint32_t)(long)[keyWindow performSelector:@selector(_contextId)];
            }
        } @catch (NSException *e) {}
        
        if (ctxId) {
            NSLog(@"[StarCoreTweak] contextID=%u from keyWindow (fallback)", ctxId);
            return ctxId;
        }
    }
    
    NSLog(@"[StarCoreTweak] ⚠️ contextID=0 (no window found)");
    return 0;
}

// ★ v4.3核心: 动态获取目标contextID
static uint32_t getTargetContextID() {
    // 方法1: CAWindowServer枚举（优先）
    uint32_t cid = getContextIDFromCAWindowServer();
    if (cid != 0) {
        g_contextSource = @"CAWindowServer";
        return cid;
    }
    
    // 方法2: SBS API
    cid = getContextIDFromSBS();
    if (cid != 0) {
        g_contextSource = @"SBS";
        return cid;
    }
    
    // 方法3: UIWindow（备选）
    cid = getContextIDFromUIWindow();
    if (cid != 0) {
        g_contextSource = @"UIWindow";
        return cid;
    }
    
    // 最终fallback: 返回0，让触摸事件自己路由
    g_contextSource = @"none";
    NSLog(@"[StarCoreTweak] ⚠️ getTargetContextID=0, touch may auto-route");
    return 0;
}

// ==================== 获取SpringBoard的contextID ====================

static uint32_t getKeyWindowContextID() {
    UIApplication *app = [UIApplication sharedApplication];
    if (!app) return 0;
    
    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow) {
            uint32_t ctxId = 0;
            @try { 
                if ([window respondsToSelector:@selector(_contextId)]) {
                    ctxId = (uint32_t)(long)[window performSelector:@selector(_contextId)];
                }
            } @catch (NSException *e) {}
            if (ctxId) {
                NSLog(@"[StarCoreTweak] SpringBoard contextID=%u from keyWindow", ctxId);
                g_springBoardContextID = ctxId;
                return ctxId;
            }
        }
    }
    
    NSLog(@"[StarCoreTweak] ⚠️ contextID=0 (no window found)");
    return 0;
}

// ==================== 屏幕尺寸 ====================
static float getScreenScaleFactor() { return [UIScreen mainScreen].scale; }

// ==================== 事件分发 ====================
static IOHIDEventSystemClientRef _dispatchClient = NULL;

static void dispatchHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    if (IOHIDEventSetSenderIDFunc) IOHIDEventSetSenderIDFunc(event, kIOHIDEventDigitizerSenderID);
    
    if (IOHIDEventSystemClientDispatchEventFunc) {
        if (!_dispatchClient && IOHIDEventSystemClientCreateFunc) {
            _dispatchClient = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        }
        if (_dispatchClient) {
            IOHIDEventSystemClientDispatchEventFunc(_dispatchClient, event);
        }
    }
    
    // 备选：_enqueueHIDEvent
    @try {
        UIApplication *app = [UIApplication sharedApplication];
        if (app && [app respondsToSelector:@selector(_enqueueHIDEvent:)]) {
            [app _enqueueHIDEvent:event];
        }
    } @catch (NSException *e) {}
    
    CFRelease(event);
}

// ==================== 重置空闲计时器 ====================
static void resetIdleTimer() {
    // BKUserEventTimer可能不可用，用performSelector兜底
    Class timerClass = objc_getClass("BKUserEventTimer");
    if (timerClass) {
        id timer = [timerClass sharedInstance];
        if ([timer respondsToSelector:@selector(userEventOccurredOnDisplay:)]) {
            [timer performSelector:@selector(userEventOccurredOnDisplay:) withObject:nil];
        }
    }
}

// ==================== v4.3: 触摸模拟（使用动态contextID） ====================

// ★ v4.3: 创建触摸事件，指定是否设置digitizerInfo
static void simulateTouchEx(int type, float x, float y, int fingerId, uint32_t targetContextID, bool setDigitizerInfo) {
    if (!loadFunctions()) { NSLog(@"[StarCoreTweak] ❌ 函数未加载"); return; }
    
    float sf = getScreenScaleFactor();
    float rX = x * sf, rY = y * sf;
    int eventM = (type == TOUCH_MOVE) ? kIOHIDDigitizerEventPosition : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
    int touch_ = (type == TOUCH_UP) ? 0 : 1;
    uint64_t ts = mach_absolute_time();
    
    NSLog(@"[StarCoreTweak] touch type=%d rX=%.4f rY=%.4f sf=%.1f contextID=%u setDigitizer=%d", 
          type, rX, rY, sf, targetContextID, setDigitizerInfo);
    
    // Hand事件
    IOHIDEventRef hand = IOHIDEventCreateDigitizerEventFunc(kCFAllocatorDefault, ts, kIOHIDTransducerTypeHand, 0, 1, 0, 0, 0, 0, 0, 0, 0, false, false, 0);
    if (!hand) { NSLog(@"[StarCoreTweak] ❌ hand=NULL"); return; }
    
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerDisplayIntegrated, 1, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldBuiltIn, 1, (unsigned int)-268435456);
    IOHIDEventSetSenderIDFunc(hand, kIOHIDEventDigitizerSenderID);
    
    // ★ v4.3: 根据参数决定是否设置contextID
    if (setDigitizerInfo && BKSHIDEventSetDigitizerInfoFunc && targetContextID) {
        BKSHIDEventSetDigitizerInfoFunc(hand, targetContextID, false, false, NULL, 0, 0);
        NSLog(@"[StarCoreTweak] ✅ BKSHIDEventSetDigitizerInfo contextID=%u", targetContextID);
    } else if (targetContextID == 0) {
        NSLog(@"[StarCoreTweak] ⚠️ contextID=0, skipping BKSHIDEventSetDigitizerInfo");
    }
    
    // Finger事件
    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEventWithQualityFunc(kCFAllocatorDefault, ts, fingerId, fingerId+2, eventM, rX, rY, 0, 0, 0, 0, 0, 0, 0, 0, touch_, touch_, 0);
    if (!finger) { NSLog(@"[StarCoreTweak] ❌ finger=NULL"); CFRelease(hand); return; }
    
    IOHIDEventAppendEventFunc(hand, finger);
    CFRelease(finger);
    
    // Hand事件掩码
    int hem = 0;
    if (type == TOUCH_MOVE) hem |= kIOHIDDigitizerEventPosition;
    else hem |= (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventIdentity);
    if (type == TOUCH_UP) hem |= kIOHIDDigitizerEventPosition;
    
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerEventMask, hem, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerRange, touch_, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerTouch, touch_, (unsigned int)-268435456);
    
    resetIdleTimer();
    dispatchHIDEvent(hand);
}

// 标准触摸（使用动态contextID）
static void simulateTouch(int type, float x, float y, int fingerId) {
    uint32_t cid = getTargetContextID();
    simulateTouchEx(type, x, y, fingerId, cid, cid != 0);
}

// ★ v4.3: 测试触摸（用不同方式注入）
static NSArray *testTouchVariations(float x, float y, int fingerId) {
    NSMutableArray *results = [NSMutableArray new];
    
    // 方式1: 不设置digitizerInfo
    uint32_t cid0 = 0;
    @try { simulateTouchEx(TOUCH_DOWN, x, y, fingerId, cid0, false); } @catch (NSException *e) {}
    usleep(50000);
    @try { simulateTouchEx(TOUCH_UP, x, y, fingerId, cid0, false); } @catch (NSException *e) {}
    [results addObject:@{@"method": @"noDigitizerInfo", @"contextID": @(cid0), @"sent": @YES}];
    
    // 方式2: contextID=0 但设置digitizerInfo
    @try { simulateTouchEx(TOUCH_DOWN, x, y, fingerId, 0, true); } @catch (NSException *e) {}
    usleep(50000);
    @try { simulateTouchEx(TOUCH_UP, x, y, fingerId, 0, true); } @catch (NSException *e) {}
    [results addObject:@{@"method": @"contextID_zero", @"contextID": @(0), @"sent": @YES}];
    
    // 方式3: 使用动态获取的contextID
    uint32_t cid = getTargetContextID();
    @try { simulateTouchEx(TOUCH_DOWN, x, y, fingerId, cid, cid != 0); } @catch (NSException *e) {}
    usleep(50000);
    @try { simulateTouchEx(TOUCH_UP, x, y, fingerId, cid, cid != 0); } @catch (NSException *e) {}
    [results addObject:@{@"method": @"frontmostApp", @"contextID": @(cid), @"sent": @(cid != 0)}];
    
    return results;
}

static void simulateTap(float x, float y) { simulateTouch(TOUCH_DOWN, x, y, 1); usleep(50000); simulateTouch(TOUCH_UP, x, y, 1); }
static void simulateSwipe(float fX, float fY, float tX, float tY, float dur) {
    int steps = (int)(dur * 120); if (steps < 2) steps = 2;
    simulateTouch(TOUCH_DOWN, fX, fY, 1);
    for (int i = 1; i <= steps; i++) { float t = (float)i/steps; simulateTouch(TOUCH_MOVE, fX+(tX-fX)*t, fY+(tY-fY)*t, 1); usleep((useconds_t)(dur*1000000/steps)); }
    simulateTouch(TOUCH_UP, tX, tY, 1);
}
static void simulateLongPress(float x, float y, float d) { simulateTouch(TOUCH_DOWN, x, y, 1); usleep((useconds_t)(d*1000000)); simulateTouch(TOUCH_UP, x, y, 1); }
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
    NSLog(@"[StarCoreTweak] TCP :6000 v4.3 (dynamic contextID)");
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
            NSData *ld=[buf subdataWithRange:NSMakeRange(0,nl)]; [buf replaceBytesInRange:NSMakeRange(0,nl+1) withBytes:"" length:0];
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
    else if([action isEqualToString:@"tap"]) {
        float x=[req[@"x"] floatValue],y=[req[@"y"] floatValue];
        if(x>1.0f||y>1.0f){CGRect b=[UIScreen mainScreen].bounds;x/=b.size.width;y/=b.size.height;if(x>1)x=1;if(y>1)y=1;}
        simulateTap(x,y); resp[@"success"]=@YES;
    }
    else if([action isEqualToString:@"swipe"]) { simulateSwipe([req[@"fromX"] floatValue],[req[@"fromY"] floatValue],[req[@"toX"] floatValue],[req[@"toY"] floatValue],[req[@"duration"] floatValue]?:0.5f); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"longPress"]) { simulateLongPress([req[@"x"] floatValue],[req[@"y"] floatValue],[req[@"duration"] floatValue]?:1.0f); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"pressHome"]) { simulateHomeButton(); resp[@"success"]=@YES; }
    else if([action isEqualToString:@"openApp"]) {
        NSString *bid=req[@"bundleId"]; if(!bid){resp[@"success"]=@NO;resp[@"error"]=@"bundleId required";}
        else { Class wc=objc_getClass("LSApplicationWorkspace"); if(wc){id ws=[wc performSelector:@selector(defaultWorkspace)];BOOL ok=(BOOL)((BOOL(*)(id,SEL,NSString*))objc_msgSend)(ws,@selector(openApplicationWithBundleID:),bid);resp[@"success"]=@(ok);}else{resp[@"success"]=@NO;resp[@"error"]=@"no workspace";} }
    }
    else if([action isEqualToString:@"getScreenSize"]) { CGRect b=[UIScreen mainScreen].bounds; resp[@"success"]=@YES; resp[@"width"]=@(b.size.width); resp[@"height"]=@(b.size.height); resp[@"scale"]=@([UIScreen mainScreen].scale); }
    
    // ★ v4.3: testTouch诊断命令
    else if ([action isEqualToString:@"testTouch"]) {
        float x=[req[@"x"] floatValue] ?: 0.5f;
        float y=[req[@"y"] floatValue] ?: 0.5f;
        int fingerId=[req[@"id"] intValue] ?: 1;
        
        // 标准化坐标
        if(x>1.0f||y>1.0f){CGRect b=[UIScreen mainScreen].bounds;x/=b.size.width;y/=b.size.height;if(x>1)x=1;if(y>1)y=1;}
        
        // 获取当前contextID信息
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        
        // 执行3种测试
        NSArray *results = testTouchVariations(x, y, fingerId);
        
        resp[@"success"]=@YES;
        resp[@"results"]=results;
        resp[@"frontmostApp"]=g_frontmostApp ?: @"unknown";
        resp[@"springBoardContextID"]=@(springCID);
        resp[@"detectedFrontmostContextID"]=@(frontmostCID);
        resp[@"contextSource"]=g_contextSource ?: @"none";
    }
    
    else if([action isEqualToString:@"diagnose"]) {
        // 获取当前contextID信息
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        
        resp[@"success"]=@YES; 
        resp[@"diagnostics"]=@{
            @"version": @"4.3",
            @"iokitHandle": g_iokitHandle?@"OK":@"NULL",
            @"bbsHandle": g_bbsHandle?@"OK":@"NULL",
            @"createDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"fingerEventWithQuality": IOHIDEventCreateDigitizerFingerEventWithQualityFunc?@"OK":@"NULL",
            @"createKeyboardEvent": IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"setIntegerValueWithOptions": IOHIDEventSetIntegerValueWithOptionsFunc?@"OK":@"NULL",
            @"setSenderID": IOHIDEventSetSenderIDFunc?@"OK":@"NULL",
            @"appendEvent": IOHIDEventAppendEventFunc?@"OK":@"NULL",
            @"eventSystemClientCreate": IOHIDEventSystemClientCreateFunc?@"OK":@"NULL",
            @"eventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@"OK":@"NULL",
            @"BKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@"OK":@"NULL",
            // ★ v4.3 新增
            @"frontmostApp": g_frontmostApp ?: @"unknown",
            @"frontmostContextID": @(frontmostCID),
            @"springBoardContextID": @(springCID),
            @"contextSource": g_contextSource ?: @"none",
        };
    }
    
    // v4.3: validate命令（保持向后兼容）
    else if([action isEqualToString:@"validate"]) {
        uint32_t frontmostCID = getTargetContextID();
        uint32_t springCID = getKeyWindowContextID();
        bool canInjectTouch = (BKSHIDEventSetDigitizerInfoFunc != NULL) && (frontmostCID != 0 || springCID != 0);
        
        resp[@"success"]=@YES;
        resp[@"validation"]=@{
            @"frameworkIOKit": g_iokitHandle?@YES:@NO,
            @"frameworkBBS": g_bbsHandle?@YES:@NO,
            @"functionIOHIDEventCreateDigitizerEvent": IOHIDEventCreateDigitizerEventFunc?@YES:@NO,
            @"functionIOHIDEventCreateDigitizerFingerEventWithQuality": IOHIDEventCreateDigitizerFingerEventWithQualityFunc?@YES:@NO,
            @"functionIOHIDEventSystemClientDispatchEvent": IOHIDEventSystemClientDispatchEventFunc?@YES:@NO,
            @"functionBKSHIDEventSetDigitizerInfo": BKSHIDEventSetDigitizerInfoFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
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
    NSLog(@"[StarCoreTweak] SpringBoard启动 v4.3 (dynamic contextID)");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
}
%end

%ctor { NSLog(@"[StarCoreTweak] v4.3 loading... (dynamic contextID for touch injection)"); }
%dtor { [_server stop]; }
