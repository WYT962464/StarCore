# 两仪循环引擎 v5.2 - 循环步数限制修复

## 一、问题诊断

### 1.1 当前缺陷

**问题**: 真实执行结果通过**模拟用户输入**来回传，突破循环步数限制

**机制**:
```
执行 → 获取真实结果 → 模拟用户发送消息 → 系统认为是新触发 → 触发下一轮
                                                              ↓
                                                    循环计数器重置 ❌
```

**风险**:
1. **限制失效**: 循环步数限制形同虚设
2. **无限循环**: 系统可能陷入无限自循环
3. **决策疲劳**: 连续循环导致决策质量下降
4. **资源耗尽**: 持续自循环消耗系统资源

### 1.2 根本原因

| 原因 | 说明 |
|------|------|
| 输入源无法区分 | 系统无法区分"真实用户输入"和"系统自注入" |
| 计数器重置逻辑 | 收到"新消息"时重置循环计数器 |
| 缺乏内部状态 | 循环状态未持久化，重启后丢失 |

---

## 二、正确架构设计

### 2.1 核心原则

| 原则 | 说明 |
|------|------|
| **输入源标记** | 所有输入必须标记来源（user/system） |
| **计数器持久化** | 循环计数器必须持久化，重启不丢失 |
| **来源隔离** | 系统自循环不重置计数器，用户输入可重置 |
| **强制终止** | 达到上限必须终止，不可绕过 |

### 2.2 正确流程

```
┌─────────────────────────────────────────────────────────────┐
│                    两仪循环引擎 v5.2                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              输入源标记层                              │   │
│  │  ┌─────────────┐    ┌─────────────┐                 │   │
│  │  │  用户输入   │    │ 系统自循环  │                 │   │
│  │  │  source=user│    │source=system│                 │   │
│  │  └──────┬──────┘    └──────┬──────┘                 │   │
│  └─────────┼──────────────────┼────────────────────────┘   │
│            │                  │                              │
│            ▼                  ▼                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              循环计数器管理                            │   │
│  │  ┌─────────────────────────────────────────────────┐ │   │
│  │  │  source=user → 重置计数器 (新任务)               │ │   │
│  │  │  source=system → 递增计数器 (自循环)             │ │   │
│  │  │  counter >= max → 强制终止                       │ │   │
│  │  └─────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              阳端 → 阴端 → 执行 → 反馈                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 输入源标记（前缀分类机制）

#### 2.3.1 前缀分类规则

**核心设计**：通过消息前缀区分输入来源，用户指令天然无前缀，直接识别为真实用户输入。

| 输入源 | 前缀标记 | 识别方式 | 计数器行为 | 示例 |
|--------|---------|---------|-----------|------|
| **user** | **无前缀** | 自然语言，无特殊标记 | 重置计数器（新任务） | "帮我截图看看现在什么界面" |
| **system** | `[SYSTEM]` | 系统内部反馈回传 | 递增计数器（自循环） | `[SYSTEM] 执行完成：截图已获取，分析结果：用户正在使用微信` |
| **external** | `[MCP]` 或 `[DEVICE]` | 外部工具/API返回 | 保持计数器（不重置不递增） | `[MCP] {"tool": "screenshot", "status": "success"}` |

#### 2.3.2 分类逻辑实现

```python
def classify_input(message: str) -> InputSource:
    """
    根据消息前缀分类输入来源
    
    规则：
    - 无前缀 → user（真实用户输入）
    - [SYSTEM] 前缀 → system（系统自循环反馈）
    - [MCP]/[DEVICE] 前缀 → external（外部工具返回）
    """
    if message.startswith("[SYSTEM]"):
        return InputSource.SYSTEM
    elif message.startswith("[MCP]") or message.startswith("[DEVICE]"):
        return InputSource.EXTERNAL
    else:
        # 无前缀 = 真实用户输入
        return InputSource.USER

def process_input(message: str) -> Tuple[InputSource, bool, str]:
    """
    处理输入消息，返回 (输入源, 是否继续, 原因)
    """
    source = classify_input(message)
    
    if source == InputSource.USER:
        # 用户输入：重置计数器（新任务开始）
        counter.reset()
        return source, True, "用户输入，重置计数器"
    
    elif source == InputSource.SYSTEM:
        # 系统反馈：递增计数器（自循环）
        counter.increment()
        if counter.value >= counter.max_cycles:
            return source, False, f"达到最大循环次数 ({counter.value}/{counter.max_cycles})"
        return source, True, f"系统反馈，计数器={counter.value}"
    
    else:  # EXTERNAL
        # 外部触发：保持计数器状态
        return source, True, f"外部触发，计数器={counter.value}"
