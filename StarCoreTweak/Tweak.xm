/**
 * StarCoreTweak.xm
 * TCP Socket服务器版 - 监听127.0.0.1:6000
 * 
 * 协议：JSON over TCP，每条消息以\n结尾
 * 请求：{"action":"tap","x":100,"y":200,"id":1}
 * 响应：{"success":true,"id":1}
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 私有框架声明
@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
@end

// TCP服务器
@interface StarCoreTCPServer : NSObject
- (void)start;
- (void)stop;
@end

static StarCoreTCPServer *server = nil;

@implementation StarCoreTCPServer {
    CFSocketRef _socket;
    NSMutableArray<NSInputStream *> *_clients;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _clients = [NSMutableArray new];
    }
    return self;
}

- (void)start {
    CFSocketContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    _socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_IP,
                             kCFSocketAcceptCallBack, &SocketAcceptCallback, &context);
    
    if (!_socket) {
        NSLog(@"[StarCoreTweak] 创建Socket失败");
        return;
    }
    
    // 设置SO_REUSEADDR
    int yes = 1;
    setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(6000);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];
    if (CFSocketSetAddress(_socket, (__bridge CFDataRef)addressData) != kCFSocketSuccess) {
        NSLog(@"[StarCoreTweak] 绑定端口6000失败");
        CFRelease(_socket);
        _socket = NULL;
        return;
    }
    
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    
    NSLog(@"[StarCoreTweak] TCP服务器已启动 127.0.0.1:6000");
}

static void SocketAcceptCallback(CFSocketRef socket, CFSocketCallBackType type, 
                                  CFDataRef address, const void *data, void *info) {
    StarCoreTCPServer *server = (__bridge StarCoreTCPServer *)info;
    [server handleNewConnection:*(CFSocketNativeHandle *)data];
}

- (void)handleNewConnection:(CFSocketNativeHandle)fd {
    NSLog(@"[StarCoreTweak] 新连接 fd=%d", fd);
    
    // 创建读写流
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, fd, &readStream, &writeStream);
    
    NSInputStream *input = (__bridge_transfer NSInputStream *)readStream;
    NSOutputStream *output = (__bridge_transfer NSOutputStream *)writeStream;
    
    input.delegate = self;
    output.delegate = self;
    [input scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [output scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [input open];
    [output open];
    
    // 关联output到input
    objc_setAssociatedObject(input, "output", output, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(input, "buffer", [NSMutableData new], OBJC_ASSOCIATION_RETAIN);
    
    @synchronized (_clients) {
        [_clients addObject:input];
    }
}

- (void)stop {
    if (_socket) {
        CFSocketInvalidate(_socket);
        CFRelease(_socket);
        _socket = NULL;
    }
    @synchronized (_clients) {
        for (NSInputStream *input in _clients) {
            NSOutputStream *output = objc_getAssociatedObject(input, "output");
            [input close];
            [output close];
        }
        [_clients removeAllObjects];
    }
    NSLog(@"[StarCoreTweak] TCP服务器已停止");
}

#pragma mark - NSStreamDelegate

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable: {
            if (![aStream isKindOfClass:[NSInputStream class]]) return;
            NSInputStream *input = (NSInputStream *)aStream;
            NSMutableData *buffer = objc_getAssociatedObject(input, "buffer");
            
            uint8_t buf[4096];
            NSInteger len = [input read:buf maxLength:sizeof(buf)];
            if (len > 0) {
                [buffer appendBytes:buf length:len];
                
                // 按行处理JSON消息
                while (YES) {
                    NSRange nlRange = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding].rangeOfString:@"\n"];
                    if (nlRange.location == NSNotFound) break;
                    
                    NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, nlRange.location)];
                    [buffer replaceBytesInRange:NSMakeRange(0, nlRange.location + 1) withBytes:@"" length:0];
                    
                    NSString *jsonStr = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
                    [self handleMessage:jsonStr fromStream:input];
                }
            }
            break;
        }
        case NSStreamEventEndEncountered: {
            @synchronized (_clients) {
                [_clients removeObject:aStream];
            }
            NSOutputStream *output = objc_getAssociatedObject(aStream, "output");
            [aStream close];
            [output close];
            NSLog(@"[StarCoreTweak] 连接断开");
            break;
        }
        case NSStreamEventErrorOccurred: {
            NSLog(@"[StarCoreTweak] 流错误: %@", aStream.streamError);
            @synchronized (_clients) {
                [_clients removeObject:aStream];
            }
            NSOutputStream *output = objc_getAssociatedObject(aStream, "output");
            [aStream close];
            [output close];
            break;
        }
        default:
            break;
    }
}

#pragma mark - 消息处理

- (void)handleMessage:(NSString *)jsonStr fromStream:(NSInputStream *)input {
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    
    NSError *error;
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!request || ![request isKindOfClass:[NSDictionary class]]) {
        [self sendResponse:@{@"success": @NO, @"error": @"invalid JSON"} toStream:input];
        return;
    }
    
    NSString *action = request[@"action"];
    NSNumber *msgId = request[@"id"] ?: @0;
    NSMutableDictionary *response = [@{@"id": msgId} mutableCopy];
    
    if ([action isEqualToString:@"tap"]) {
        NSInteger x = [request[@"x"] integerValue];
        NSInteger y = [request[@"y"] integerValue];
        NSLog(@"[StarCoreTweak] tap:(%ld,%ld)", (long)x, (long)y);
        // TODO: IOHIDEvent触摸注入
        response[@"success"] = @YES;
        response[@"message"] = @"tap received (stub)";
    }
    else if ([action isEqualToString:@"swipe"]) {
        NSLog(@"[StarCoreTweak] swipe: %@", request);
        response[@"success"] = @YES;
        response[@"message"] = @"swipe received (stub)";
    }
    else if ([action isEqualToString:@"longPress"]) {
        NSLog(@"[StarCoreTweak] longPress: %@", request);
        response[@"success"] = @YES;
        response[@"message"] = @"longPress received (stub)";
    }
    else if ([action isEqualToString:@"pressHome"]) {
        NSLog(@"[StarCoreTweak] pressHome");
        response[@"success"] = @YES;
        response[@"message"] = @"pressHome received (stub)";
    }
    else if ([action isEqualToString:@"openApp"]) {
        NSString *bundleId = request[@"bundleId"];
        NSLog(@"[StarCoreTweak] openApp: %@", bundleId);
        LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
        if (workspace) {
            BOOL success = [workspace openApplicationWithBundleID:bundleId];
            response[@"success"] = @(success);
        } else {
            response[@"success"] = @NO;
            response[@"error"] = @"workspace unavailable";
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
    else if ([action isEqualToString:@"ping"]) {
        response[@"success"] = @YES;
        response[@"message"] = @"pong";
    }
    else {
        response[@"success"] = @NO;
        response[@"error"] = [NSString stringWithFormat:@"unknown action: %@", action];
    }
    
    [self sendResponse:response toStream:input];
}

- (void)sendResponse:(NSDictionary *)response toStream:(NSInputStream *)input {
    NSOutputStream *output = objc_getAssociatedObject(input, "output");
    if (!output || ![output hasSpaceAvailable]) return;
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
    if (!jsonData) return;
    
    NSMutableData *sendData = [jsonData mutableCopy];
    uint8_t nl = '\n';
    [sendData appendBytes:&nl length:1];
    
    [output write:[sendData bytes] maxLength:[sendData length]];
}

@end

// Hook SpringBoard启动
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动完成");
    
    server = [[StarCoreTCPServer alloc] init];
    [server start];
    
    NSLog(@"[StarCoreTweak] Tweak初始化完成 - v1.0-tcp");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
}

%dtor {
    NSLog(@"[StarCoreTweak] Tweak卸载");
    [server stop];
}
