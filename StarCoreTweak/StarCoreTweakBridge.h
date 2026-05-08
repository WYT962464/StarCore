/**
 * StarCoreTweakBridge.h
 * XPC协议定义 - App和Tweak共用
 * 
 * 定义了StarCore App与Tweak之间的通信接口
 * 协议设计预留扩展能力，后续可按需添加新接口
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - XPC协议定义

/**
 * StarCore Tweak XPC协议
 * 定义所有可通过XPC调用的触摸注入和系统操作接口
 */
@protocol StarCoreTweakProtocol <NSObject>

@required
#pragma mark - 基础触摸操作

/**
 * 点击指定坐标
 * @param x X坐标（逻辑像素）
 * @param y Y坐标（逻辑像素）
 * @param reply 回调：操作是否成功
 */
- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply;

/**
 * 滑动操作
 * @param fromX 起始X坐标（逻辑像素）
 * @param fromY 起始Y坐标（逻辑像素）
 * @param toX 结束X坐标（逻辑像素）
 * @param toY 结束Y坐标（逻辑像素）
 * @param duration 持续时间（秒），默认0.5秒
 * @param reply 回调：操作是否成功
 */
- (void)swipeFromX:(NSInteger)fromX 
             fromY:(NSInteger)fromY 
               toX:(NSInteger)toX 
               toY:(NSInteger)toY 
          duration:(double)duration 
             reply:(void (^)(BOOL))reply;

/**
 * 长按操作
 * @param x X坐标（逻辑像素）
 * @param y Y坐标（逻辑像素）
 * @param duration 持续时间（秒）
 * @param reply 回调：操作是否成功
 */
- (void)longPressAtX:(NSInteger)x 
                   Y:(NSInteger)y 
            duration:(double)duration 
               reply:(void (^)(BOOL))reply;

#pragma mark - 系统操作

/**
 * 按下Home键
 * @param reply 回调：操作是否成功
 */
- (void)pressHomeButton:(void (^)(BOOL))reply;

/**
 * 打开指定应用
 * @param bundleId 应用Bundle ID
 * @param reply 回调：操作是否成功
 */
- (void)openApp:(NSString *)bundleId reply:(void (^)(BOOL))reply;

#pragma mark - 感知能力（预留）

/**
 * 获取屏幕尺寸
 * @param reply 回调：包含width/height的字典
 */
- (void)getScreenSize:(void (^)(NSDictionary *))reply;

/**
 * 获取当前前台应用
 * @param reply 回调：当前应用bundleId
 */
- (void)getCurrentApp:(void (^)(NSString *))reply;

#pragma mark - 截图能力（预留）

/**
 * 截取当前屏幕
 * @param reply 回调：PNG图片数据
 */
- (void)takeScreenshot:(void (^)(NSData *))reply;

@end

#pragma mark - 服务标识

// XPC服务名称（无根越狱路径）
extern NSString * const kStarCoreTweakServiceName;

NS_ASSUME_NONNULL_END
