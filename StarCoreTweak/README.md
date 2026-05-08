# StarCoreTweak

> iOS越狱触摸注入Tweak - 适配多巴胺无根越狱(Dopamine rootless)

## 设备适配

| 项目 | 值 |
|------|-----|
| 设备 | iPhone X |
| 系统 | iOS 16.7.12 |
| 越狱 | 多巴胺(Dopamine)无根越狱 |
| 安装路径 | `/var/jb/` |

## 项目结构

```
StarCoreTweak/
├── Tweak.xm              # 主代码：Hook SpringBoard + IOHIDEvent触摸注入
├── StarCoreTweakBridge.h # XPC协议定义
├── control               # DEB包配置
├── Makefile              # Theos编译配置(rootless)
└── StarCoreTweak.plist   # 过滤器配置
```

## XPC协议接口

```objc
@protocol StarCoreTweakProtocol <NSObject>
- (void)tapAtX:(NSInteger)x Y:(NSInteger)y reply:(void (^)(BOOL))reply;
- (void)swipeFromX:(NSInteger)fromX fromY:(NSInteger)fromY 
               toX:(NSInteger)toX toY:(NSInteger)toY 
          duration:(double)duration reply:(void (^)(BOOL))reply;
- (void)longPressAtX:(NSInteger)x Y:(NSInteger)y duration:(double)duration reply:(void (^)(BOOL))reply;
- (void)pressHomeButton:(void (^)(BOOL))reply;
- (void)openApp:(NSString *)bundleId reply:(void (^)(BOOL))reply;
- (void)getScreenSize:(void (^)(NSDictionary *))reply;
- (void)getCurrentApp:(void (^)(NSString *))reply;
- (void)takeScreenshot:(void (^)(NSData *))reply;
@end
```

## 编译方式

### GitHub Actions（推荐）
推送到 `v1.0-dual-layer` 分支自动触发构建：
```bash
git push origin v1.0-dual-layer
```

### 本地编译（需要macOS + Theos）
```bash
cd StarCoreTweak
make clean
make package
```

## 安装

### 编译产出
- `.deb` 文件会上传为GitHub Actions Artifact
- 下载后通过Filza或命令行安装：
```bash
dpkg -i com.starcore.tweak_*.deb
```

### 手动部署到设备
```bash
scp com.starcore.tweak_*.deb root@<device-ip>:/tmp/
ssh root@<device-ip>
cd /var/jb && dpkg -i /tmp/com.starcore.tweak_*.deb
```

## IOHIDEvent触摸注入原理

```
1. IOHIDEventCreateDigitizerFingerEvent() 创建手指事件
2. IOHIDEventSetIntegerValue() 设置 IsDisplayIntegrated
3. IOHIDEventSetSenderID() 设置发送者ID
4. IOHIDEventSystemClientDispatchEvent() 分发到系统
```

坐标系统：
- 输入：逻辑像素（iPhone X = 375×812）
- 内部：归一化坐标（0.0-1.0）
- IOFixed格式：值 × 0x10000

## 注意事项

1. **无根越狱约束**：deb必须使用 `THEOS_PACKAGE_SCHEME=rootless`
2. **Tweak安装后需重启SpringBoard**：`killall SpringBoard`
3. **XPC服务名称**：`com.starcore.tweak-service`

## 相关文档

- [iOS操控方案](./StarCore研究/iOS操控方案.md)
- [Frida触摸注入方案](./StarCore研究/Frida触摸注入方案_归档参考.md)
