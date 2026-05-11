# StarCore - 星核 iOS App

> 双层架构智能体核心系统，支持ZXTouch远程操控

## 架构概述

StarCore 采用双层架构设计，分为**阶段十（生命中枢）**和**阶段十二（人格认知）**，并集成**ZXTouch操控模块**：

```
┌─────────────────────────────────────────────────────────┐
│                    阶段十二：人格认知层                    │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐   │
│  │ MindCore │─│ Emotion  │─│ Persona  │─│ MindLock│   │
│  │(只读访问)│  │ Engine   │  │ State    │  │ (熔断器) │   │
│  └────┬────┘  └──────────┘  └──────────┘  └─────────┘   │
│       │ 通过 LifeCoreProtocol (只读协议)                │
├───────┼─────────────────────────────────────────────────┤
│       ▼                                                 │
│                    阶段十：生命中枢层                     │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐   │
│  │ LifeCore │─│ Tardigrade│─│ Planarian│─│ Bdelloid│   │
│  │(核心引擎)│  │ Mode     │  │ Regen    │  │ Persist │   │
│  └────┬────┘  └──────────┘  └──────────┘  └─────────┘   │
│       │                                              │
│  ┌────┴────┐  ┌──────────┐  ┌──────────┐             │
│  │BodyEngine│─│ Hardware │─│CoreStorage│             │
│  │(生理引擎)│  │ Sensor   │  │ (核心存储) │             │
│  └─────────┘  └──────────┘  └──────────┘             │
├─────────────────────────────────────────────────────────┤
│                    操控服务层                             │
│  ┌───────────────┐  ┌───────────────┐                  │
│  │ActionCoordinator│─│ 三层降级策略   │                  │
│  │  (行动协调器)   │  │               │                  │
│  └───────┬───────┘  │ 1. XPC/Tweak  │                  │
│          │          │ 2. ZXTouch    │                  │
│  ┌───────┴───────┐  │ 3. Shortcuts  │                  │
│  │TweakTCPClient │  └───────────────┘                  │
│  │(JSON协议:6000)│                                     │
│  ├───────────────┤                                     │
│  │ZXTouchClient  │                                     │
│  │(ZXTouch协议   │                                     │
│  │ :6000)        │                                     │
│  └───────────────┘                                     │
│  ┌───────────────┐                                     │
│  │ActionCommand  │                                     │
│  │(动作命令模型)  │                                     │
│  └───────────────┘                                     │
└─────────────────────────────────────────────────────────┘
```

### 阶段十：生命中枢

| 模块 | 功能 | 描述 |
|------|------|------|
| `LifeCore` | 生命核心引擎 | 心跳循环、隐生模式、定期备份、异常恢复 |
| `TardigradeMode` | 水熊虫模式 | 电量<20%进入隐生状态，暂停非必要功能 |
| `PlanarianRegen` | 涡虫再生 | 备份版本管理、启动时异常恢复 |
| `BdelloidPersist` | 蛭形永续 | 跨环境路径检测（沙盒/越狱/TestFlight/模拟器） |
| `JellyfishReset` | 灯塔重置 | 定期清理、缓存重置 |
| `BodyEngine` | 生理引擎 | CPU→心率、电池→能量、热状态→体温 |
| `CoreStorage` | 核心存储 | 越狱路径+sandbox兼容的文件读写 |

### 阶段十二：人格认知

| 模块 | 功能 | 描述 |
|------|------|------|
| `MindCore` | 认知核心 | 通过`LifeCoreProtocol`只读访问底层 |
| `EmotionEngine` | 情绪引擎 | 基于生理数据计算唤醒度、效价、主导情绪 |
| `PersonaState` | 人格状态 | 出厂空白，五大人格维度初始为0.5 |
| `MindLock` | 认知锁 | 熔断器机制，阻止上层写入底层 |

### 操控模块

