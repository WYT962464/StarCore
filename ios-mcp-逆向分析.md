# ios-mcp 逆向分析与 Tweak 移植方案

## 一、ios-mcp 架构

ios-mcp 本质是一个 **SpringBoard Tweak**（注入到 SpringBoard 进程），通过 HTTP 服务器暴露 MCP JSON-RPC 接口。

### 核心模块

| 模块 | 文件 | 功能 | iOS API |
|------|------|------|---------|
| **HIDManager** | HIDManager.h/m | 触摸/按键模拟 | IOHIDEventSystemClient + IOHIDEvent (私有API) |
| **AccessibilityManager** | AccessibilityManager.h/m | UI节点树 | AXUIElement (无障碍API) + 私有AX框架 |
| **ScreenManager** | ScreenManager.h/m | 截图 | _UICreateScreenUIImage / CARenderServerCaptureDisplay (私有API) |
| **TextInputManager** | TextInputManager.h/m | 文字输入 | IOHIDEventCreateUnicodeEvent (私有API) + HID键盘事件 |
| **ClipboardManager** | ClipboardManager.h/m | 剪贴板 | UIPasteboard.generalPasteboard (公开API) |
| **AppManager** | AppManager.h/m | App管理 | LSApplicationWorkspace (私有API) + FBSScene/openURL |
| **MCPServer** | MCPServer.m | MCP协议层 | HTTP服务器 + JSON-RPC |

### 注入方式
- Tweak.x: Logos语法，注入到 SpringBoard (`Bundles=("com.apple.springboard")`)
- 启动 HTTP 服务器在 8090 端口
- mcp-root: root提权辅助进程（安装IPA等需要root权限的操作）

---

## 二、各功能实现原理

### 2.1 触摸模拟 (HIDManager)

**核心API**: `IOHIDEventSystemClientCreate` + `IOHIDEventSystemClientDispatchEvent`

**关键流程**:
1. 创建 `IOHIDEventSystemClientRef` 客户端
2. 构造触摸事件:
   - 父事件: `IOHIDEventCreateDigitizerEvent` (transducerType=Hand, senderID=固定值)
   - 子事件: `IOHIDEventCreateDigitizerFingerEvent` (含归一化坐标 x/width, y/height)
3. 设置 senderID: `IOHIDEventSetSenderID(event, 0x8000000817319372)` — 这个固定ID很关键！
4. 分发事件: `IOHIDEventSystemClientDispatchEvent(_hidClient, event)`

**触摸三阶段**:
- Began: `kIOHIDDigitizerEventRange | kIOHIDDigitizerEventTouch`
- Moved: `kIOHIDDigitizerEventPosition`
- Ended: `kIOHIDDigitizerEventTouch` (range=NO, touch=NO)

**滑动**: Began → N步Moved → Ended，每步usleep
**长按**: 本质是"原地滑动"（开始点+0.5偏移，持续 Moved）
**双击**: 两次完整 tap，中间 usleep

**关键发现**: 
- 坐标是**归一化**的 (point.x / screenWidth, point.y / screenHeight)
- senderID 是硬编码的 `0x8000000817319372`，iOS 用它过滤合成事件
- 需要 `IOHIDPrivate.h` 私有头文件

### 2.2 硬件按键 (HIDManager)

**核心API**: `IOHIDEventCreateKeyboardEvent`

按键映射:
- Home: kHIDPage_Consumer + kHIDUsage_Csmr_Menu
- Power: kHIDPage_Consumer + kHIDUsage_Csmr_Power
- Volume Up/Down: kHIDPage_Consumer + kHIDUsage_Csmr_VolumeIncrement/Decrement
- Mute: kHIDPage_Consumer + kHIDUsage_Csmr_Mute

流程: 创建 keydown 事件 → usleep → 创建 keyup 事件

### 2.3 截图 (ScreenManager)

**三级降级策略**:
1. `CARenderServerCaptureDisplay` (QuartzCore私有) — 最可靠
2. `_UICreateScreenUIImage` (UIKit私有) — 次选
3. IOSurface + `UICreateCGImageFromIOSurface` — 最后手段

**压缩**: JPEG，初始质量0.82，目标<400KB，二分搜索最优质量

**关键**: 在SpringBoard进程内调用这些私有API，因为截图权限只给SpringBoard

### 2.4 UI节点树 (AccessibilityManager)

**核心API**: `AXUIElement` 系统 + 私有AX框架

**复杂之处**:
- 使用 `AXUIElement` API 获取无障碍树
- 需要激活 VoiceOver 运行时 (`AXUIElement.h` 私有API)
- 使用 `MCPAXQueryContext` 管理查询上下文
- 使用 `MCPAXRemoteContextResolver` 解析远程进程的UI
- 使用 `MCPAXUIClientDelegateBridge` 与AX服务通信

**输出格式**:
```json
{
  "screen": {"width": 375, "height": 812, "scale": 3},
  "processName": "WeChat",
  "bundleId": "com.tencent.xin",
  "elements": [
    {"index":0, "text":"聊天", "type":"button", "clickable":true, "tap":{"x":187.5,"y":50}},
    ...
  ]
}
```

