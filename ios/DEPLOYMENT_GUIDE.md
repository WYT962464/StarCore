# StarCore iOS 部署指南

## 📋 概述

本文档说明如何将 StarCore iOS App 部署到越狱 iPhone。

## 🏗️ 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    StarCore iOS 部署架构                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    SSH 隧道     ┌──────────────────┐      │
│  │   Mac 构建    │ ─────────────► │   服务器          │      │
│  │   (Xcode)    │                │   (Ubuntu)        │      │
│  └──────────────┘                └────────┬─────────┘      │
│                                           │                │
│                                    SSH 反向隧道              │
│                                           ▼                │
│                                  ┌──────────────────┐      │
│                                  │   iPhone (越狱)   │      │
│                                  │   - StarCore App  │      │
│                                  │   - StarCoreTweak │      │
│                                  │   - daemon 服务   │      │
│                                  └──────────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 📦 部署步骤

### 步骤 1: 在 Mac 上构建 IPA

```bash
# 1. 将 ios/ 目录复制到 Mac
scp -r user@server:/home/ubuntu/starcore/ios ~/StarCore-iOS

# 2. 打开 Xcode 项目
cd ~/StarCore-iOS
open StarCore.xcodeproj

# 3. 配置签名 (需要 Apple Developer 账户)
#    - 打开 Signing & Capabilities
#    - 选择你的 Team
#    - 设置 Bundle Identifier

# 4. 构建 Archive
xcodebuild archive -scheme StarCore -configuration Release

# 5. 导出 IPA
#    Product → Export → Ad Hoc
```

### 步骤 2: 传输 IPA 到 iPhone

**方法 A: SSH 传输**
```bash
# 从服务器传输
scp ~/StarCore-iOS/build/StarCore-1.0.0.ipa mobile@192.168.1.100:~/Downloads/

# 或通过服务器中转
ssh mobile@192.168.1.100 "mkdir -p ~/Downloads"
scp -P 8028 ~/StarCore-iOS/build/StarCore-1.0.0.ipa mobile@localhost:~/Downloads/
```

**方法 B: AirDrop**
- 在 Mac 上使用 AirDrop 发送到 iPhone

**方法 C: 云存储**
- 上传到 iCloud Drive / Google Drive
- 在 iPhone 上下载

### 步骤 3: 安装 App

**方法 A: AltStore (推荐)**
1. 在 Mac 上安装 AltServer
2. 连接 iPhone (USB 或同一 WiFi)
3. 使用 AltStore 安装 IPA
4. 信任开发者证书

**方法 B: Filza (越狱)**
1. 打开 Filza
2. 导航到 ~/Downloads/
3. 点击 IPA 文件
4. 选择"Install"

**方法 C: Sileo (越狱)**
1. 添加 IPA 到 Sileo 源
2. 安装

### 步骤 4: 配置 App

1. 打开 StarCore App
2. 进入设置页面
3. 配置服务器地址:
   - 如果使用 SSH 隧道: `http://localhost:9090`
   - 如果直接连接: `http://192.168.1.100:9090`
4. 测试连接

### 步骤 5: 验证功能

| 功能 | 验证方法 |
|------|---------|
| 卦象显示 | 打开 App，查看卦象卡片 |
| 系统数据 | 查看 CPU/内存/电池数据 |
| 演化历史 | 查看演化时间线 |
| Tweak 注入 | 检查 daemon 是否运行 |

## 🔧 Tweak 部署

### 构建 Tweak

```bash
# 1. 创建 Tweak 项目结构
mkdir -p ~/StarCoreTweak/Sources
cd ~/StarCoreTweak

# 2. 创建 Makefile
cat > Makefile << 'EOF'
TARGET = iphone:clang:15.0:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StarCoreTweak
StarCoreTweak_FILES = Tweak.x
StarCoreTweak_CFLAGS = -fobjc-arc
StarCoreTweak_LIBRARIES = ellekit

include $(THEOS_MAKE_PATH)/tweak.mk
EOF

# 3. 创建 Tweak.x
cat > Sources/Tweak.x << 'EOF'
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

%hook SpringBoard
- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    // 注入 StarCore daemon
    NSString *daemonPath = @"/var/jb/usr/bin/starcore-daemon";
    [[NSProcessInfo processInfo] arguments];
    // 启动 daemon
    system([daemonPath UTF8String]);
}
%end
EOF

# 4. 编译
make package

# 5. 安装
scp packages/*.deb mobile@192.168.1.100:~/Downloads/
# 在 iPhone 上用 Filza 安装
```

## 📊 状态检查

### 检查 App 运行
```bash
# 通过 SSH 检查
ssh mobile@192.168.1.100 "ps aux | grep StarCore"
```

### 检查 daemon
```bash
curl http://localhost:9090/health
# 预期: {"status": "ok", "version": "v6.0"}
```

### 检查 iOS MCP
```bash
curl http://localhost:18090/health
# 预期: {"server": "ios-mcp", "status": "ok"}
```

## 🐛 故障排除

### 问题 1: App 无法启动
- 检查签名是否有效
- 检查开发者证书是否信任
- 查看控制台日志: `log stream --predicate "process == 'StarCore'"`

### 问题 2: 无法连接 daemon
- 检查 SSH 隧道: `ss -tlnp | grep 9090`
- 检查 daemon 进程: `ps aux | grep daemon`
- 重启 daemon: `launchctl kickstart -k system/com.starcore.daemon`

### 问题 3: Tweak 未注入
- 检查 plist: `/var/jb/usr/lib/TweakInject/StarCoreTweak.plist`
- 检查 dylib: `ls -la /var/jb/usr/lib/TweakInject/StarCoreTweak.dylib`
- 重启 SpringBoard: `killall SpringBoard`

## 📞 支持

- GitHub: https://github.com/WYT962464/StarCore
- 文档: `/home/ubuntu/starcore/ios/README.md`