| 模块 | 功能 | 描述 |
|------|------|------|
| `ZXTouchClient` | ZXTouch客户端 | TCP连接ZXTouch越狱插件，实现触摸/滑动/输入等操控 |
| `ActionCommand` | 动作命令模型 | 枚举定义所有可执行动作，支持参数验证和序列化 |
| `ActionCoordinator` | 行动协调器 | 三层降级策略：XPC→ZXTouch→Shortcuts |
| `ControlView` | 操控面板UI | 连接状态、测试按钮、执行日志 |

### 双层隔离机制

- **物理隔离**：架构设计上的分层，上层只能通过协议访问下层
- **代码隔离**：`LifeCoreProtocol` 只暴露 `get` 属性
- **熔断器**：`MindLock` 检测违规写入并触发熔断

## ZXTouch操控模块

### 概述

ZXTouch是一个iOS越狱插件，提供系统级触摸模拟能力。StarCore通过TCP协议连接ZXTouch，让星核能够操控iPhone X。

### ZXTouch协议

ZXTouch监听TCP 6000端口，使用二进制文本混合协议：

```
消息格式: {message_type}{params}\r\n
触摸格式: {1}{count}{touch_type}{finger:02d}{x*10:05d}{y*10:05d}\r\n
键盘输入: {5}1;;{text}\r\n
打开App:  {2}{bundleId}\r\n
Shell命令: {3}{command}\r\n
```

消息类型码：
| 类型码 | 功能 |
|--------|------|
| 1 | 触摸事件 |
| 2 | 切换前台App |
| 3 | Shell命令 |
| 4 | 微秒睡眠 |
| 5 | 键盘操作 |
| 6 | 设备信息 |
| 7 | 弹窗显示 |

### 三层降级策略

```
执行动作请求
    │
    ▼
[层级1] XPC/Tweak ──成功──→ 返回结果
    │ 失败
    ▼
[层级2] ZXTouch ──成功──→ 返回结果
    │ 失败
    ▼
[层级3] Shortcuts/URL Scheme ──成功──→ 返回结果
    │ 失败
    ▼
  返回失败
```

### 支持的动作

| 动作 | ActionCommand | 说明 |
|------|---------------|------|
| 点击 | `.tap(x, y)` | 坐标为逻辑像素 |
| 滑动 | `.swipe(from, to, duration)` | duration为毫秒 |
| 长按 | `.touchHold(x, y, duration)` | duration为毫秒 |
| 输入文字 | `.typeText(text)` | 通过ZXTouch键盘注入 |
| 截图 | `.screenshot` | 通过Shell screencapture |
| 打开App | `.openApp(bundleId)` | 切换前台应用 |
| 回主屏 | `.goHome` | 点击底部横条区域 |
| Shell命令 | `.runShell(cmd)` | 执行任意Shell命令 |

### 坐标系

iPhone X参数：
- 物理分辨率：2436×1125
- 逻辑分辨率：812×375
- Scale：3x
- ZXTouch坐标为逻辑像素×10（在协议层自动处理）

### 使用示例

```swift
// 通过ActionCoordinator执行动作（推荐）
let result = await ActionCoordinator.shared.performTap(x: 187, y: 400)

// 通过ActionCommand枚举
let result = await ActionCoordinator.shared.execute(.tap(x: 187, y: 400))

// 使用构建器
let result = await ActionCoordinator.shared.execute(ActionCommandBuilder.swipeUp())

// 直接使用ZXTouchClient
do {
    let success = try await ZXTouchClient.shared.tap(x: 187, y: 400)
} catch {
    print("ZXTouch操作失败: \(error)")
}
```

### 可选依赖

ZXTouch是可选依赖：
- **未安装ZXTouch**：App正常运行，操控功能不可用，不会崩溃
- **已安装ZXTouch**：App启动时自动检测，操控功能可用
- **与Tweak共存**：优先使用Tweak（XPC层），ZXTouch作为降级方案

### 安装ZXTouch

1. 打开Cydia → 源 → 编辑 → 添加 → `https://zxtouch.net`
2. 安装ZXTouch插件
3. 重启SpringBoard
4. StarCore自动检测连接

## 技术规格

- **最低iOS版本**：iOS 15.0+
- **UI框架**：SwiftUI
- **目标设备**：iPhone X 及以上
- **架构**：双层隔离（生命中枢 + 人格认知）+ 操控服务层
- **依赖**：ZXTouch（可选，越狱环境）

