# 易经记忆体系补充条目

## [巽][少阴][采集][API 文档] iOS MCP 工具列表（34 个）

### 触控类
- `tap_screen` - 点击屏幕指定位置
- `swipe_screen` - 滑动屏幕
- `long_press` - 长按屏幕
- `double_tap` - 双击屏幕
- `drag_and_drop` - 拖拽

### 硬件控制
- `press_home` - 按下 Home 键
- `press_power` - 按下电源键
- `press_volume_up/down` - 音量控制
- `toggle_mute` - 静音切换
- `wake_and_home` - 唤醒并返回主屏

### 输入类
- `input_text` - 输入文本
- `type_text` - 逐字输入
- `press_key` - 按下特定按键
- `set_clipboard` - 设置剪贴板
- `get_clipboard` - 获取剪贴板

### App 管理
- `launch_app` - 启动应用
- `kill_app` - 关闭应用
- `list_apps` - 列出已安装应用
- `install_app` - 安装应用
- `uninstall_app` - 卸载应用

### UI 交互
- `get_ui_elements` - 获取 UI 元素
- `get_element_at_point` - 获取指定位置元素
- `get_frontmost_app` - 获取前台应用

### 设备信息
- `get_screen_info` - 获取屏幕信息
- `get_device_info` - 获取设备信息
- `screenshot` - 截图
- `get_brightness` / `set_brightness` - 亮度控制
- `get_volume` / `set_volume` - 音量控制
- `run_command` - 执行 Shell 命令

---

## [坎][太阳][问题][调试记录] Tweak 注入失败诊断

### 问题现象
- SpringBoard 无 `DYLD_INSERT_LIBRARIES` 环境变量
- ElleKit 注入机制未工作
- iOS MCP HTTP 服务器未启动（端口 8090/9090/18090 均无监听）

### 根本原因
1. **Dopamine rootless 环境**：ElleKit 注入机制与 rootless 越狱不兼容
2. **CydiaSubstrate 依赖缺失**：所有 Tweak 依赖 `@rpath/CydiaSubstrate.framework/CydiaSubstrate`，但系统中不存在
3. **ElleKit 配置问题**：`/var/jb/usr/lib/ellekit/` 存在，但 SpringBoard 未链接到 `libinjector.dylib`

### 临时方案
- 使用 iOS MCP HTTP 服务（通过 SSH 隧道访问）
- 端口转发：`ssh -f -N -p 8029 mobile@localhost -L 8091:127.0.0.1:8090`
- MCP 地址：`http://127.0.0.1:8091/mcp`

### 待解决问题
1. ElleKit 注入配置（需要 root 权限）
2. SpringBoard 链接 ElleKit
3. Tweak 双架构编译（arm64 + arm64e）
4. Sender ID 验证

---

## 八卦分类映射表

| 卦象 | 符号 | 属性 | 工作场景 | 记忆条目 |
|------|------|------|----------|----------|
| 乾 | ☰ | 决策 | 架构设计/方案选择 | 3 条 |
| 坤 | ☷ | 存储 | 文件/数据持久化 | 2 条 |
| 震 | ☳ | 触发 | 自动化/定时器/事件 | 1 条 |
| 巽 | ☴ | 采集 | API/数据源/工具 | 待补充 |
| 坎 | ☵ | 问题 | 错误记录/调试 | 待补充 |
| 离 | ☲ | 展示 | 报告/输出/格式 | 1 条 |
| 艮 | ☶ | 边界 | 安全/限制/策略 | 1 条 |
| 兑 | ☱ | 交互 | 用户/对话/反馈 | 2 条 |

---

## 维护机制

### 定期清理
- **频率**：每周检查，每月归档
- **阈值**：MEMORY > 80% 触发清理
- **原则**：临时信息优先删除，核心架构保留

### 归档位置
- `~/.hermes/memory/archive/completed-projects.md`
- `~/.hermes/memory/archive/`

### 分类标准
- 项目完成 → 归档到 completed-projects.md
- 临时调试 → 清理或删除
- 核心架构 → 永久保留

---

*生成时间：2026-05-28 03:00*
*阿腾认知核心校准后补充*