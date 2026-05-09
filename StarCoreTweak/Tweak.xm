/**
 * StarCoreTweak.xm v4.0 - Aligned with SimulateTouch
 * 
 * 核心修复（v3.1 → v4.0）：
 * 1. IOHIDEventCreateDigitizerEvent 参数从16改为15（匹配SimulateTouch源码）
 * 2. 坐标系统从物理像素改为 rX = x_norm × scaleFactor（SimulateTouch公式）
 * 3. 事件分发改用 IOHIDEventSystemClientDispatchEvent（SimulateTouch验证方案）
 * 4. BKHIDSystemInterface.injectHIDEvent 作为备选方案
 * 
 * 协议：JSON over TCP 127.0.0.1:6000，每条消息以\n结尾
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

// ==================== 私有IOHIDEvent类型 ====================
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

// IOHIDEvent常量
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

// 触摸类型
#define TOUCH_DOWN  1
#define TOUCH_MOVE  0
#define TOUCH_UP    2

// HID Usage Tables
#define kHIDPage_Consumer 0x0C
#define kHIDUsage_Csmr_Menu 0x40

// SenderID（与SimulateTouch一致）
#define kIOHIDEventDigitizerSenderID 0x000000010000027FULL

// ==================== 私有类声明 ====================

@interface BKHIDSystemInterface : NSObject
+ (id)sharedInstance;
- (void)injectHIDEvent:(IOHIDEventRef)arg1;
@end

@interface BKUserEventTimer : NSObject
+ (id)sharedInstance;
- (void)userEventOccurredOnDisplay:(id)arg1;
@end

@interface CAWindowServer : NSObject
+ (id)serverIfRunning;
- (id)displayWithName:(id)name;
- (NSArray *)displays;
@end

@interface CAWindowServerDisplay : NSObject
- (CGRect)bounds;
@end

// ==================== 函数指针（对齐SimulateTouch源码）====================

// IOHIDEventCreateDigitizerEvent - 15个参数（SimulateTouch MSHook验证）
// 参数: allocator, timestamp, type, index, identity, eventMask, buttonMask,
//       x, y, z, tipPressure, barrelPressure, range, touch, options
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    uint32_t, uint32_t,
    float, float, float, float, float,
    bool, bool, uint32_t) = NULL;

// IOHIDEventCreateDigitizerFingerEventWithQuality - 18个参数（SimulateTouch MSHook验证）
// 参数: allocator, timestamp, index, identity, eventMask,
//       x, y, z, tipPressure, twist, minorRadius, majorRadius,
//       quality, density, irregularity, range, touch, options
static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    float, float, float, float, float,
    float, float, float, float, float,
    bool, bool, uint32_t) = NULL;

static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;

static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;

// DispatchEvent（SimulateTouch方案）
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    // 显式dlopen IOKit（DeepSeek建议，更稳妥）
    void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!iokit) {
        NSLog(@"[StarCoreTweak] ⚠️ dlopen IOKit失败，尝试RTLD_DEFAULT");
    }
    
    IOHIDEventCreateDigitizerEventFunc = (typeof(IOHIDEventCreateDigitizerEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerEvent");
    IOHIDEventCreateDigitizerFingerEventWithQualityFunc = (typeof(IOHIDEventCreateDigitizerFingerEventWithQualityFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerFingerEventWithQuality");
    IOHIDEventCreateKeyboardEventFunc = (typeof(IOHIDEventCreateKeyboardEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSetIntegerValueWithOptionsFunc = (typeof(IOHIDEventSetIntegerValueWithOptionsFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetIntegerValueWithOptions");
    IOHIDEventSetFloatValueFunc = (typeof(IOHIDEventSetFloatValueFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetFloatValue");
    IOHIDEventSetSenderIDFunc = (typeof(IOHIDEventSetSenderIDFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetSenderID");
    IOHIDEventAppendEventFunc = (typeof(IOHIDEventAppendEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventAppendEvent");
    
    // DispatchEvent函数
    IOHIDEventSystemClientCreateFunc = (typeof(IOHIDEventSystemClientCreateFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEventFunc = (typeof(IOHIDEventSystemClientDispatchEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientDispatchEvent");
    
    NSLog(@"[StarCoreTweak] === 函数加载状态 v4.0 ===");
    NSLog(@"[StarCoreTweak]   CreateDigitizerEvent: %p", IOHIDEventCreateDigitizerEventFunc);
    NSLog(@"[StarCoreTweak]   FingerEventWithQuality: %p", IOHIDEventCreateDigitizerFingerEventWithQualityFunc);
    NSLog(@"[StarCoreTweak]   CreateKeyboardEvent: %p", IOHIDEventCreateKeyboardEventFunc);
    NSLog(@"[StarCoreTweak]   SetIntegerValueWithOptions: %p", IOHIDEventSetIntegerValueWithOptionsFunc);
    NSLog(@"[StarCoreTweak]   SetSenderID: %p", IOHIDEventSetSenderIDFunc);
    NSLog(@"[StarCoreTweak]   AppendEvent: %p", IOHIDEventAppendEventFunc);
    NSLog(@"[StarCoreTweak]   EventSystemClientCreate: %p", IOHIDEventSystemClientCreateFunc);
    NSLog(@"[StarCoreTweak]   EventSystemClientDispatchEvent: %p", IOHIDEventSystemClientDispatchEventFunc);
    
    // 检查BKHIDSystemInterface（备选方案）
    Class bksClass = objc_getClass("BKHIDSystemInterface");
    NSLog(@"[StarCoreTweak]   BKHIDSystemInterface: %@", bksClass ? @"OK" : @"NULL");
    
    if (!IOHIDEventCreateDigitizerEventFunc || !IOHIDEventCreateDigitizerFingerEventWithQualityFunc) {
        NSLog(@"[StarCoreTweak] ❌ 核心函数加载失败");
        return false;
    }
    
    if (!IOHIDEventSystemClientCreateFunc || !IOHIDEventSystemClientDispatchEventFunc) {
        NSLog(@"[StarCoreTweak] ⚠️ DispatchEvent不可用，将使用BKHIDSystemInterface");
    }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ 触摸注入模块初始化成功 v4.0");
    return true;
}

// ==================== 屏幕尺寸获取 ====================

static float getScreenScaleFactor() {
    // iPhone X: scale=3.0, 其他设备按实际scale
    return [UIScreen mainScreen].scale;
}

// ==================== 事件分发 ====================

// 方案1: IOHIDEventSystemClientDispatchEvent（SimulateTouch方案）
static IOHIDEventSystemClientRef _dispatchClient = NULL;

static void dispatchEventViaClient(IOHIDEventRef event) {
    if (!_dispatchClient && IOHIDEventSystemClientCreateFunc) {
        _dispatchClient = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
        NSLog(@"[StarCoreTweak] EventSystemClient创建: %@", _dispatchClient ? @"OK" : @"FAIL");
    }
    if (_dispatchClient && IOHIDEventSystemClientDispatchEventFunc) {
        IOHIDEventSystemClientDispatchEventFunc(_dispatchClient, event);
    } else {
        NSLog(@"[StarCoreTweak] ❌ DispatchEvent不可用");
    }
}

// 方案2: BKHIDSystemInterface.injectHIDEvent（备选）
static void dispatchEventViaBKS(IOHIDEventRef event) {
    BKHIDSystemInterface *interface = [objc_getClass("BKHIDSystemInterface") sharedInstance];
    if (interface) {
        @try {
            [interface injectHIDEvent:event];
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] injectHIDEvent异常: %@", e);
        }
    } else {
        NSLog(@"[StarCoreTweak] ❌ BKHIDSystemInterface不可用");
    }
}

// 统一分发入口：优先DispatchEvent，失败则用BKS
static void dispatchHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    
    // 设置SenderID（SimulateTouch使用0xDEFACEDBEEFFECE5，我们用标准SenderID）
    if (IOHIDEventSetSenderIDFunc) {
        IOHIDEventSetSenderIDFunc(event, kIOHIDEventDigitizerSenderID);
    }
    
    // 优先使用DispatchEvent（SimulateTouch验证方案）
    if (_dispatchClient || IOHIDEventSystemClientCreateFunc) {
        dispatchEventViaClient(event);
    } else {
        // 备选：BKHIDSystemInterface
        dispatchEventViaBKS(event);
    }
    
    CFRelease(event);
}

// ==================== 重置空闲计时器 ====================

static void resetIdleTimer() {
    BKUserEventTimer *timer = (BKUserEventTimer *)[objc_getClass("BKUserEventTimer") sharedInstance];
    if ([timer respondsToSelector:@selector(userEventOccurredOnDisplay:)]) {
        [timer userEventOccurredOnDisplay:nil];
    }
}

// ==================== 触摸事件发送（对齐SimulateTouch）====================

static void simulateTouch(int type, float x, float y, int fingerId) {
    if (!loadFunctions()) return;
    
    // 坐标转换：归一化0.0-1.0 → SimulateTouch坐标系统
    // SimulateTouch公式: rX = x_pixel / screenWidth * scaleFactor
    // 对于归一化输入: rX = x_norm * scaleFactor
    float scaleFactor = getScreenScaleFactor();
    float rX = x * scaleFactor;
    float rY = y * scaleFactor;
    
    // 事件掩码（与SimulateTouch一致）
    int eventM = (type == TOUCH_MOVE) ? kIOHIDDigitizerEventPosition : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
    int touch_ = (type == TOUCH_UP) ? 0 : 1;
    
    uint64_t timeStamp = mach_absolute_time();
    
    NSLog(@"[StarCoreTweak] simulateTouch type=%d rX=%.4f rY=%.4f scale=%.1f", type, rX, rY, scaleFactor);
    
    // 1. 创建Hand事件（完全对齐SimulateTouch）
    //    参数: allocator, timestamp, type=3(Hand), index=0, identity=1,
    //          eventMask=0, buttonMask=0, x=0, y=0, z=0, tip=0, barrel=0,
    //          range=false, touch=false, options=0
    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault,
        timeStamp,
        kIOHIDTransducerTypeHand,  // type = 3
        0,                         // index = 0
        1,                         // identity = 1
        0,                         // eventMask = 0
        0,                         // buttonMask = 0
        0, 0, 0,                   // x, y, z = 0
        0, 0,                      // tipPressure, barrelPressure = 0
        false, false,              // range, touch = false
        0                          // options = 0
    );
    
    if (!handEvent) {
        NSLog(@"[StarCoreTweak] ❌ 创建handEvent失败");
        return;
    }
    
    // 关键设置 - 与SimulateTouch完全一致
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldDigitizerDisplayIntegrated, 1, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldBuiltIn, 1, (unsigned int)-268435456);
    IOHIDEventSetSenderIDFunc(handEvent, kIOHIDEventDigitizerSenderID);
    
    // 2. 创建Finger事件（完全对齐SimulateTouch）
    //    参数: allocator, timestamp, index=fingerId, identity=i+2, eventMask,
    //          x=rX, y=rY, z=0, tipPressure=0, twist=0, minorRadius=0,
    //          majorRadius=0, quality=0, density=0, irregularity=0,
    //          range=touch_, touch=touch_, options=0
    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEventWithQualityFunc(
        kCFAllocatorDefault,
        timeStamp,
        fingerId,           // index
        fingerId + 2,       // identity (SimulateTouch用 i+2)
        eventM,             // eventMask
        rX, rY,             // x, y (SimulateTouch坐标系统)
        0,                  // z
        0,                  // tipPressure
        0, 0, 0, 0, 0, 0,  // twist, minorRadius, majorRadius, quality, density, irregularity
        touch_,             // range
        touch_,             // touch
        0                   // options
    );
    
    if (!fingerEvent) {
        NSLog(@"[StarCoreTweak] ❌ 创建fingerEvent失败");
        CFRelease(handEvent);
        return;
    }
    
    // 3. 附加Finger到Hand
    IOHIDEventAppendEventFunc(handEvent, fingerEvent);
    CFRelease(fingerEvent);
    
    // 4. 设置Hand事件掩码（与SimulateTouch一致）
    int handEventMask = 0;
    int handEventTouch = 0;
    
    if (type == TOUCH_MOVE) {
        handEventMask |= kIOHIDDigitizerEventPosition;
    } else {
        handEventMask |= (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventIdentity);
    }
    handEventTouch = touch_;
    
    if (type == TOUCH_UP) {
        handEventMask |= kIOHIDDigitizerEventPosition;
    }
    
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldDigitizerEventMask, handEventMask, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldDigitizerRange, handEventTouch, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldDigitizerTouch, handEventTouch, (unsigned int)-268435456);
    
    // 5. 重置空闲计时器
    resetIdleTimer();
    
    // 6. 分发事件
    dispatchHIDEvent(handEvent);
}

// ==================== 高级触摸操作 ====================

static void simulateTap(float x, float y) {
    NSLog(@"[StarCoreTweak] tap: (%.4f, %.4f)", x, y);
    simulateTouch(TOUCH_DOWN, x, y, 1);
    usleep(50000);
    simulateTouch(TOUCH_UP, x, y, 1);
}

static void simulateSwipe(float fromX, float fromY, float toX, float toY, float duration) {
    NSLog(@"[StarCoreTweak] swipe: (%.4f,%.4f)->(%.4f,%.4f) dur=%.2f", fromX, fromY, toX, toY, duration);
    int steps = (int)(duration * 120);
    if (steps < 2) steps = 2;
    
    simulateTouch(TOUCH_DOWN, fromX, fromY, 1);
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        float cx = fromX + (toX - fromX) * t;
        float cy = fromY + (toY - fromY) * t;
        simulateTouch(TOUCH_MOVE, cx, cy, 1);
        usleep((useconds_t)(duration * 1000000 / steps));
    }
    simulateTouch(TOUCH_UP, toX, toY, 1);
}

static void simulateLongPress(float x, float y, float duration) {
    NSLog(@"[StarCoreTweak] longPress: (%.4f, %.4f) dur=%.2f", x, y, duration);
    simulateTouch(TOUCH_DOWN, x, y, 1);
    usleep((useconds_t)(duration * 1000000));
    simulateTouch(TOUCH_UP, x, y, 1);
}

static void simulateHomeButton() {
    NSLog(@"[StarCoreTweak] pressHome");
    if (!loadFunctions()) return;
    
    uint64_t timeStamp = mach_absolute_time();
    
    IOHIDEventRef downEvent = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, timeStamp,
        kHIDPage_Consumer, kHIDUsage_Csmr_Menu,
        true, 0);
    if (downEvent) dispatchHIDEvent(downEvent);
    
    usleep(50000);
    
    timeStamp = mach_absolute_time();
    IOHIDEventRef upEvent = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, timeStamp,
        kHIDPage_Consumer, kHIDUsage_Csmr_Menu,
        false, 0);
    if (upEvent) dispatchHIDEvent(upEvent);
    
    resetIdleTimer();
}

// ==================== TCP服务器 ====================

@interface StarCoreTCPServer : NSObject
- (void)start;
- (void)stop;
@end

static StarCoreTCPServer *_server = nil;

@implementation StarCoreTCPServer {
    NSInteger _serverSock;
    NSMutableArray<NSNumber *> *_clientFds;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _clientFds = [NSMutableArray new];
    }
    return self;
}

- (void)start {
    _serverSock = socket(AF_INET, SOCK_STREAM, 0);
    if (_serverSock < 0) { NSLog(@"[StarCoreTweak] 创建socket失败"); return; }
    
    int yes = 1;
    setsockopt((int)_serverSock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(6000);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    if (bind((int)_serverSock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        NSLog(@"[StarCoreTweak] 绑定端口失败"); close((int)_serverSock); _serverSock = -1; return;
    }
    if (listen((int)_serverSock, 5) < 0) {
        NSLog(@"[StarCoreTweak] listen失败"); close((int)_serverSock); _serverSock = -1; return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self acceptLoop]; });
    NSLog(@"[StarCoreTweak] TCP服务器已启动 127.0.0.1:6000 v4.0");
}

- (void)acceptLoop {
    while (_serverSock >= 0) {
        struct sockaddr_in clientAddr; socklen_t clientLen = sizeof(clientAddr);
        int clientFd = accept((int)_serverSock, (struct sockaddr *)&clientAddr, &clientLen);
        if (clientFd < 0) continue;
        NSLog(@"[StarCoreTweak] 新连接 fd=%d", clientFd);
        @synchronized (_clientFds) { [_clientFds addObject:@(clientFd)]; }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self handleClient:clientFd]; });
    }
}

- (void)handleClient:(int)fd {
    NSMutableData *buffer = [NSMutableData new]; uint8_t buf[4096];
    while (YES) {
        ssize_t len = read(fd, buf, sizeof(buf));
        if (len <= 0) break;
        [buffer appendBytes:buf length:len];
        while (buffer.length > 0) {
            const uint8_t *bytes = (const uint8_t *)buffer.bytes;
            NSInteger nlPos = -1;
            for (NSInteger i = 0; i < buffer.length; i++) { if (bytes[i] == '\n') { nlPos = i; break; } }
            if (nlPos < 0) break;
            NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, nlPos)];
            [buffer replaceBytesInRange:NSMakeRange(0, nlPos + 1) withBytes:"" length:0];
            NSString *jsonStr = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
            if (jsonStr) { NSDictionary *response = [self processMessage:jsonStr]; if (response) [self sendResponse:response toFd:fd]; }
        }
    }
    @synchronized (_clientFds) { [_clientFds removeObject:@(fd)]; }
    close(fd);
}

- (NSDictionary *)processMessage:(NSString *)jsonStr {
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return @{@"success": @NO, @"error": @"invalid JSON"};
    NSError *error;
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!request || ![request isKindOfClass:[NSDictionary class]]) return @{@"success": @NO, @"error": @"invalid JSON"};
    
    NSString *action = request[@"action"];
    NSNumber *msgId = request[@"id"] ?: @0;
    NSMutableDictionary *response = [@{@"id": msgId} mutableCopy];
    
    if ([action isEqualToString:@"ping"]) {
        response[@"success"] = @YES; response[@"message"] = @"pong";
    }
    else if ([action isEqualToString:@"tap"]) {
        float x = [request[@"x"] floatValue];
        float y = [request[@"y"] floatValue];
        // 支持两种坐标：归一化0-1 或 逻辑像素
        if (x > 1.0f || y > 1.0f) {
            CGRect bounds = [UIScreen mainScreen].bounds;
            x = x / bounds.size.width;
            y = y / bounds.size.height;
            if (x > 1.0f) x = 1.0f; if (y > 1.0f) y = 1.0f;
        }
        simulateTap(x, y);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"swipe"]) {
        float fromX = [request[@"fromX"] floatValue], fromY = [request[@"fromY"] floatValue];
        float toX = [request[@"toX"] floatValue], toY = [request[@"toY"] floatValue];
        double duration = [request[@"duration"] doubleValue] ?: 0.5;
        simulateSwipe(fromX, fromY, toX, toY, (float)duration);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"longPress"]) {
        float x = [request[@"x"] floatValue], y = [request[@"y"] floatValue];
        double duration = [request[@"duration"] doubleValue] ?: 1.0;
        simulateLongPress(x, y, (float)duration);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"pressHome"]) {
        simulateHomeButton();
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"openApp"]) {
        NSString *bundleId = request[@"bundleId"];
        if (!bundleId) { response[@"success"] = @NO; response[@"error"] = @"bundleId required"; }
        else {
            Class workspaceClass = objc_getClass("LSApplicationWorkspace");
            if (workspaceClass) {
                id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
                BOOL ok = (BOOL)((BOOL (*)(id, SEL, NSString *))objc_msgSend)(workspace, @selector(openApplicationWithBundleID:), bundleId);
                response[@"success"] = @(ok);
            } else { response[@"success"] = @NO; response[@"error"] = @"workspace not found"; }
        }
    }
    else if ([action isEqualToString:@"getScreenSize"]) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        response[@"success"] = @YES;
        response[@"width"] = @(bounds.size.width);
        response[@"height"] = @(bounds.size.height);
        response[@"scale"] = @([UIScreen mainScreen].scale);
    }
    else if ([action isEqualToString:@"diagnose"]) {
        NSMutableDictionary *diag = [@{
            @"version": @"4.0",
            @"createDigitizerEvent": (IOHIDEventCreateDigitizerEventFunc ? @"OK" : @"NULL"),
            @"fingerEventWithQuality": (IOHIDEventCreateDigitizerFingerEventWithQualityFunc ? @"OK" : @"NULL"),
            @"createKeyboardEvent": (IOHIDEventCreateKeyboardEventFunc ? @"OK" : @"NULL"),
            @"setIntegerValueWithOptions": (IOHIDEventSetIntegerValueWithOptionsFunc ? @"OK" : @"NULL"),
            @"setSenderID": (IOHIDEventSetSenderIDFunc ? @"OK" : @"NULL"),
            @"appendEvent": (IOHIDEventAppendEventFunc ? @"OK" : @"NULL"),
            @"eventSystemClientCreate": (IOHIDEventSystemClientCreateFunc ? @"OK" : @"NULL"),
            @"eventSystemClientDispatchEvent": (IOHIDEventSystemClientDispatchEventFunc ? @"OK" : @"NULL"),
            @"BKHIDSystemInterface": (objc_getClass("BKHIDSystemInterface") ? @"OK" : @"NULL"),
            @"dispatchClient": (_dispatchClient ? @"OK" : @"NULL"),
        } mutableCopy];
        response[@"success"] = @YES; response[@"diagnostics"] = diag;
    }
    else { response[@"success"] = @NO; response[@"error"] = [NSString stringWithFormat:@"unknown action: %@", action]; }
    
    return response;
}

- (void)sendResponse:(NSDictionary *)response toFd:(int)fd {
    NSError *error; NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    if (!jsonData) return;
    NSMutableData *sendData = [jsonData mutableCopy]; uint8_t nl = '\n'; [sendData appendBytes:&nl length:1];
    const uint8_t *bytes = (const uint8_t *)sendData.bytes; size_t totalLen = sendData.length; size_t sent = 0;
    while (sent < totalLen) { ssize_t n = write(fd, bytes + sent, totalLen - sent); if (n <= 0) break; sent += n; }
}

- (void)stop {
    if (_serverSock >= 0) { close((int)_serverSock); _serverSock = -1; }
    @synchronized (_clientFds) { for (NSNumber *fdNum in _clientFds) close([fdNum intValue]); [_clientFds removeAllObjects]; }
}
@end

// ==================== SpringBoard Hook ====================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动完成 v4.0");
    
    // 启动TCP服务器
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    
    NSLog(@"[StarCoreTweak] v4.0 初始化完成 ✅ (SimulateTouch对齐版)");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] v4.0 加载中... (SimulateTouch对齐 + DispatchEvent)");
}

%dtor {
    [_server stop];
}
