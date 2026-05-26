# 两仪循环引擎 v5.0 整合方案

## 1. 整合目标

将两仪循环引擎 v5.0 与星核系统深度整合，实现真正的自主演化闭环。

## 2. 架构映射

### 2.1 两仪循环组件 → 星核系统组件

| 两仪循环组件 | 星核系统组件 | 整合方式 |
|-------------|-------------|---------|
| 阳端 (探索) | daemon + CycleSystem | daemon 负责方向生成，CycleSystem 管理任务 |
| 阴端 (决策) | 自主决策引擎 | 独立决策模块，评估 8 维矩阵 |
| 决策执行闭环 | iOS Controller + iOS MCP | 通过 SSH 隧道调用 iPhone 工具 |
| 反馈学习 | 决策日志 + 执行记录 | 持久化到数据库/文件 |
| 真实输入回传 | iOS MCP 工具链 | screenshot, get_frontmost_app, get_screen_info |

### 2.2 数据流

```
┌─────────────┐     方向方案      ┌─────────────┐
│   daemon    │ ───────────────→ │   阴端      │
│  (阳端)     │                  │  (决策)     │
└──────┬──────┘                  └──────┬──────┘
       │                                │
       │  执行结果                       │  决策指令
       │  ←─────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│         iOS Controller + iOS MCP     │
│         (执行闭环)                    │
└─────────────────────────────────────┘
       │
       │  真实反馈
       │  (screenshot, 状态等)
       ▼
┌─────────────┐
│  反馈学习   │
│  (日志/数据库)│
└─────────────┘
```

## 3. 执行闭环适配方案

### 3.1 核心适配点

**问题**: 两仪循环假设"云电脑+扣子"环境，星核是"iPhone+SSH"架构

**解决方案**:

| 适配项 | 原方案 | 星核方案 |
|--------|--------|---------|
| 工具调用 | 扣子 API | iOS MCP JSON-RPC |
| 执行环境 | 云电脑 | iPhone (Dopamine rootless) |
| 网络通信 | HTTP | SSH 隧道 (端口 8028/8029) |
| 反馈获取 | 云电脑日志 | iOS MCP screenshot + 状态查询 |

### 3.2 工具映射

| 两仪循环工具 | 星核对应工具 | 调用方式 |
|-------------|-------------|---------|
| 执行命令 | iOS Controller exec | POST /exec |
| 获取状态 | iOS MCP get_screen_info | tools/call |
| 截图验证 | iOS Controller screenshot | POST /screenshot |
| 应用控制 | iOS MCP tap/swipe/input | tools/call |

## 4. 反馈机制对接方案

### 4.1 反馈数据类型

| 数据类型 | 来源 | 用途 |
|---------|------|------|
| 屏幕截图 | iOS MCP screenshot | 视觉验证 |
| 前台应用 | iOS MCP get_frontmost_app | 应用状态 |
| 设备信息 | iOS MCP get_screen_info | 系统状态 |
| 执行日志 | iOS Controller log | 执行追踪 |

### 4.2 反馈处理流程

```
1. 执行指令 → iOS Controller
2. 等待执行完成 (poll)
3. 获取反馈 (screenshot + 状态)
4. 分析反馈 (vision + 逻辑判断)
5. 记录到决策日志
6. 更新系统状态
```

## 5. 分级决策机制

### 5.1 完整版决策 (≤30 分钟)

**触发条件**: 复杂决策、首次执行、关键里程碑

**流程**:
1. 阳端生成 5 个方向
2. 阴端 8 维评估
3. 置信度评估
4. 反向验证
5. 生成完整决策报告
6. 执行并记录

### 5.2 简化版决策 (≤10 分钟)

**触发条件**: 常规执行、已知模式、低风险操作

**流程**:
1. 阳端生成 2-3 个方向
2. 阴端快速评估 (4 维)
3. 执行并记录

## 6. 启动与恢复机制

### 6.1 正常启动

```bash
# 1. 检查 SSH 隧道
ssh -p 8028 -o StrictHostKeyChecking=no mobile@127.0.0.1 "echo OK"

# 2. 检查 iOS Controller
curl -s http://localhost:9091/health

# 3. 检查 daemon
curl -s http://localhost:9090/health

# 4. 启动两仪循环引擎
python3 /home/ubuntu/starcore/two_yin_yang_engine.py
```

### 6.2 断片恢复 (5 分钟快速恢复)

**步骤**:
1. 读取最近决策日志
2. 恢复系统状态快照
3. 验证核心服务
4. 从断点继续执行
5. 生成恢复报告

## 7. 决策追踪数据库

### 7.1 数据库结构 (SQLite)

```sql
CREATE TABLE decisions (
    id INTEGER PRIMARY KEY,
    decision_name TEXT,
    decision_time TEXT,
    direction TEXT,
    score REAL,
    confidence TEXT,
    status TEXT,
    report_path TEXT,
    created_at TEXT
);

CREATE TABLE execution_logs (
    id INTEGER PRIMARY KEY,
    decision_id INTEGER,
    action TEXT,
    result TEXT,
    feedback TEXT,
    timestamp TEXT,
    FOREIGN KEY (decision_id) REFERENCES decisions(id)
);
```

### 7.2 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| decision_name | TEXT | 决策名称 |
| direction | TEXT | 选择的方向 |
| score | REAL | 8 维评估总分 |
| confidence | TEXT | 置信度评估 |
| status | TEXT | 执行状态 |
| report_path | TEXT | 决策报告路径 |

## 8. 实施计划

### 8.1 阶段一：基础整合 (1-2 天)
- [ ] 创建两仪循环引擎主模块
- [ ] 实现阳端方向生成
- [ ] 实现阴端 8 维评估
- [ ] 连接 iOS Controller

### 8.2 阶段二：闭环验证 (2-3 天)
- [ ] 实现执行闭环
- [ ] 实现反馈获取
- [ ] 实现反馈分析
- [ ] 端到端测试

### 8.3 阶段三：增强优化 (3-5 天)
- [ ] 实现分级决策
- [ ] 实现断片恢复
- [ ] 实现决策数据库
- [ ] 性能优化

## 9. 风险与应对

| 风险 | 影响 | 应对 |
|------|------|------|
| SSH 隧道中断 | 高 | 自动重连 + 心跳检测 |
| iOS MCP 不可用 | 高 | 降级方案 + 缓存 |
| 决策偏差 | 中 | 反向验证 + 置信度评估 |
| 执行失败 | 中 | 重试机制 + 回滚 |

## 10. 验收标准

- [ ] 阳端能生成 5 个方向方案
- [ ] 阴端能进行 8 维评估
- [ ] 执行闭环能调用 iOS Controller
- [ ] 反馈机制能获取并分析截图
- [ ] 决策日志能持久化
- [ ] 断片恢复能在 5 分钟内完成
- [ ] 端到端测试通过

---
*方案创建时间: 2026-05-27 03:25:42*
*两仪循环引擎 v5.0 + 星核系统*
