#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    
    // 启动 StarCore daemon
    NSString *daemonPath = @"/var/jb/usr/bin/starcore-daemon";
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:daemonPath];
    [task launch];
    
    NSLog(@"[StarCore] Tweak loaded, daemon started");
}

%end

%hook UIApplication

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    BOOL result = %orig;
    
    // 注入 iOS MCP 功能
    NSLog(@"[StarCore] Application launched, MCP ready");
    
    return result;
}

%end
