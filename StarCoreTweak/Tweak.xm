/**
 * StarCoreTweak.xm v2.0 - 触摸注入版
 * TCP Socket服务器 127.0.0.1:6000
 * 
 * 协议：JSON over TCP，每条消息以\n结尾
 * 参考: SimulateTouch / ZXTouch 触摸注入方案
 * 
 * 核心原理：
 * 1. 创建parent IOHIDEvent（Hand类型）
 * 2. 创建child IOHIDEvent（Finger类型），附加到parent
 * 3. 通过IOHIDEventSystemClientDispatchEvent发送
 * 4. 使用BKSHIDEventSetDigitizerInfo设置目标context
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

// ==================== 私有框架 - 运行时动态加载 ====================

// IOHIDEvent 类型前向声明
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef uint32_t IOHIDDigitizerEventMask;

// IOHIDEvent 常量
#define kIOHIDDigitizerTransducerTypeHand 4
#define kIOHIDDigitizerEventTouch    0x00000001
#define kIOHIDDigitizerEventRange    0x00000004
#define kIOHIDDigitizerEventPosition 0x00000002

// IOHIDEvent字段常量
#define kIOHIDEventFieldDigitizerIsDisplayIntegrated 0x00040001
#define kIOHIDEventFieldDigitizerTiltX  0x00040006
#define kIOHIDEventFieldDigitizerTiltY  0x00040007
#define kIOHIDEventFieldDigitizerAltitude 0x00040008
#define kIOHIDEventFieldDigitizerMajorRadius 0x0004000a
#define kIOHIDEventFieldDigitizerMinorRadius 0x0004000b

// 触摸类型
#define TOUCH_DOWN  0
#define TOUCH_MOVE  1
#define TOUCH_UP    2

// ==================== 动态加载的函数指针 ====================

// IOHIDEvent函数
static IOHIDEventRef (*IOHIDEventCreateDigitizerEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t,
    uint32_t, float, float, float, float, float,
    uint32_t, bool, uint32_t) = NULL;

static IOHIDEventRef (*IOHIDEventCreateDigitizerFingerEventFunc)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t,
    IOHIDDigitizerEventMask, float, float,
    float, float, float, bool, bool, uint32_t) = NULL;

static void (*IOHIDEventSetIntegerValueFunc)(IOHIDEventRef, uint32_t, int32_t) = NULL;
static void (*IOHIDEventSetFloatValueFunc)(IOHIDEventRef, uint32_t, float) = NULL;
static void (*IOHIDEventSetSenderIDFunc)(IOHIDEventRef, uint64_t) = NULL;
static void (*IOHIDEventAppendEventFunc)(IOHIDEventRef, IOHIDEventRef) = NULL;

// IOHIDEventSystemClient函数
static IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(CFAllocatorRef) = NULL;
static void (*IOHIDEventSystemClientDispatchEventFunc)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;

// BKSHIDEventSetDigitizerInfo函数
typedef void (*BKSHIDEventSetDigitizerInfoFuncType)(
    IOHIDEventRef, uint32_t, uint8_t, uint8_t, CFStringRef, CFTimeInterval, float);
static BKSHIDEventSetDigitizerInfoFuncType BKSHIDEventSetDigitizerInfoFunc = NULL;

// UIApplication私有方法
static void (*enqueueHIDEventFunc)(id, SEL, IOHIDEventRef) = NULL;

// 全局EventSystemClient
static IOHIDEventSystemClientRef eventSystemClient = NULL;

// kIOHIDEventDigitizerSenderID - 这是一个系统常量，通常为0x8000000000000000
static const uint64_t kIOHIDEventDigitizerSenderID = 0x8000000000000000LL;

// ==================== 初始化触摸注入 ====================

static bool initTouchInjection() {
    static bool initialized = false;
    static bool success = false;
    if (initialized) return success;
    initialized = true;
    
    // 加载IOHIDEvent函数 - 从已加载的框架中查找
    IOHIDEventCreateDigitizerEventFunc = (typeof(IOHIDEventCreateDigitizerEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerEvent");
    IOHIDEventCreateDigitizerFingerEventFunc = (typeof(IOHIDEventCreateDigitizerFingerEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventCreateDigitizerFingerEvent");
    IOHIDEventSetIntegerValueFunc = (typeof(IOHIDEventSetIntegerValueFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetIntegerValue");
    IOHIDEventSetFloatValueFunc = (typeof(IOHIDEventSetFloatValueFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetFloatValue");
    IOHIDEventSetSenderIDFunc = (typeof(IOHIDEventSetSenderIDFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSetSenderID");
    IOHIDEventAppendEventFunc = (typeof(IOHIDEventAppendEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventAppendEvent");
    
    IOHIDEventSystemClientCreateFunc = (typeof(IOHIDEventSystemClientCreateFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientCreate");
    IOHIDEventSystemClientDispatchEventFunc = (typeof(IOHIDEventSystemClientDispatchEventFunc))dlsym(RTLD_DEFAULT, "IOHIDEventSystemClientDispatchEvent");
    
    // 加载BackBoardServices中的BKSHIDEventSetDigitizerInfo
    void *bbsHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_NOW);
    if (bbsHandle) {
        BKSHIDEventSetDigitizerInfoFunc = (BKSHIDEventSetDigitizerInfoFuncType)dlsym(bbsHandle, "BKSHIDEventSetDigitizerInfo");
    }
    
    // 日志打印所有函数加载状态
    NSLog(@"[StarCoreTweak] === IOHIDEvent函数加载状态 ===");
    NSLog(@"[StarCoreTweak] CreateDigitizerEvent: %p", IOHIDEventCreateDigitizerEventFunc);
    NSLog(@"[StarCoreTweak] CreateFingerEvent: %p", IOHIDEventCreateDigitizerFingerEventFunc);
    NSLog(@"[StarCoreTweak] SetIntegerValue: %p", IOHIDEventSetIntegerValueFunc);
    NSLog(@"[StarCoreTweak] SetFloatValue: %p", IOHIDEventSetFloatValueFunc);
    NSLog(@"[StarCoreTweak] SetSenderID: %p", IOHIDEventSetSenderIDFunc);
    NSLog(@"[StarCoreTweak] AppendEvent: %p", IOHIDEventAppendEventFunc);
    NSLog(@"[StarCoreTweak] SystemClientCreate: %p", IOHIDEventSystemClientCreateFunc);
    NSLog(@"[StarCoreTweak] DispatchEvent: %p", IOHIDEventSystemClientDispatchEventFunc);
    NSLog(@"[StarCoreTweak] BKSSetDigitizerInfo: %p", BKSHIDEventSetDigitizerInfoFunc);
    
    if (!IOHIDEventCreateDigitizerEventFunc || !IOHIDEventCreateDigitizerFingerEventFunc ||
        !IOHIDEventSystemClientCreateFunc || !IOHIDEventSystemClientDispatchEventFunc) {
        NSLog(@"[StarCoreTweak] ❌ 核心函数加载失败，触摸注入不可用");
        return false;
    }
    
    // 创建EventSystemClient
    eventSystemClient = IOHIDEventSystemClientCreateFunc(kCFAllocatorDefault);
    if (!eventSystemClient) {
        NSLog(@"[StarCoreTweak] ❌ 创建EventSystemClient失败");
        return false;
    }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ 触摸注入模块初始化成功");
    return true;
}

// ==================== 触摸事件发送 ====================

static void postIOHIDEvent(IOHIDEventRef event) {
    if (!event || !eventSystemClient) return;
    
    // 设置senderID
    if (IOHIDEventSetSenderIDFunc) {
        IOHIDEventSetSenderIDFunc(event, kIOHIDEventDigitizerSenderID);
    }
    
    // 通过BKSHIDEventSetDigitizerInfo设置context
    if (BKSHIDEventSetDigitizerInfoFunc) {
        // 获取keyWindow的contextID
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (keyWindow) {
            uint32_t contextID = 0;
            @try {
                contextID = ((NSNumber *)[keyWindow performSelector:@selector(_contextId)]).unsignedIntValue;
            } @catch (NSException *e) {
                NSLog(@"[StarCoreTweak] 获取contextID失败: %@", e);
            }
            if (contextID != 0) {
                BKSHIDEventSetDigitizerInfoFunc(event, contextID, false, false, NULL, 0, 0);
            }
        }
    }
    
    // 通过UIApplication _enqueueHIDEvent - 跳过，直接用DispatchEvent
    // @try方式可能无法捕获CF层面的crash，先只用DispatchEvent
    
    // 通过EventSystemClient分发
    IOHIDEventSystemClientDispatchEventFunc(eventSystemClient, event);
}

// ==================== 触摸模拟核心 ====================

static void simulateTouch(int type, float x, float y, int fingerIndex) {
    if (!initTouchInjection()) {
        NSLog(@"[StarCoreTweak] 触摸注入未初始化，无法模拟触摸");
        return;
    }
    @try {
    
    uint64_t timestamp = mach_absolute_time();
    
    // 1. 创建Parent事件（Hand类型）
    IOHIDEventRef parentEvent = IOHIDEventCreateDigitizerEventFunc(
        kCFAllocatorDefault,
        timestamp,
        kIOHIDDigitizerTransducerTypeHand,
        0,           // index
        0,           // eventMask
        0,           // rangeEvent
        0.0, 0.0,    // x, y
        0.0, 0.0,    // z, pressure
        0.0,         // twist
        0,           // eventMask2
        true,        // range
        0            // options
    );
    
    if (!parentEvent) {
        NSLog(@"[StarCoreTweak] 创建parent事件失败");
        return;
    }
    
    // 设置为内建显示屏
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parentEvent, kIOHIDEventFieldDigitizerIsDisplayIntegrated, 1);
    }
    
    // 2. 创建Child事件（Finger类型）
    IOHIDDigitizerEventMask eventMask = 0;
    if (type == TOUCH_DOWN || type == TOUCH_UP) {
        eventMask = kIOHIDDigitizerEventTouch | kIOHIDDigitizerEventRange;
    }
    if (type == TOUCH_MOVE || type == TOUCH_DOWN) {
        eventMask |= kIOHIDDigitizerEventPosition;
    }
    
    bool isTouch = (type != TOUCH_UP);
    
    IOHIDEventRef fingerEvent = IOHIDEventCreateDigitizerFingerEventFunc(
        kCFAllocatorDefault,
        timestamp,
        fingerIndex + 1,  // finger index (1-based)
        3,                // identity
        eventMask,
        x, y,             // 归一化坐标 0.0-1.0
        0.0f,             // z
        0.0f,             // tipPressure (iOS会用默认值)
        0.0f,             // twist
        isTouch,          // isTouch
        isTouch,          // isRange
        0                 // options
    );
    
    if (!fingerEvent) {
        NSLog(@"[StarCoreTweak] 创建finger事件失败");
        CFRelease(parentEvent);
        return;
    }
    
    // 设置手指大小
    if (IOHIDEventSetFloatValueFunc) {
        IOHIDEventSetFloatValueFunc(fingerEvent, kIOHIDEventFieldDigitizerMajorRadius, 5.0f);
        IOHIDEventSetFloatValueFunc(fingerEvent, kIOHIDEventFieldDigitizerMinorRadius, 5.0f);
    }
    
    // 3. 附加Child到Parent
    if (IOHIDEventAppendEventFunc) {
        IOHIDEventAppendEventFunc(parentEvent, fingerEvent);
    }
    CFRelease(fingerEvent);
    
    // 设置Parent的元数据
    if (IOHIDEventSetIntegerValueFunc) {
        IOHIDEventSetIntegerValueFunc(parentEvent, kIOHIDEventFieldDigitizerTiltX, kIOHIDDigitizerTransducerTypeHand);
        IOHIDEventSetIntegerValueFunc(parentEvent, kIOHIDEventFieldDigitizerTiltY, 1);
        IOHIDEventSetIntegerValueFunc(parentEvent, kIOHIDEventFieldDigitizerAltitude, 1);
    }
    
    // 4. 发送事件
    @try {
        postIOHIDEvent(parentEvent);
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] postIOHIDEvent异常: %@", e);
    }
    CFRelease(parentEvent);
    } @catch (NSException *e) {
        NSLog(@"[StarCoreTweak] simulateTouch异常: %@", e);
    }
}

// ==================== 高级触摸操作 ====================

// 点击（逻辑像素）
static void simulateTap(float x, float y) {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect bounds = [UIScreen mainScreen].bounds;
    // 转换为归一化坐标 0.0-1.0
    float nx = (x * scale) / (bounds.size.width * scale);
    float ny = (y * scale) / (bounds.size.height * scale);
    
    NSLog(@"[StarCoreTweak] tap: logical(%.0f,%.0f) -> normalized(%.4f,%.4f)", x, y, nx, ny);
    
    simulateTouch(TOUCH_DOWN, nx, ny, 0);
    usleep(50000);  // 50ms
    simulateTouch(TOUCH_UP, nx, ny, 0);
}

// 滑动（逻辑像素）
static void simulateSwipe(float fromX, float fromY, float toX, float toY, float duration) {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect bounds = [UIScreen mainScreen].bounds;
    float w = bounds.size.width * scale;
    float h = bounds.size.height * scale;
    
    float nfx = (fromX * scale) / w;
    float nfy = (fromY * scale) / h;
    float ntx = (toX * scale) / w;
    float nty = (toY * scale) / h;
    
    NSLog(@"[StarCoreTweak] swipe: (%.0f,%.0f)->(%.0f,%.0f) dur=%.2f", fromX, fromY, toX, toY, duration);
    
    int steps = (int)(duration * 120);  // 120fps
    if (steps < 2) steps = 2;
    
    // Down
    simulateTouch(TOUCH_DOWN, nfx, nfy, 0);
    
    // Move
    for (int i = 1; i <= steps; i++) {
        float t = (float)i / steps;
        float cx = nfx + (ntx - nfx) * t;
        float cy = nfy + (nty - nfy) * t;
        simulateTouch(TOUCH_MOVE, cx, cy, 0);
        usleep((useconds_t)(duration * 1000000 / steps));
    }
    
    // Up
    simulateTouch(TOUCH_UP, ntx, nty, 0);
}

// 长按（逻辑像素）
static void simulateLongPress(float x, float y, float duration) {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect bounds = [UIScreen mainScreen].bounds;
    float nx = (x * scale) / (bounds.size.width * scale);
    float ny = (y * scale) / (bounds.size.height * scale);
    
    NSLog(@"[StarCoreTweak] longPress: (%.0f,%.0f) dur=%.2f", x, y, duration);
    
    simulateTouch(TOUCH_DOWN, nx, ny, 0);
    usleep((useconds_t)(duration * 1000000));
    simulateTouch(TOUCH_UP, nx, ny, 0);
}

// Home键 - 通过SpringBoard私有API
static void simulateHomeButton() {
    NSLog(@"[StarCoreTweak] pressHome");
    Class SBUIController = objc_getClass("SBUIController");
    if (SBUIController) {
        id controller = [SBUIController performSelector:@selector(sharedInstance)];
        if (controller && [controller respondsToSelector:@selector(handleHomeButton)]) {
            [controller performSelector:@selector(handleHomeButton)];
            return;
        }
    }
    // 备选方案：通过GS键盘事件
    NSLog(@"[StarCoreTweak] SBUIController方案失败，尝试其他方案");
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
    if (_serverSock < 0) {
        NSLog(@"[StarCoreTweak] 创建socket失败");
        return;
    }
    
    int yes = 1;
    setsockopt((int)_serverSock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(6000);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    if (bind((int)_serverSock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        NSLog(@"[StarCoreTweak] 绑定端口失败");
        close((int)_serverSock);
        _serverSock = -1;
        return;
    }
    
    if (listen((int)_serverSock, 5) < 0) {
        NSLog(@"[StarCoreTweak] listen失败");
        close((int)_serverSock);
        _serverSock = -1;
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self acceptLoop];
    });
    
    NSLog(@"[StarCoreTweak] TCP服务器已启动 127.0.0.1:6000");
}

- (void)acceptLoop {
    while (_serverSock >= 0) {
        struct sockaddr_in clientAddr;
        socklen_t clientLen = sizeof(clientAddr);
        int clientFd = accept((int)_serverSock, (struct sockaddr *)&clientAddr, &clientLen);
        
        if (clientFd < 0) continue;
        
        NSLog(@"[StarCoreTweak] 新连接 fd=%d", clientFd);
        @synchronized (_clientFds) {
            [_clientFds addObject:@(clientFd)];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self handleClient:clientFd];
        });
    }
}

- (void)handleClient:(int)fd {
    NSMutableData *buffer = [NSMutableData new];
    uint8_t buf[4096];
    
    while (YES) {
        ssize_t len = read(fd, buf, sizeof(buf));
        if (len <= 0) break;
        
        [buffer appendBytes:buf length:len];
        
        while (buffer.length > 0) {
            const uint8_t *bytes = (const uint8_t *)buffer.bytes;
            NSInteger nlPos = -1;
            for (NSInteger i = 0; i < buffer.length; i++) {
                if (bytes[i] == '\n') { nlPos = i; break; }
            }
            if (nlPos < 0) break;
            
            NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, nlPos)];
            [buffer replaceBytesInRange:NSMakeRange(0, nlPos + 1) withBytes:"" length:0];
            
            NSString *jsonStr = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
            if (jsonStr) {
                NSDictionary *response = [self processMessage:jsonStr];
                if (response) [self sendResponse:response toFd:fd];
            }
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
    if (!request || ![request isKindOfClass:[NSDictionary class]]) {
        return @{@"success": @NO, @"error": @"invalid JSON"};
    }
    
    NSString *action = request[@"action"];
    NSNumber *msgId = request[@"id"] ?: @0;
    NSMutableDictionary *response = [@{@"id": msgId} mutableCopy];
    
    if ([action isEqualToString:@"ping"]) {
        response[@"success"] = @YES;
        response[@"message"] = @"pong";
    }
    else if ([action isEqualToString:@"tap"]) {
        NSInteger x = [request[@"x"] integerValue];
        NSInteger y = [request[@"y"] integerValue];
        simulateTap((float)x, (float)y);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"swipe"]) {
        NSInteger fromX = [request[@"fromX"] integerValue];
        NSInteger fromY = [request[@"fromY"] integerValue];
        NSInteger toX = [request[@"toX"] integerValue];
        NSInteger toY = [request[@"toY"] integerValue];
        double duration = [request[@"duration"] doubleValue] ?: 0.5;
        simulateSwipe((float)fromX, (float)fromY, (float)toX, (float)toY, (float)duration);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"longPress"]) {
        NSInteger x = [request[@"x"] integerValue];
        NSInteger y = [request[@"y"] integerValue];
        double duration = [request[@"duration"] doubleValue] ?: 1.0;
        simulateLongPress((float)x, (float)y, (float)duration);
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"pressHome"]) {
        simulateHomeButton();
        response[@"success"] = @YES;
    }
    else if ([action isEqualToString:@"openApp"]) {
        NSString *bundleId = request[@"bundleId"];
        Class workspaceClass = objc_getClass("LSApplicationWorkspace");
        if (workspaceClass) {
            SEL defaultWorkspaceSel = sel_registerName("defaultWorkspace");
            SEL openAppSel = sel_registerName("openApplicationWithBundleID:");
            id workspace = ((id (*)(Class, SEL))objc_msgSend)(workspaceClass, defaultWorkspaceSel);
            if (workspace) {
                BOOL success = ((BOOL (*)(id, SEL, NSString *))objc_msgSend)(workspace, openAppSel, bundleId);
                response[@"success"] = @(success);
            } else {
                response[@"success"] = @NO;
                response[@"error"] = @"workspace instance nil";
            }
        } else {
            response[@"success"] = @NO;
            response[@"error"] = @"workspace class not found";
        }
    }
    else if ([action isEqualToString:@"getScreenSize"]) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        response[@"success"] = @YES;
        response[@"width"] = @(bounds.size.width);
        response[@"height"] = @(bounds.size.height);
        response[@"scale"] = @([UIScreen mainScreen].scale);
    }
    else if ([action isEqualToString:@"getCurrentApp"]) {
        response[@"success"] = @YES;
        response[@"bundleId"] = @"SpringBoard";
    }
    else {
        response[@"success"] = @NO;
        response[@"error"] = [NSString stringWithFormat:@"unknown action: %@", action];
    }
    
    return response;
}

- (void)sendResponse:(NSDictionary *)response toFd:(int)fd {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    if (!jsonData) return;
    
    NSMutableData *sendData = [jsonData mutableCopy];
    uint8_t nl = '\n';
    [sendData appendBytes:&nl length:1];
    
    const uint8_t *bytes = (const uint8_t *)sendData.bytes;
    size_t totalLen = sendData.length;
    size_t sent = 0;
    while (sent < totalLen) {
        ssize_t n = write(fd, bytes + sent, totalLen - sent);
        if (n <= 0) break;
        sent += n;
    }
}

- (void)stop {
    if (_serverSock >= 0) { close((int)_serverSock); _serverSock = -1; }
    @synchronized (_clientFds) {
        for (NSNumber *fdNum in _clientFds) close([fdNum intValue]);
        [_clientFds removeAllObjects];
    }
}

@end

// ==================== SpringBoard Hook ====================

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动完成");
    
    // 不在启动时初始化触摸注入 - 改为懒加载
    // initTouchInjection(); 
    
    // 启动TCP服务器
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    
    NSLog(@"[StarCoreTweak] Tweak初始化完成 - v2.0-touch");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
}

%dtor {
    [_server stop];
}