### 2.5 文字输入 (TextInputManager)

**两种模式**:
1. `input_text`: 通过剪贴板+粘贴（最快）
   - 使用 `IOHIDEventCreateUnicodeEvent` (私有API) 发送Unicode事件
   - 需要 `BKSHIDEventSendToProcess` 发送到目标进程
   - 降级方案: setClipboard → 长按 → 粘贴

2. `type_text`: 逐字符HID键盘模拟
   - ASCII字符: 查HID usage表，发送 keydown/keyup
   - 非ASCII: 通过 `IOHIDEventCreateUnicodeEvent` 发送Unicode事件

**关键私有API**:
- `IOHIDEventCreateUnicodeEvent`: 从Unicode字符创建HID事件
- `BKSHIDEventSendToProcess`: 将HID事件发送到指定进程 (BackBoardServices私有)

### 2.6 剪贴板 (ClipboardManager)

**API**: `UIPasteboard.generalPasteboard` (公开API)

非常简单:
- 读: `pb.string`, `pb.hasImages`, `pb.hasURLs`, `pb.URL`
- 写: `pb.string = text`

⚠️ 必须在主线程操作: `dispatch_sync(dispatch_get_main_queue(), block)`

### 2.7 App管理 (AppManager)

**核心API**: `LSApplicationWorkspace` (私有API)

- 启动App: `FBSScene` open 或 `openURL` scheme
- 关闭App: `FBSScene` terminate
- 列表: `LSApplicationWorkspace allInstalledApplications`
- 运行中: `FBSScene` running
- 安装IPA: root提权后 `appinst` 命令行工具
- 卸载: `LSApplicationWorkspace uninstallApplication`

---

## 三、与 StarCore Tweak 的差距分析

| 能力 | StarCore Tweak v8.3 | ios-mcp v1.1.0 | 差距 |
|------|---------------------|-----------------|------|
| 触摸(tap) | ✅ IOHIDEvent | ✅ 同原理 | 无 |
| 滑动(swipe) | ❌ 未实现 | ✅ | 需实现 |
| 长按 | ✅ 基础 | ✅ 更完善 | 小 |
| 硬件按键 | ❌ 未实现 | ✅ HID键盘事件 | **大** |
| 截图 | ❌ 未实现 | ✅ 三级降级 | **大** |
| UI树 | ❌ 未实现 | ✅ AXUIElement | **大** |
| 文字输入 | ❌ 仅clipboard | ✅ 直接输入 | **中** |
| 剪贴板 | ✅ | ✅ | 无 |
| App启动 | ✅ openApp | ✅ 更稳定 | 小 |
| App列表 | ❌ | ✅ | 中 |
| Shell | ✅ | ✅ | 无 |

---

## 四、移植优先级

### P0 - 微信群发消息必须
1. **硬件按键** (press_home) — 导航必备，代码量小
2. **文字输入** (input_text) — 比clipboard粘贴更可靠
3. **截图** — 验证操作结果

### P1 - 提升自动化能力
4. **UI树** — 精准定位元素，告别盲点
5. **滑动** — 页面滚动

### P2 - 完整体验
6. **双击/拖拽** — 增强手势
7. **App列表/管理** — 设备控制

---

## 五、移植方案

### 5.1 最快路径：直接复用 ios-mcp 的代码

ios-mcp 是 MIT 协议！可以直接复用。

关键文件：
- `HIDManager.h/m` → 直接集成到 Tweak
- `IOHIDPrivate.h` → 私有API声明
- `ClipboardManager.h/m` → 已有，对比确认
- `ScreenManager.h/m` → 截图功能
- `TextInputManager.h/m` → 文字输入

### 5.2 实现步骤

**Step 1: 硬件按键** (30min)
- 复制 IOHIDPrivate.h
- 在 Tweak 中添加 pressButton action
- 处理: home, power, volumeUp, volumeDown

**Step 2: 截图** (1h)
- 复制 ScreenManager 的截图逻辑
- 添加 screenshot action
- 返回 base64 JPEG

**Step 3: 文字输入** (1h)
- 复制 TextInputManager 的 inputText
- 优先使用 IOHIDEventCreateUnicodeEvent
- 降级到 clipboard+paste

**Step 4: UI树** (2h+)
- 最复杂，依赖最多私有API
- 考虑先简化版：只获取当前App的可点击元素
- 或直接通过 ios-mcp 调用（过渡期）

### 5.3 Tweak action 扩展

```json
{"action": "pressHome"}
{"action": "pressPower"}
{"action": "swipe", "fromX": 200, "fromY": 400, "toX": 200, "toY": 100, "duration": 300}
{"action": "screenshot"}  → 返回 base64 JPEG
{"action": "inputText", "text": "hello"}  → 直接输入（不走剪贴板）
{"action": "getUIElements"}  → 返回简化UI树
```
