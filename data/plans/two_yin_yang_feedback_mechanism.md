# 两仪循环引擎 v5.1 - 真实回传机制修正

## 一、问题诊断

### 1.1 当前架构缺陷

**问题**: 阴端真实回传通过"模拟用户在对话窗口发送消息"绕过循环步数限制

**风险**:
1. **破坏闭环完整性**: 循环步数限制是防止无限循环的安全机制
2. **违背自进化原则**: 依赖外部触发而非自主反馈
3. **决策质量下降**: 绕过限制可能导致决策疲劳和偏差累积

### 1.2 根本原因

```
错误架构:
阳端 → 阴端 → 执行 → [绕过限制] → 阳端 (虚假闭环)

正确架构:
阳端 → 阴端 → 执行 → 真实反馈 → 反馈学习 → 阳端 (真实闭环)
```

---

## 二、正确真实回传机制

### 2.1 核心原则

| 原则 | 说明 |
|------|------|
| **自主性** | 反馈必须来自系统自主执行结果，非外部模拟 |
| **真实性** | 反馈数据必须真实反映执行效果 |
| **可验证性** | 反馈必须可被验证和审计 |
| **闭环性** | 反馈必须能驱动下一轮决策 |

### 2.2 真实回传数据源

| 数据源 | 获取方式 | 用途 |
|--------|---------|------|
| 屏幕截图 | iOS MCP screenshot | 视觉验证执行效果 |
| 应用状态 | iOS MCP get_frontmost_app | 验证应用切换 |
| 设备状态 | iOS MCP get_screen_info | 系统健康检查 |
| 执行日志 | iOS Controller log | 执行过程追踪 |
| 决策数据库 | SQLite | 历史决策对比 |

### 2.3 真实回传流程

```
1. 执行指令 → iOS Controller
2. 等待执行完成 (poll 机制)
3. 获取多源反馈:
   - screenshot (视觉)
   - get_frontmost_app (应用状态)
   - get_screen_info (设备状态)
4. 反馈分析:
   - 视觉对比 (执行前后截图)
   - 状态验证 (预期 vs 实际)
   - 异常检测 (错误/警告)
5. 反馈学习:
   - 更新决策权重
   - 记录偏差模式
   - 优化评估矩阵
6. 驱动下一轮:
   - 反馈进入阳端上下文
   - 影响方向生成
```

---

## 三、循环步数限制机制

### 3.1 限制设计

| 参数 | 值 | 说明 |
|------|-----|------|
| max_cycles | 10 | 单轮决策最大循环次数 |
| cycle_timeout | 300s | 单循环最大执行时间 |
| feedback_threshold | 0.7 | 反馈质量阈值 |
| decay_rate | 0.1 | 决策权重衰减率 |

### 3.2 终止条件

```python
def should_terminate(cycle_count, feedback_quality, decision_confidence):
    # 条件 1: 达到最大循环次数
    if cycle_count >= max_cycles:
        return True, "达到最大循环次数"
    
    # 条件 2: 反馈质量过低
    if feedback_quality < feedback_threshold:
        return True, "反馈质量不足"
    
    # 条件 3: 决策置信度持续下降
    if decision_confidence < 0.5:
        return True, "决策置信度过低"
    
    # 条件 4: 连续相同决策
    if has_consecutive_same_decisions(3):
        return True, "连续相同决策，可能陷入局部最优"
    
    return False, "继续循环"
```

### 3.3 绕过限制的检测

```python
def detect_bypass_attempt(feedback_source, feedback_type):
    """检测是否试图绕过循环限制"""
    
    # 检测 1: 反馈来源异常
    if feedback_source not in ALLOWED_FEEDBACK_SOURCES:
        raise BypassDetectionError(f"非法反馈来源: {feedback_source}")
    
    # 检测 2: 反馈类型不匹配
    if feedback_type not in EXPECTED_FEEDBACK_TYPES:
        raise BypassDetectionError(f"非法反馈类型: {feedback_type}")
    
    # 检测 3: 反馈时间异常 (过快)
    if feedback_latency < MIN_FEEDBACK_LATENCY:
        raise BypassDetectionError("反馈时间异常，可能为模拟数据")
    
    return True
```

---

## 四、反馈学习机制

### 4.1 反馈权重更新

```python
def update_feedback_weights(feedback_result):
    """根据反馈结果更新评估权重"""
    
    if feedback_result["success"]:
        # 成功执行：增加相关方向权重
        for dim in feedback_result["positive_dimensions"]:
            weights[dim] += DECISION_BONUS
        
        # 减少偏差
        bias_correction *= (1 - BIAS_DECAY)
    else:
        # 执行失败：减少相关方向权重
        for dim in feedback_result["negative_dimensions"]:
            weights[dim] -= DECISION_PENALTY
        
        # 增加偏差检测
        bias_correction += BIAS_INCREASE
    
    # 记录学习历史
    learning_history.append({
        "timestamp": datetime.now(),
        "feedback": feedback_result,
        "weights": weights.copy()
    })
```

### 4.2 偏差溯源

```python
def trace_bias(decision, actual_outcome):
    """偏差溯源五步法"""
    
    steps = []
    
    # 1. 识别偏差
    deviation = calculate_deviation(decision.expected, actual_outcome)
    steps.append(f"偏差识别: {deviation}")
    
    # 2. 定位来源
    source = identify_bias_source(decision, actual_outcome)
    steps.append(f"来源定位: {source}")
    
    # 3. 分析原因
    cause = analyze_cause(source, decision.context)
    steps.append(f"原因分析: {cause}")
    
    # 4. 修正方案
    correction = generate_correction(cause)
    steps.append(f"修正方案: {correction}")
    
    # 5. 验证效果
    verification = verify_correction(correction)
    steps.append(f"验证效果: {verification}")
    
    return steps
```

---

## 五、安全机制

### 5.1 防绕过检测

| 检测项 | 方法 | 响应 |
|--------|------|------|
| 反馈来源 | 白名单验证 | 非法来源拒绝 |
| 反馈时间 | 延迟检测 | 异常快速拒绝 |
| 反馈内容 | 内容验证 | 不匹配拒绝 |
| 循环次数 | 计数器 | 超限终止 |
| 决策一致性 | 模式检测 | 异常一致告警 |

### 5.2 审计日志

```sql
CREATE TABLE feedback_audit (
    id INTEGER PRIMARY KEY,
    cycle_id INTEGER,
    feedback_source TEXT,
    feedback_type TEXT,
    feedback_latency REAL,
    is_validated BOOLEAN,
    bypass_detected BOOLEAN,
    timestamp TEXT
);
```

---

## 六、实施计划

### 阶段 1: 机制设计 (已完成)
- [x] 问题诊断
- [x] 正确架构设计
- [x] 安全机制设计

### 阶段 2: 代码实现
- [ ] 实现真实反馈获取模块
- [ ] 实现反馈分析模块
- [ ] 实现反馈学习模块
- [ ] 实现防绕过检测

### 阶段 3: 测试验证
- [ ] 单元测试
- [ ] 集成测试
- [ ] 绕过检测测试
- [ ] 端到端验证

---

*设计时间: 2026-05-27*
*两仪循环引擎 v5.1*