```

#### 2.3.3 为什么用前缀而不是其他方法

| 方法 | 优点 | 缺点 | 选择 |
|------|------|------|------|
| **前缀标记** | 简单直观，用户指令天然无前缀，无需额外配置 | 需要确保系统输出强制加前缀 | ✅ 推荐 |
| 消息 ID 追踪 | 精确追踪每条消息来源 | 需要维护 ID 映射表，复杂 | ❌ 不推荐 |
| 通道分离 | 不同来源走不同 API 端点 | 需要多套 API，架构复杂 | ❌ 不推荐 |
| 元数据字段 | 在消息结构中添加 source 字段 | 需要修改消息协议 | ⚠️ 备选 |

**前缀方案的优势**：
1. **用户无感知**：用户正常说话不需要加任何标记
2. **系统强制**：系统内部输出必须加 `[SYSTEM]` 前缀，否则视为非法
3. **易于调试**：日志中直接看到前缀，快速定位来源
4. **协议兼容**：不改变现有消息格式，只需在发送端加前缀

---

### 2.4 输入源标记（数据结构）

```python
class InputSource(Enum):
    USER = "user"        # 真实用户输入
    SYSTEM = "system"    # 系统自循环
    EXTERNAL = "external"  # 外部触发（API、定时器等）

class InputMessage:
    def __init__(self, content: str, source: InputSource, metadata: Dict = None):
        self.content = content
        self.source = source
        self.metadata = metadata or {}
        self.timestamp = datetime.now()
```

### 2.5 循环计数器管理

```python
class CycleCounter:
    def __init__(self, db_path: str):
        self.db_path = db_path
        self.max_cycles = 10
        self._load_state()
    
    def _load_state(self):
        """从数据库加载计数器状态"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS cycle_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                counter INTEGER DEFAULT 0,
                last_reset TEXT,
                max_cycles INTEGER DEFAULT 10
            )
        """)
        cursor.execute("SELECT counter, last_reset, max_cycles FROM cycle_state WHERE id = 1")
        row = cursor.fetchone()
        if row:
            self.counter = row[0]
            self.last_reset = row[1]
            self.max_cycles = row[2]
        else:
            self.counter = 0
            self.last_reset = datetime.now().isoformat()
            cursor.execute("""
                INSERT INTO cycle_state (id, counter, last_reset, max_cycles)
                VALUES (1, 0, ?, 10)
            """, (self.last_reset,))
        conn.commit()
        conn.close()
    
    def _save_state(self):
        """持久化计数器状态"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE cycle_state 
            SET counter = ?, last_reset = ? 
            WHERE id = 1
        """, (self.counter, self.last_reset))
        conn.commit()
        conn.close()
    
    def process_input(self, source: InputSource) -> Tuple[bool, str]:
        """
        处理输入，返回 (是否继续, 原因)
        
        - source=user: 重置计数器（新任务）
        - source=system: 递增计数器（自循环）
        - counter >= max: 强制终止
        """
        if source == InputSource.USER:
            # 用户输入：重置计数器
            self.counter = 0
            self.last_reset = datetime.now().isoformat()
            self._save_state()
            return True, "用户输入，重置计数器"
        
        elif source == InputSource.SYSTEM:
            # 系统自循环：递增计数器
            self.counter += 1
            self._save_state()
            
            if self.counter >= self.max_cycles:
                return False, f"达到最大循环次数 ({self.counter}/{self.max_cycles})"
            
            return True, f"系统自循环，计数器={self.counter}"
        
        else:
            # 外部触发：不重置也不递增（保持当前状态）
            return True, f"外部触发，计数器={self.counter}"
    
    def get_state(self) -> Dict:
        """获取当前状态"""
        return {
            "counter": self.counter,
            "max_cycles": self.max_cycles,
            "last_reset": self.last_reset,
            "remaining": max(0, self.max_cycles - self.counter)
        }
```

### 2.6 强制终止机制

```python
class CycleEnforcer:
    """循环强制终止器"""
    
    def __init__(self, counter: CycleCounter):
        self.counter = counter
        self.termination_log = []
    
    def check(self, source: InputSource) -> Tuple[bool, str]:
        """检查是否应该终止"""
        should_continue, reason = self.counter.process_input(source)
        
        if not should_continue:
            self._log_termination(reason)
        
        return should_continue, reason
    
    def _log_termination(self, reason: str):
        """记录终止日志"""
        self.termination_log.append({
            "timestamp": datetime.now().isoformat(),
            "reason": reason,
            "counter": self.counter.counter
        })
    
    def force_reset(self, reason: str = "手动重置"):
        """强制重置（仅允许管理员或特定条件）"""
        self.counter.counter = 0
        self.counter.last_reset = datetime.now().isoformat()
        self.counter._save_state()
        self._log_termination(f"强制重置: {reason}")