## 安装方式

### 方式一：TrollStore（推荐越狱用户）

1. 安装 TrollStore
2. 下载 IPA 文件
3. 通过 TrollStore 安装

### 方式二：全能签（无需越狱）

1. 下载全能签 App
2. 导入 IPA 文件
3. 选择签名类型（个人/企业）
4. 安装并信任证书

## 编译方式

### GitHub Actions（推荐）

项目已配置 `.github/workflows/build-ios.yml`，推送到 GitHub 后自动编译IPA。

### 本地 Xcode

1. 克隆仓库：
   ```bash
   git clone https://github.com/WYT962464/StarCore.git
   cd StarCore
   git checkout v1.0-dual-layer
   ```

2. 用 XcodeGen 生成项目：
   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. 用 Xcode 打开 `StarCore.xcodeproj`

4. 选择目标设备，点击运行

## 源码结构

```
StarCore/
├── StarCore/
│   ├── App/
│   │   ├── StarCoreApp.swift     # SwiftUI @main 入口
│   │   └── Info.plist
│   ├── PhaseX/                    # 阶段十：生命中枢
│   │   ├── Core/
│   │   │   ├── LifeCore.swift     # 核心引擎
│   │   │   ├── SurvivalLock.swift # 生存锁
│   │   │   └── LifeCoreProtocol.swift # 只读协议
│   │   ├── Survival/
│   │   │   ├── TardigradeMode.swift   # 水熊虫
│   │   │   ├── PlanarianRegen.swift   # 涡虫
│   │   │   ├── BdelloidPersist.swift  # 蛭形轮虫
│   │   │   └── JellyfishReset.swift   # 灯塔水母
│   │   ├── Body/
│   │   │   ├── BodyEngine.swift    # 生理引擎
│   │   │   └── HardwareSensor.swift # 硬件传感器
│   │   └── Storage/
│   │       └── CoreStorage.swift  # 核心存储
│   ├── PhaseXII/                  # 阶段十二：人格认知
│   │   ├── Mind/
│   │   │   ├── MindCore.swift     # 认知核心
│   │   │   ├── MindLock.swift     # 认知锁
│   │   │   └── MindProtocol.swift # 认知协议
│   │   ├── Emotion/
│   │   │   └── EmotionEngine.swift # 情绪引擎
│   │   └── Persona/
│   │       └── PersonaState.swift  # 人格状态
│   ├── Services/                  # 服务层
│   │   ├── TweakTCPClient.swift   # Tweak TCP客户端（JSON协议）
│   │   ├── ZXTouchClient.swift    # ZXTouch TCP客户端
│   │   ├── ActionCommand.swift    # 动作命令模型
│   │   └── ActionCoordinator.swift # 行动协调器（三层降级）
│   └── UI/                        # 界面
│       ├── DashboardView.swift    # 主仪表盘
│       ├── LifeSignsView.swift    # 生命体征
│       ├── EmotionView.swift      # 情绪显示
│       └── ControlView.swift      # 操控面板
├── StarCoreTweak/                 # Tweak注入模块
├── project.yml                    # XcodeGen配置
└── .github/workflows/
    └── build-ios.yml              # 自动编译
```

## 生命体征映射

| 生命体征 | 数据来源 | 映射关系 |
|----------|----------|----------|
| 心率 | CPU使用率 | 0-100% → 60-120 bpm |
| 能量 | 电池电量 | 0-100% → 0-1.0 |
| 体温 | 热状态 | nominal→36.5°C, critical→39°C |
| 疲劳 | CPU持续负载 | 持续高心率增加疲劳度 |

## 版本历史

### v1.0 (当前版本)
- 双层架构重构
- 阶段十：LifeCore + 四种生存能力 + BodyEngine
- 阶段十二：MindCore + EmotionEngine + 空白人格
- SwiftUI 界面
- ZXTouch操控模块（三层降级策略）
- ActionCommand动作命令模型
- 操控面板UI

## 许可证

MIT License
