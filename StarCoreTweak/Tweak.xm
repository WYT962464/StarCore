/**
 * StarCoreTweak.xm v4.1 - Force dlopen + validate runtime environment
 * 
 * v4.0问题：dlsym(RTLD_DEFAULT)全部返回NULL
 * 修复：显式dlopen + handle-based symbol lookup + validate诊断命令
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

@interface BKUserEventTimer : NSObject
+ (id)sharedInstance;
- (void)userEventOccurredOnDisplay:(id)arg1;
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

static void *g_iokitHandle = NULL;
static void *g_bbsHandle = NULL; // BackBoardServices

// ==================== 强制加载框架 ====================

static bool forceLoadFrameworks() {
    NSLog(@"[StarCoreTweak] === 强制加载框架 ===");
    
    // IOKit路径列表
    const char *iokitPaths[] = {
        "/System/Library/Frameworks/IOKit.framework/IOKit",
        "/System/Library/Frameworks/IOKit.framework/IOKit.dylib",
        "/usr/lib/libIOKit.dylib",
        NULL
    };
    
    for (int i = 0; iokitPaths[i]; i++) {
        dlerror(); // 清除
        void *h = dlopen(iokitPaths[i], RTLD_NOW | RTLD_GLOBAL);
        const char *err = dlerror();
        if (h) {
            g_iokitHandle = h;
            NSLog(@"[StarCoreTweak] ✅ IOKit dlopen: %s → %p", iokitPaths[i], h);
            break;
        }
        NSLog(@"[StarCoreTweak] ❌ IOKit dlopen: %s → %s", iokitPaths[i], err ?: "?");
    }
    
    // BackBoardServices路径
    const char *bbsPaths[] = {
        "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",
        "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices.dylib",
        NULL
    };
    
    for (int i = 0; bbsPaths[i]; i++) {
        dlerror();
        void *h = dlopen(bbsPaths[i], RTLD_NOW | RTLD_GLOBAL);
        const char *err = dlerror();
        if (h) {
            g_bbsHandle = h;
            NSLog(@"[StarCoreTweak] ✅ BBS dlopen: %s → %p", bbsPaths[i], h);
            break;
        }
        NSLog(@"[StarCoreTweak] ❌ BBS dlopen: %s → %s", bbsPaths[i], err ?: "?");
    }
    
    return (g_iokitHandle != NULL || g_bbsHandle != NULL);
}

// ==================== 函数加载 ====================

static bool loadFunctions() {
    static bool loaded = false;
    static bool success = false;
    if (loaded) return success;
    loaded = true;
    
    // 先强制加载框架
    forceLoadFrameworks();
    
    // 依次从各handle尝试查找符号
    void *handles[] = { g_iokitHandle, g_bbsHandle, RTLD_DEFAULT, NULL };
    
    #define LOAD_SYM(var, name) do { \
        var = NULL; \
        for (int _i = 0; handles[_i] && !var; _i++) { \
            var = (typeof(var))dlsym(handles[_i], name); \
        } \
        NSLog(@"[StarCoreTweak] %s = %@", name, var ? [NSString stringWithFormat:@"%p", var] : @"NULL"); \
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
    
    #undef LOAD_SYM
    
    Class bksClass = objc_getClass("BKHIDSystemInterface");
    NSLog(@"[StarCoreTweak] BKHIDSystemInterface = %@", bksClass ? @"OK" : @"NULL");
    
    if (!IOHIDEventCreateDigitizerEventFunc) {
        NSLog(@"[StarCoreTweak] ❌ 核心函数仍未找到");
        return false;
    }
    
    success = true;
    NSLog(@"[StarCoreTweak] ✅ 函数加载成功 v4.1");
    return true;
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
    } else {
        BKHIDSystemInterface *iface = [objc_getClass("BKHIDSystemInterface") sharedInstance];
        if (iface) { @try { [iface injectHIDEvent:event]; } @catch (NSException *e) {} }
    }
    CFRelease(event);
}

static void resetIdleTimer() {
    BKUserEventTimer *t = (BKUserEventTimer *)[objc_getClass("BKUserEventTimer") sharedInstance];
    if ([t respondsToSelector:@selector(userEventOccurredOnDisplay:)]) [t userEventOccurredOnDisplay:nil];
}

// ==================== 触摸模拟 ====================

static void simulateTouch(int type, float x, float y, int fingerId) {
    if (!loadFunctions()) { NSLog(@"[StarCoreTweak] ❌ 函数未加载"); return; }
    
    float sf = getScreenScaleFactor();
    float rX = x * sf, rY = y * sf;
    int eventM = (type == TOUCH_MOVE) ? kIOHIDDigitizerEventPosition : (kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch);
    int touch_ = (type == TOUCH_UP) ? 0 : 1;
    uint64_t ts = mach_absolute_time();
    
    IOHIDEventRef hand = IOHIDEventCreateDigitizerEventFunc(kCFAllocatorDefault, ts, kIOHIDTransducerTypeHand, 0, 1, 0, 0, 0, 0, 0, 0, 0, false, false, 0);
    if (!hand) return;
    
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldDigitizerDisplayIntegrated, 1, (unsigned int)-268435456);
    IOHIDEventSetIntegerValueWithOptionsFunc(hand, kIOHIDEventFieldBuiltIn, 1, (unsigned int)-268435456);
    IOHIDEventSetSenderIDFunc(hand, kIOHIDEventDigitizerSenderID);
    
    IOHIDEventRef finger = IOHIDEventCreateDigitizerFingerEventWithQualityFunc(kCFAllocatorDefault, ts, fingerId, fingerId+2, eventM, rX, rY, 0, 0, 0, 0, 0, 0, 0, 0, touch_, touch_, 0);
    if (!finger) { CFRelease(hand); return; }
    
    IOHIDEventAppendEventFunc(hand, finger);
    CFRelease(finger);
    
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
    if (d) dispatchHIDEvent(d);
    usleep(50000); ts = mach_absolute_time();
    IOHIDEventRef u = IOHIDEventCreateKeyboardEventFunc(kCFAllocatorDefault, ts, kHIDPage_Consumer, kHIDUsage_Csmr_Menu, false, 0);
    if (u) dispatchHIDEvent(u);
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
    NSLog(@"[StarCoreTweak] TCP :6000 v4.1");
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
    else if([action isEqualToString:@"diagnose"]) {
        NSMutableDictionary *diag=[@{@"version":@"4.1",
            @"iokitHandle":g_iokitHandle?[NSString stringWithFormat:@"%p",g_iokitHandle]:@"NULL",
            @"bbsHandle":g_bbsHandle?[NSString stringWithFormat:@"%p",g_bbsHandle]:@"NULL",
            @"createDigitizerEvent":IOHIDEventCreateDigitizerEventFunc?@"OK":@"NULL",
            @"fingerEventWithQuality":IOHIDEventCreateDigitizerFingerEventWithQualityFunc?@"OK":@"NULL",
            @"createKeyboardEvent":IOHIDEventCreateKeyboardEventFunc?@"OK":@"NULL",
            @"setIntegerValueWithOptions":IOHIDEventSetIntegerValueWithOptionsFunc?@"OK":@"NULL",
            @"setSenderID":IOHIDEventSetSenderIDFunc?@"OK":@"NULL",
            @"appendEvent":IOHIDEventAppendEventFunc?@"OK":@"NULL",
            @"eventSystemClientCreate":IOHIDEventSystemClientCreateFunc?@"OK":@"NULL",
            @"eventSystemClientDispatchEvent":IOHIDEventSystemClientDispatchEventFunc?@"OK":@"NULL",
            @"BKHIDSystemInterface":objc_getClass("BKHIDSystemInterface")?@"OK":@"NULL",
            @"BKUserEventTimer":objc_getClass("BKUserEventTimer")?@"OK":@"NULL",
        } mutableCopy];
        resp[@"success"]=@YES; resp[@"diagnostics"]=diag;
    }
    else if([action isEqualToString:@"validate"]) {
        // 运行时环境验证
        NSMutableDictionary *val=[NSMutableDictionary new];
        
        // 1. 扫描dyld镜像中IOKit/BackBoard相关的
        uint32_t ic=_dyld_image_count();
        NSMutableArray *matching=[NSMutableArray new];
        for(uint32_t i=0;i<ic;i++) {
            const char *n=_dyld_get_image_name(i);
            if(n && (strstr(n,"IOKit")||strstr(n,"BackBoard")||strstr(n,"HID"))) {
                [matching addObject:@{@"index":@(i),@"name":[NSString stringWithUTF8String:n],@"addr":[NSString stringWithFormat:@"%p",_dyld_get_image_header(i)]}];
            }
        }
        val[@"matchingImages"]=matching;
        val[@"totalImages"]=@(ic);
        
        // 2. 测试dlopen + dlerror
        const char *paths[] = {
            "/System/Library/Frameworks/IOKit.framework/IOKit",
            "/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices",
            NULL
        };
        NSMutableArray *dlr=[NSMutableArray new];
        for(int i=0;paths[i];i++) {
            dlerror(); void *h=dlopen(paths[i],RTLD_NOW); const char *err=dlerror();
            [dlr addObject:@{@"path":[NSString stringWithUTF8String:paths[i]],@"handle":h?[NSString stringWithFormat:@"%p",h]:@"NULL",@"error":err?[NSString stringWithUTF8String:err]:@"none"}];
        }
        val[@"dlopenResults"]=dlr;
        
        // 3. 测试RTLD_DEFAULT dlsym
        void *s1=dlsym(RTLD_DEFAULT,"IOHIDEventCreateDigitizerEvent"); const char *e1=dlerror();
        void *s2=dlsym(RTLD_DEFAULT,"IOHIDEventSetSenderID"); const char *e2=dlerror();
        void *s3=dlsym(RTLD_DEFAULT,"IOHIDEventSystemClientCreate"); const char *e3=dlerror();
        val[@"rtldDefault"]=@{
            @"IOHIDEventCreateDigitizerEvent":s1?[NSString stringWithFormat:@"%p",s1]:@"NULL",
            @"IOHIDEventSetSenderID":s2?[NSString stringWithFormat:@"%p",s2]:@"NULL",
            @"IOHIDEventSystemClientCreate":s3?[NSString stringWithFormat:@"%p",s3]:@"NULL",
        };
        
        // 4. 测试ObjC类
        val[@"objcClasses"]=@{
            @"BKHIDSystemInterface":objc_getClass("BKHIDSystemInterface")?@"OK":@"NULL",
            @"BKUserEventTimer":objc_getClass("BKUserEventTimer")?@"OK":@"NULL",
            @"CAWindowServer":objc_getClass("CAWindowServer")?@"OK":@"NULL",
            @"LSApplicationWorkspace":objc_getClass("LSApplicationWorkspace")?@"OK":@"NULL",
            @"UIScreen":objc_getClass("UIScreen")?@"OK":@"NULL",
        };
        
        resp[@"success"]=@YES; resp[@"validate"]=val;
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
    NSLog(@"[StarCoreTweak] SpringBoard启动 v4.1");
    loadFunctions();
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
}
%end

%ctor { NSLog(@"[StarCoreTweak] v4.1 loading..."); }
%dtor { [_server stop]; }
