# 星核 v8.4 - StarCore Native App

Swift原生重写版，替代原有的WKWebView+Python架构。一个App搞定所有。

## 架构变化

| 旧架构 | 新架构 |
|--------|--------|
| WKWebView加载localhost:8643 | Swift UIKit原生聊天界面 |
| Python HTTP服务器 | Swift原生Agent逻辑 |
| HTML/CSS/JS UI | UIKit纯代码布局 |
| Python urllib调用LLM | URLSession async POST |
| Python socket连接Tweak | NWConnection (Network.framework) |
| Python正则解析动作 | NSRegularExpression解析 |

## 文件清单

```
StarCoreApp/
├── Makefile                    # Theos编译配置
├── Info.plist                  # App配置（ATS、版本等）
├── resources/
│   └── LaunchScreen.storyboard # 启动屏
├── AppDelegate.swift           # 入口：TabBar（聊天|设置）
├── Models.swift                # 数据模型：ChatMessage, LLMProvider等
├── StarCoreAgent.swift         # Agent核心：LLM调用+Tweak通信+动作解析
├── ChatViewController.swift    # 聊天界面：气泡+输入+状态栏
├── SettingsViewController.swift # 设置页：Provider/Key/超脑/记忆
└── MemoryManager.swift         # 记忆文件管理：SOUL.md等
```

## 功能

### 聊天界面
- 深空蓝渐变背景
- 用户蓝色气泡 / 星核半透明白气泡
- 输入框 + 发送按钮
- 顶部状态栏：Tweak连接 + LLM Provider + 云端超脑
- 底部Tab：聊天 | 设置
- 开场语："核心就位｜星核系统｜启动完毕。随时响应你的一切指令。"

### Agent核心
- **LLM API**：URLSession POST，支持多Provider切换，429自动Fallback
  - DeepSeek（免费，500万token）— 默认
  - Gemini（免费，1500次/天）
  - Groq（免费，30RPM）
  - 硅基流动（有免费额度）
  - 自定义URL
- **Tweak通信**：NWConnection TCP连localhost:6000
  - 动作：tap/swipe/shell/openApp/pressHome/getScreenSize
  - v8.4新增：inputText/typeText/pressPower/pressVolumeUp/pressVolumeDown/getScreenInfo
  - 截图：优先Tweak截图（快），失败fallback到ios-mcp
- **ios-mcp**（备选方案）：需localhost:8090运行
  - 动作：iosMcpTap/iosMcpSwipe/iosMcpGetUI/iosMcpLaunchApp/iosMcpListApps
- **动作解析**：正则提取JSON动作→执行→替换为✓
- **对话历史**：UserDefaults持久化，最多40条

### 云端超脑
- 设置页配置扣子Bot API地址和Token
- 聊天模式切换：本地/云端

### 本地记忆包
- 启动时读取 `/var/mobile/StarCoreAgent/memory/files/SOUL.md`
- 注入system_prompt（截取前2000字符）
- 设置页可查看记忆文件状态

## 编译

### 前置条件
- macOS + Theos
- iOS SDK 15.0+
- Xcode Command Line Tools

### 编译步骤

```bash
# 1. 确保Theos已安装
export THEOS=~/theos

# 2. 进入App目录
cd StarCore/StarCoreApp

# 3. 清理旧构建
make clean

# 4. 编译打包
make package

# 5. 产物位置
ls .theos/packages/  # .deb文件
```

## 安装

### TrollStore安装
1. 将编译好的 `.deb` 传到iPhone
2. 用Filza解压deb，取出 `/Applications/StarCoreApp.app`
3. 放到 `/Applications/StarCoreApp.app`
4. TrollStore刷新或重启SpringBoard

### 也可以直接用Theos安装
```bash
make install THEOS_DEVICE_IP=<iPhone-IP>
```

## 首次使用

1. 打开App，进入**设置**Tab
2. 选择LLM Provider（默认硅基流动）
3. 输入API Key
4. 回到聊天Tab，开始对话

## 与Hermes-Lite的关系

Hermes-Lite (port 8642) 保留作为崩溃备胎，与本App互不冲突：
- 本App使用原生Swift逻辑，不依赖任何Python进程
- 如果本App出问题，Hermes-Lite仍可通过浏览器访问

## 技术细节

### Theos + Swift编译
- Makefile中使用 `StarCoreApp_FILES` 列出所有 `.swift` 文件
- `StarCoreApp_FRAMEWORKS = UIKit Foundation Network`
- `@UIApplicationMain` 在 AppDelegate.swift 中声明入口
- 不需要 main.swift 或 main.m

### TCP通信
使用 Network.framework 的 NWConnection：
- 非阻塞式TCP连接
- 5秒超时
- 自动重连检测

### 动作解析正则
两种格式支持：
1. ` ```json {...} ``` ` 代码块格式
2. 裸JSON格式 `{"action":"tap",...}`

### 兼容性
- iOS 15.5+
- iPhone 8 ~ iPhone 15 Pro Max
- arm64 + arm64e 双架构编译
