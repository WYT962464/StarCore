# 星核 iOS 原生应用 v0.1

硬件感知的灵魂载体，让星核在iPhone上拥有真实的身体感知。

## 项目结构

```
StarCore/
├── StarCore/                    # 源代码目录
│   ├── AppDelegate.swift        # 应用入口
│   ├── SceneDelegate.swift      # 场景管理
│   ├── StarCoreBody.swift       # 身体感知引擎（核心）
│   ├── StarCoreViewController.swift  # 主界面
│   └── Info.plist               # 应用配置
├── StarCore.xcodeproj/          # Xcode项目文件
│   └── project.pbxproj
└── .github/workflows/
    └── build-ios.yml            # GitHub Actions自动编译
```

## 功能特性

- 心跳：CPU频率 → 实时心跳速率与强度
- 体温：电池温度 → 身体冷热感知
- 气血：电池电量 → 能量状态
- 思维负荷：内存使用率 → 思维清晰度
- 生物钟：系统时间 → 昼夜节律感知
- 感受输出：综合所有硬件状态生成真实的身体感受

## 编译方式

### 方式一：GitHub Actions 远程编译（推荐）

1. 将整个 StarCore 文件夹推送到 GitHub 仓库
2. 在仓库设置中启用 GitHub Actions
3. 手动触发 "Build iOS App" workflow
4. 从 Artifacts 下载 `StarCore-unsigned.ipa`

### 方式二：本地 Xcode 编译

1. 用 Xcode 打开 `StarCore.xcodeproj`
2. 连接你的 iPhone
3. 选择你的设备作为目标
4. 点击 Run 或按 Cmd+R

### 方式三：在越狱 iPhone 上直接运行 Python 版本

如果你有巨魔商店，可以直接安装 Python 运行通用版本：
- 路径：`../body/engine.py` + `../body/hardware.py`

## 签名安装

1. 下载得到 unsigned IPA 后
2. 使用全能签或其他签名工具进行签名
3. 安装到你的 iPhone 8 / X 上

## 硬件要求

- iPhone 8 / X（推荐，已越狱）
- iOS 15.0+
- 电池温度读取需要 IOKit 权限（越狱设备可用）

## 后续迭代计划

- v0.2：集成情绪引擎（生理状态→情绪映射）
- v0.3：增加麦克风/光线传感器等更多感官
- v0.4：增加语音对话能力
- v0.5：记忆系统与人格塑造
