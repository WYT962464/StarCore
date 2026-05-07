# StarCore - 星核 iOS App

> 双层架构智能体核心系统

## 架构概述

StarCore 采用双层架构设计，分为**阶段十（生命中枢）**和**阶段十二（人格认知）**：

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

### 双层隔离机制

- **物理隔离**：架构设计上的分层，上层只能通过协议访问下层
- **代码隔离**：`LifeCoreProtocol` 只暴露 `get` 属性
- **熔断器**：`MindLock` 检测违规写入并触发熔断

## 技术规格

- **最低iOS版本**：iOS 15.0+
- **UI框架**：SwiftUI
- **目标设备**：iPhone X 及以上
- **架构**：双层隔离（生命中枢 + 人格认知）

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

### Xcode Cloud（推荐）

项目已配置 `.github/workflows/build-ios.yml`，推送到 GitHub 后自动编译。

### 本地 Xcode

1. 克隆仓库：
   ```bash
   git clone https://github.com/WYT962464/StarCore.git
   cd StarCore
   git checkout v1.0-dual-layer
   ```

2. 用 Xcode 打开 `StarCore.xcodeproj`

3. **重要**：由于新文件未自动添加到 Xcode 项目，请手动添加源文件：
   - 在 Xcode 中右键 `StarCore` 文件夹
   - 选择 "Add Files to StarCore..."
   - 添加 `StarCore/` 目录下的所有 Swift 文件

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
│   └── UI/
│       ├── DashboardView.swift     # 主仪表盘
│       ├── LifeSignsView.swift     # 生命体征
│       └── EmotionView.swift       # 情绪显示
└── README.md
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

## 许可证

MIT License
