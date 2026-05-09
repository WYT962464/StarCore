/**
 * StarCoreTweak.xm v3.1 - SpringBoard + BKHIDSystemInterface
 * 
 * 核心变更（v3.0 → v3.1）：
 * 1. 回退到SpringBoard注入（backboardd在dopamine下不被注入）
 * 2. 触摸事件发送改用 BKHIDSystemInterface.injectHIDEvent
 * 3. 坐标用归一化0.0-1.0 + SimulateTouch转换
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
typedef uint32_t IOHIDDigitizerEventMask;

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

// ==================== 函数指针 ====================
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    uint32_t, uint32_t, float, float, float, float, float,
    uint32_t, bool, bool, uint32_t) = NULL;

static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventWithQualityFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t,
    uint32_t, float, float,
    float, float, float,
    float, float, float,
    float, float,
    bool, bool, uint32_t) = NULL;

static IOHIDEventRef (*IOHIDEventCreateKeyboardEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, bool, uint32_t) = NULL;

static void (*IOHIDEventSetIntegerValueWithOptionsFunc)(IOHIDEventRef, uint32_t, int32_t, unsigned int) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;

// SenderID
static const uint64_t kStarCoreSenderID = 0x000000010000027FULL;

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    IOHIDEventCreateDigitizerEventFunc = (typeof(IOHIDEventCreateDigitizerEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerEvent");
    IOHIDEventCreateDigitizerFingerEventWithQualityFunc = (typeof(IOHIDEventCreateDigitizerFingerEventWithQualityFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerFingerEventWithQuality");
    IOHIDEventCreateKeyboardEventFunc = (typeof(IOHIDEventCreateKeyboardEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateKeyboardEvent");
    IOHIDEventSetIntegerValueWithOptionsFunc = (typeof(IOHIDEventSetIntegerValueWithOptionsFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetIntegerValueWithOptions");
    IOHIDEventSetFloatValueFunc = (typeof(IOHIDEventSetFloatValueFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetFloatValue");
    IOHIDEventSetSenderIDFunc = (typeof(IOHIDEventSetSenderIDFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetSenderID");
    IOHIDEventAppendEventFunc = (typeof(IOHIDEventAppendEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventAppendEvent");
    
    NSLog(@"[StarCoreTweak] === 函数加载状态 ===");
    NSLog(@"[StarCoreTweak]   CreateDigitizerEvent: %p", IOHIDEventCreateDigitizerEventFunc);
    NSLog(@"[StarCoreTweak]   FingerEventWithQuality: %p", IOHIDEventCreateDigitizerFingerEventWithQualityFunc);
    NSLog(@"[StarCoreTweak]   CreateKeyboardEvent: %p", IOHIDEventCreateKeyboardEventFunc);
    NSLog(@"[StarCoreTweak]   SetIntegerValueWithOptions: %p", IOHIDEventSetIntegerValueWithOptionsFunc);
    NSLog(@"[StarCoreTweak]   SetSenderID: %p", IOHIDEventSetSenderIDFunc);
    NSLog(@"[StarCoreTweak]   AppendEvent: %p", IOHIDEventAppendEventFunc);
    
    // 检查BKHIDSystemInterface
    Class bksClass = objc_getClass("BKHIDSystemInterface");
    NSLog(@"[StarCoreTweak]   BKHIDSystemInterface: %@", bksClass ? @"OK" : @"NULL");
    
    if (!IOHIDEventCreateDigitizerEventFunc || !IOHIDEventCreateDigitizerFingerEventWithQualityFunc) {
        NSLog(@"[StarCoreTweak] ❌ 核心函数加载失败");
        return false;
    }
    
    if (!bksClass) {
        NSLog(@"[StarCoreTweak] ❌ BKHIDSystemInterface不可用");
        return false;
    }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ 触摸注入模块初始化成功 (BKHIDSystemInterface模式)");
    return true;
}

// ==================== 屏幕尺寸获取 ====================

static CGSize getScreenSize() {
    CAWindowServer *server = [objc_getClass("CAWindowServer") serverIfRunning];
    if (server) {
        id display = [server displayWithName:@"LCD"];
        if (display) {
            CGRect bounds = [(CAWindowServerDisplay *)display bounds];
            return bounds.size;
        }
        NSArray *displays = [server displays];
        if (displays.count > 0) {
            CGRect bounds = [(CAWindowServerDisplay *)displays[0] bounds];
            return bounds.size;
        }
    }
    // 备选：用UIScreen
    CGRect bounds = [UIScreen mainScreen].bounds;
    CGFloat scale = [UIScreen mainScreen].scale;
    return CGSizeMake(bounds.size.width * scale, bounds.size.height * scale);
}

// ==================== 通过BKHIDSystemInterface注入事件 ====================

static void injectHIDEvent(IOHIDEventRef event) {
    if (!event) return;
    
    // 设置SenderID
    if (IOHIDEventSetSenderIDFunc) {
        IOHIDEventSetSenderIDFunc(event, kStarCoreSenderID);
    }
    
    // 使用BKHIDSystemInterface.injectHIDEvent（SpringBoard中可用）
    BKHIDSystemInterface *interface = [objc_getClass("BKHIDSystemInterface") sharedInstance];
    if (interface) {
        @try {
            [interface injectHIDEvent:event];
        } @catch (NSException *e) {
            NSLog(@"[StarCoreTweak] injectHIDEvent异常: %@", e);
        }
        CFRelease(event);
    } else {
        NSLog(@"[StarCoreTweak] ❌ BKHIDSystemInterface sharedInstance为nil");
        CFRelease(event);
    }
}

// ==================== 重置空闲计时器 ====================

static void resetIdleTimer() {
    BKUserEventTimer *timer = (BKUserEventTimer *)[objc_getClass("BKUserEventTimer") sharedInstance];
    if ([timer respondsToSelector:@selector(userEventOccurredOnDisplay:)]) {
        [timer userEventOccurredOnDisplay:nil];
    }
}

// ==================== 触摸事件发送 ====================

static void simulateTouch(int type, float x, float y, int fingerId) {
    if (!loadFunctions()) {
        NSLog(@"[StarCoreTweak] ❌ 触摸函数未加载");
        return;
    }
    
    uint64_t timeStamp = mach_absolute_time();
    
    // 事件掩码
    int eventM = (type == TOUCH_MOVE) ? kIOHIDDigitizerEventPosition : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
    int touch_ = (type == TOUCH_UP) ? 0 : 1;
    
    // 1. 创建Parent事件（Hand类型）
    IOHIDEventRef handEvent = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault,
        timeStamp,
        kIOHIDTransducerTypeHand,
        0, 1, 0, 0,
        0, 0, 0, 0, 0,
        0, false, false, 0
    );
    
    if (!handEvent) {
        NSLog(@"[StarCoreTweak] ❌ 创建handEvent失败");
        return;
    }
    
    // 关键设置 - 与SimulateTouch一致
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldDigitizerDisplayIntegrated, 1, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(handEvent, kIOHIDEventFieldBuiltIn, 1, (unsigned int)-268435456);
    IOHIDEventSetSenderIDFunc(handEvent, kStarCoreSenderID);
    
    // 2. 创建Finger事件
    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEventWithQualityFunc(
        kCFAllocatorDefault,
        timeStamp,
        fingerId, fingerId + 2,
        eventM,
        x, y,
        0,
        touch_ ? 1.0f : 0.0f,
        0, 0, 0, 0, 0, 0,
        touch_, touch_, 0
    );
    
    if (!fingerEvent) {
        NSLog(@"[StarCoreTweak] ❌ 创建fingerEvent失败");
        CFRelease(handEvent);
        return;
    }
    
    // 3. 附加Finger到Hand
    IOHIDEventAppendEventFunc(handEvent, fingerEvent);
    CFRelease(fingerEvent);
    
    // 4. 设置Hand事件掩码
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
    
    // 6. 通过BKHIDSystemInterface注入
    injectHIDEvent(handEvent);
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
    NSLog(@"[StarCoreTweak] longPress: (%.4f,%.4f) dur=%.2f", x, y, duration);
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
    if (downEvent) injectHIDEvent(downEvent);
    
    usleep(50000);
    
    timeStamp = mach_absolute_time();
    IOHIDEventRef upEvent = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, timeStamp,
        kHIDPage_Consumer, kHIDUsage_Csmr_Menu,
        false, 0);
    if (upEvent) injectHIDEvent(upEvent);
    
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
    NSLog(@"[StarCoreTweak] TCP服务器已启动 127.0.0.1:6000");
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
        // 逻辑像素转归一化
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
            @"createDigitizerEvent": (IOHIDEventCreateDigitizerEventFunc ? @"OK" : @"NULL"),
            @"fingerEventWithQuality": (IOHIDEventCreateDigitizerFingerEventWithQualityFunc ? @"OK" : @"NULL"),
            @"createKeyboardEvent": (IOHIDEventCreateKeyboardEventFunc ? @"OK" : @"NULL"),
            @"setIntegerValueWithOptions": (IOHIDEventSetIntegerValueWithOptionsFunc ? @"OK" : @"NULL"),
            @"setSenderID": (IOHIDEventSetSenderIDFunc ? @"OK" : @"NULL"),
            @"appendEvent": (IOHIDEventAppendEventFunc ? @"OK" : @"NULL"),
            @"BKHIDSystemInterface": (objc_getClass("BKHIDSystemInterface") ? @"OK" : @"NULL"),
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
    NSLog(@"[StarCoreTweak] SpringBoard启动完成 v3.1");
    
    // 启动TCP服务器
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    
    NSLog(@"[StarCoreTweak] v3.1 初始化完成 ✅");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] v3.1 加载中... (SpringBoard + BKHIDSystemInterface)");
}

%dtor {
    [_server stop];
}
