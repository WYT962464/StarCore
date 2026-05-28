# StarCore iPhone App — 部署指南

> **版本**: v1.0  
> **时间**: 2026-05-29  
> **卦象**: 乾 ☰ (创造/决策)

---

## 一、快速开始

### 1.1 构建 IPA

```bash
cd /home/ubuntu/starcore/ios
chmod +x build.sh
./build.sh
```

输出：
```
📦 IPA: build/StarCore.ipa
📊 大小: 15M
```

### 1.2 传输到 iPhone

```bash
chmod +x ssh_transfer.sh
./ssh_transfer.sh
```

文件位置：
- iPhone: `/tmp/StarCore.ipa`
- Tweak: `/tmp/tweak/`

### 1.3 安装

**方法 1: Filza（推荐）**
1. 打开 Filza
2. 导航到 `/tmp/`
3. 点击 `StarCore.ipa` → 安装

**方法 2: AltStore**
1. 将 IPA 传输到电脑
2. 使用 AltStore 安装

**方法 3: Sideloadly**
1. 下载 Sideloadly
2. 拖入 IPA 文件
3. 使用 Apple ID 签名安装

---

## 二、Tweak 安装

### 2.1 准备 Tweak 文件

```bash
# Tweak 文件位置
/var/jb/usr/lib/TweakInject/
  ├─ StarCoreTweak.dylib
  └─ StarCoreTweak.plist
```

### 2.2 安装步骤

**使用 Filza:**

1. 打开 Filza
2. 导航到 `/tmp/tweak/`
3. 复制 `StarCoreTweak.dylib` 到 `/var/jb/usr/lib/TweakInject/`
4. 复制 `StarCoreTweak.plist` 到 `/var/jb/usr/lib/TweakInject/`
5. 重启 SpringBoard

**使用终端（需要 sudo）:**

```bash
# 传输到 iPhone
scp -P 22 /tmp/tweak/* mobile@10.70.92.235:/tmp/

# SSH 到 iPhone
ssh mobile@10.70.92.235

# 安装（需要 sudo 密码）
sudo cp /tmp/StarCoreTweak.dylib /var/jb/usr/lib/TweakInject/
sudo cp /tmp/StarCoreTweak.plist /var/jb/usr/lib/TweakInject/

# 重启 SpringBoard
sudo killall SpringBoard
```

### 2.3 inject.plist 配置

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Bundles</key>
    <array>
        <dict>
            <key>BundlePath</key>
            <string>/var/jb/usr/lib/TweakInject/StarCoreTweak.dylib</string>
            <key>ProcessName</key>
            <string>SpringBoard</string>
        </dict>
    </array>
</dict>
</plist>
```

位置：`/var/jb/usr/lib/ellekit/inject.plist`

---

## 三、服务器配置

### 3.1 SSH 反向隧道

**iPhone 端（建立反向隧道）:**

```bash
ssh -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -R 8028:localhost:22 \
    ubuntu@124.222.29.75
```

**服务器端（验证隧道）:**

```bash
# 检查端口监听
ss -tlnp | grep 8028

# 测试连接
ssh -p 8028 localhost
```

### 3.2 云电脑连接

App 内配置：
1. 打开 StarCore App
2. 进入 ⚙️ 设置
3. 云电脑配置：
   - 服务器 IP: `124.222.29.75`
   - SSH 端口: `8028`
   - 用户名: `ubuntu`
4. 点击"连接云电脑"

---

## 四、App 功能说明

### 4.1 对话窗口（💬）

- 多模型切换（SenseNova/OpenAI/Claude/DeepSeek）
- 三位一体决策显示
- 云电脑/本地执行自动选择

### 4.2 记忆管理（🧠）

- 易经记忆体系（64 卦分类）
- 记忆条目搜索
- 导入/导出功能

### 4.3 文件管理（📁）

- 本地文件浏览
- 云电脑文件同步
- 上传/下载功能

### 4.4 设置（⚙️）

- LLM API 配置
- 云电脑连接
- 三位一体/六十四卦开关
- 自循环间隔设置

---

## 五、开发环境

### 5.1 依赖

| 组件 | 版本 | 说明 |
|------|------|------|
| Xcode | 15+ | iOS 开发环境 |
| Swift | 5.9+ | 编程语言 |
| iOS SDK | 17+ | 目标平台 |

### 5.2 项目结构

```
ios/
├── StarCoreApp.swift       # 应用入口
├── ContentView.swift       # 主界面
├── ChatView.swift          # 对话窗口
├── MemoryView.swift        # 记忆管理
├── FileView.swift          # 文件管理
├── SettingsView.swift      # 设置界面
├── Managers.swift          # 核心管理器
├── ThreeSagesFramework.swift # 三位一体框架
├── GuaEngine.swift         # 六十四卦引擎
├── build.sh                # 构建脚本
├── ssh_transfer.sh         # 传输脚本
└── DEPLOYMENT_GUIDE.md     # 部署指南
```

---

## 六、故障排除

### 6.1 IPA 安装失败

**问题**: IPA 安装后无法打开

**解决**:
1. 检查签名是否有效
2. 使用 AltStore 重新签名
3. 信任开发者证书（设置 → 通用 → VPN 与设备管理）

### 6.2 Tweak 注入失败

**问题**: SpringBoard 崩溃

**解决**:
1. 检查 inject.plist 格式（必须是 XML）
2. 确认 dylib 架构（arm64 + arm64e）
3. 检查 ElleKit 配置
4. 查看 `/var/log/syslog` 日志

### 6.3 云电脑连接失败

**问题**: SSH 隧道断开

**解决**:
1. 检查服务器网络可达性
2. 验证 SSH 端口（8028）
3. 检查反向隧道是否建立
4. 重启 SSH 连接

### 6.4 模型 API 调用失败

**问题**: LLM 响应超时

**解决**:
1. 检查 API Key 是否有效
2. 验证 Base URL
3. 检查网络连接
4. 切换备用模型

---

## 七、下一步

### Phase 1: 基础框架 ✅
- [x] SwiftUI 主界面
- [x] 模型切换栏
- [x] 本地存储

### Phase 2: 核心功能 🔄
- [ ] 对话管理器完善
- [ ] 记忆管理器完善
- [ ] LLM API 集成

### Phase 3: 系统整合 ⏳
- [ ] 三位一体决策引擎
- [ ] 六十四卦自循环
- [ ] 文件管理器

### Phase 4: 云电脑连接 ⏳
- [ ] SSH 反向隧道
- [ ] 服务器状态监控
- [ ] 文件同步

### Phase 5: Tweak 注入 ⏳
- [ ] ElleKit inject.plist
- [ ] SpringBoard 注入
- [ ] 系统操控 API

---

*部署指南 v1.0*
*卦象：乾 ☰*
