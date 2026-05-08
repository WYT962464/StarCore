/**
 * StarCoreTweakBridge.h
 * TCP Socket协议定义 - App和Tweak共用
 * 
 * 通信方式：TCP Socket 127.0.0.1:6000
 * 协议格式：JSON over TCP，每条消息以\n结尾
 * 
 * 请求格式：{"action":"<action>","id":<int>, ...params}
 * 响应格式：{"success":<bool>,"id":<int>, ...data}
 * 
 * 支持的action：
 * - ping: 心跳检测
 * - tap: 点击 {"action":"tap","x":100,"y":200}
 * - swipe: 滑动 {"action":"swipe","fromX":0,"fromY":0,"toX":100,"toY":100,"duration":0.5}
 * - longPress: 长按 {"action":"longPress","x":100,"y":200,"duration":1.0}
 * - pressHome: Home键
 * - openApp: 打开应用 {"action":"openApp","bundleId":"com.xxx.xxx"}
 * - getScreenSize: 获取屏幕尺寸
 * - getCurrentApp: 获取当前前台应用
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// TCP服务端口
static const int kStarCoreTCPPort = 6000;

// TCP服务地址
static NSString * const kStarCoreTCPHost = @"127.0.0.1";

// Action常量
static NSString * const kActionPing = @"ping";
static NSString * const kActionTap = @"tap";
static NSString * const kActionSwipe = @"swipe";
static NSString * const kActionLongPress = @"longPress";
static NSString * const kActionPressHome = @"pressHome";
static NSString * const kActionOpenApp = @"openApp";
static NSString * const kActionGetScreenSize = @"getScreenSize";
static NSString * const kActionGetCurrentApp = @"getCurrentApp";

NS_ASSUME_NONNULL_END