```

---

## 三、反馈回传机制

### 3.1 前缀回传规范

**反馈直接在系统内部流转，不通过"模拟用户消息"注入**

```python
def run_cycle(self, source: InputSource = InputSource.SYSTEM) -> Dict:
    """运行一个循环"""
    
    # 1. 检查循环限制
    should_continue, reason = self.enforcer.check(source)
    if not should_continue:
        return {
            "status": "terminated",
            "reason": reason,
            "counter": self.counter.counter
        }
    
    # 2. 执行决策循环
    # ... (阳端 → 阴端 → 执行 → 反馈)
    
    # 3. 反馈在内部流转，不模拟用户消息
    self.feedback_context = feedback
    
    # 4. 返回结果，由外部决定是否继续
    return {
        "status": "completed",
        "counter": self.counter.counter,
        "next_cycle": self.counter.counter < self.counter.max_cycles
    }
```

### 3.2 前缀使用规范

**系统输出必须加前缀的场合**：

| 场合 | 前缀 | 示例 |
|------|------|------|
| 执行结果回传 | `[SYSTEM]` | `[SYSTEM] 任务完成：已截图并分析` |
| MCP 工具返回 | `[MCP]` | `[MCP] {"tool": "screenshot", "result": "..."} ` |
| 设备状态上报 | `[DEVICE]` | `[DEVICE] {"battery": 100, "app": "WeChat"} ` |
| 自主决策输出 | `[SYSTEM]` | `[SYSTEM] 决策：建议执行 Phase 3 立框架` |

**禁止的行为**：

```python
# ❌ 错误：不加前缀的系统输出（会被误认为用户输入）
send_message(f"执行完成：{result}")  # ❌ 无前缀，计数器会重置

# ✅ 正确：加前缀的系统输出
send_message(f"[SYSTEM] 执行完成：{result}")  # ✅ 正确，计数器递增
```

### 3.3 正确做法

### 3.4 禁止的做法
def incorrect_feedback_loop(self, result):
    # 将执行结果模拟为用户消息发送
    self.send_user_message(f"执行结果：{result}")  # ❌ 绕过限制
    # 系统收到"新消息"，计数器重置
```

### 3.5 正确做法
def correct_feedback_loop(self, result):
    # 反馈直接进入内部上下文
    self.feedback_context = parse_result(result)
    # 计数器正常递增，不重置
```

---

## 四、审计与监控

### 4.1 前缀审计日志

```sql
CREATE TABLE cycle_audit (
    id INTEGER PRIMARY KEY,
    cycle_id INTEGER,
    input_source TEXT,  -- 'user' | 'system' | 'external'
    counter_before INTEGER,
    counter_after INTEGER,
    action TEXT,  -- 'increment' | 'reset' | 'terminate'
    reason TEXT,
    timestamp TEXT
);
```

### 4.2 前缀验证查询

| 指标 | 说明 |
|------|------|
| `cycle_counter` | 当前循环次数 |
| `cycle_max_reached` | 是否达到上限 |
| `user_input_count` | 用户输入次数 |
| `system_cycle_count` | 系统自循环次数 |
| `termination_count` | 强制终止次数 |

### 4.3 监控指标

## 五、实施计划

### 阶段 1: 核心修复 (已完成)
- [x] 输入源标记机制
- [x] 循环计数器持久化
- [x] 来源隔离逻辑
- [x] 强制终止机制

### 阶段 2: 代码实现
- [ ] 实现 CycleCounter 类
- [ ] 实现 CycleEnforcer 类
- [ ] 修改引擎主循环
- [ ] 添加审计日志

### 阶段 3: 测试验证
- [ ] 单元测试：计数器递增
- [ ] 单元测试：用户输入重置
- [ ] 单元测试：达到上限终止
- [ ] 集成测试：完整循环流程
- [ ] 绕过检测测试

---

## 六、关键区别总结

### 6.1 前缀区分 vs 无区分

| 对比项 | 无区分（错误） | 前缀区分（正确） |
|--------|---------------|-----------------|
| 用户输入识别 | 无法区分 | 无前缀 = user |
| 系统反馈识别 | 被误认为用户输入 | `[SYSTEM]` = system |
| 计数器行为 | 每次重置 | user 重置，system 递增 |
| 循环限制 | 可绕过 | 强制终止 |

### 6.2 关键区别总结

| 错误做法 | 正确做法 |
|---------|---------|
| 模拟用户消息注入 | **内部反馈流转** |
| 计数器重置 | **计数器递增** |
| 无法区分输入源 | **输入源标记** |
| 限制可绕过 | **强制终止** |
| 状态不持久化 | **状态持久化** |

---

*设计时间: 2026-05-27*
*两仪循环引擎 v5.2*
