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
#import <objc/message.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

// 私有框架 - 使用运行时动态调用

#pragma mark - TCP服务器

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
    
    // 在后台线程accept连接
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
        
        if (clientFd < 0) {
            continue;
        }
        
        NSLog(@"[StarCoreTweak] 新连接 fd=%d", clientFd);
        @synchronized (_clientFds) {
            [_clientFds addObject:@(clientFd)];
        }
        
        // 为每个客户端启动读线程
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
        if (len <= 0) {
            break;
        }
        
        [buffer appendBytes:buf length:len];
        
        // 按\n分割处理
        while (buffer.length > 0) {
            // 查找\n
            const uint8_t *bytes = (const uint8_t *)buffer.bytes;
            NSInteger nlPos = -1;
            for (NSInteger i = 0; i < buffer.length; i++) {
                if (bytes[i] == '\n') {
                    nlPos = i;
                    break;
                }
            }
            
            if (nlPos < 0) break; // 没有完整消息
            
            NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, nlPos)];
            [buffer replaceBytesInRange:NSMakeRange(0, nlPos + 1) withBytes:"" length:0];
            
            NSString *jsonStr = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
            if (jsonStr) {
                NSDictionary *response = [self processMessage:jsonStr];
                if (response) {
                    [self sendResponse:response toFd:fd];
                }
            }
        }
    }
    
    NSLog(@"[StarCoreTweak] 连接断开 fd=%d", fd);
    @synchronized (_clientFds) {
        [_clientFds removeObject:@(fd)];
    }
    close(fd);
}

- (NSDictionary *)processMessage:(NSString *)jsonStr {
    NSData *data = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;
    
    NSError *error;
    NSDictionary *request = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!request || ![request isKindOfClass:[NSDictionary class]]) {
        return @{@"success": @NO, @"error": @"invalid JSON"};
    }
    
    NSString *action = request[@"action"];
    NSNumber *msgId = request[@"id"] ?: @0;
    NSMutableDictionary *response = [@{@"id": msgId} mutableCopy];
    
    if ([action isEqualToString:@"tap"]) {
        NSInteger x = [request[@"x"] integerValue];
        NSInteger y = [request[@"y"] integerValue];
        NSLog(@"[StarCoreTweak] tap:(%ld,%ld)", (long)x, (long)y);
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
        // 运行时动态调用LSApplicationWorkspace（私有框架，编译时不可链接）
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
    else if ([action isEqualToString:@"ping"]) {
        response[@"success"] = @YES;
        response[@"message"] = @"pong";
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
    if (_serverSock >= 0) {
        close((int)_serverSock);
        _serverSock = -1;
    }
    @synchronized (_clientFds) {
        for (NSNumber *fdNum in _clientFds) {
            close([fdNum intValue]);
        }
        [_clientFds removeAllObjects];
    }
    NSLog(@"[StarCoreTweak] TCP服务器已停止");
}

@end

#pragma mark - SpringBoard Hook

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[StarCoreTweak] SpringBoard启动完成");
    
    _server = [[StarCoreTCPServer alloc] init];
    [_server start];
    
    NSLog(@"[StarCoreTweak] Tweak初始化完成 - v1.0-tcp");
}

%end

%ctor {
    NSLog(@"[StarCoreTweak] Tweak加载中...");
}

%dtor {
    NSLog(@"[StarCoreTweak] Tweak卸载");
    [_server stop];
}
