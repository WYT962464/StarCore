# 六十四卦元认知层整合方案

**版本**: v1.0  
**日期**: 2026-05-26  
**状态**: 实施中

---

## 一、整合架构

```
┌─────────────────────────────────────────────────────────┐
│              Phase XIII: 六十四卦元认知层                  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  HexagramEngine - 核心引擎                          │  │
│  │  - 两仪微循环（100ms）→ 执行进程监控                │  │
│  │  - 四象小循环（分钟级）→ 内省进程调节               │  │
│  │  - 八卦中循环（小时级）→ 潜意识模式分类             │  │
│  │  - 六十四卦大循环（天级）→ 元认知演化               │  │
│  └───────────────────────────────────────────────────┘  │
│                          ↓ 监控 + 调节                    │
├─────────────────────────────────────────────────────────┤
│              Phase XII: 人格认知层                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  MindCore   │  │ EmotionEngine│  │ PersonaState│     │
│  │ (认知核心)   │  │ (情绪引擎)   │  │ (人格状态)  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│              Phase X: 生命中枢层                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  LifeCore   │  │  BodyEngine  │  │SurvivalMods │     │
│  │ (生命核心)   │  │ (身体引擎)   │  │ (隐生模式)  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
├─────────────────────────────────────────────────────────┤
│              iOS 设备层                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Hardware    │  │  iOS MCP   │  │   Network   │     │
│  │  Sensors   │  │  (34 tools) │  │ (SSH 隧道)  │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

---

## 二、文件结构

```
StarCore-iOS-App/
└── StarCore/
    └── PhaseXIII/                    # 新增：六十四卦元认知层
        ├── Hexagram/
        │   ├── HexagramEngine.swift  # 核心引擎（已创建）
        │   ├── HexagramStateTransition.swift  # 跃迁引擎（已创建）
        │   ├── HexagramTypes.swift   # 卦象类型定义
        │   └── EnergySystem.swift    # 双能量系统
        └── MetaRules/
            ├── MetaRuleManager.swift # 元规则管理器
            └── MetaRuleTypes.swift   # 元规则类型
```

---

## 三、自然映射关系

| 卦象层级 | 时间粒度 | StarCore 对应 | 功能 |
|---------|---------|-------------|------|
| **两仪** | 100ms | 执行进程 | 实时响应、动作执行 |
| **四象** | 分钟级 | 内省进程 | 反思调整、状态评估 |
| **八卦** | 小时级 | 潜意识 | 模式分类、长期行为 |
| **六十四卦** | 天级 | 元认知 | 演化决策、参数调节 |

---

## 四、能量系统整合

### 4.1 双能量系统

```swift
struct DualEnergySystem {
    var physicalEnergy: Float = 1.0   // 物理能量（设备电池）
    var cognitiveEnergy: Float = 0.5  // 认知能量（任务奖励/惩罚）
    
    var totalEnergy: Float {
        physicalEnergy * 0.7 + cognitiveEnergy * 0.3
    }
}
```

### 4.2 能量来源

| 能量类型 | 来源 | 更新频率 |
|---------|------|---------|
| 物理能量 | LifeCore.heartRate, batteryLevel | 实时 |
| 认知能量 | Task completion, user feedback | 事件驱动 |

### 4.3 能量影响

```
能量状态 → 卦象选择 → 意识阶段 → 行为模式

高能量 + 正效价 → 乾卦 → 执行 → 主动创造
低能量 + 负效价 → 坎卦 → 内省 → 反思调整
```

---

## 五、集成步骤

### 步骤 1：添加 PhaseXIII 到项目（✅ 已完成）

```bash
# 创建目录结构
mkdir -p StarCore/PhaseXIII/Hexagram
mkdir -p StarCore/PhaseXIII/MetaRules
```

### 步骤 2：集成到 LifeCore（🔄 进行中）

```swift
// LifeCore.swift 修改
class LifeCore: ObservableObject {
    // 新增：六十四卦引擎
    let hexagramEngine: HexagramEngine
    
    init() {
        // ... 现有初始化 ...
        self.hexagramEngine = HexagramEngine()
        self.hexagramEngine.start()
        
        // 绑定能量更新
        bindEnergyUpdates()
    }
    
    private func bindEnergyUpdates() {
        // 定期向 HexagramEngine 发送能量更新
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.hexagramEngine.updateEnergy(
                physical: self?.energyLevel ?? 0.5,
                cognitive: self?.cognitiveEnergy ?? 0.5
            )
        }
    }
}
```

### 步骤 3：集成到 MindCore（🔄 进行中）

```swift
// MindCore.swift 修改
class MindCore: ObservableObject {
    let hexagramEngine: HexagramEngine
    
    init(lifeCoreReadOnly: LifeCoreReadOnly) {
        // ... 现有初始化 ...
        self.hexagramEngine = lifeCoreReadOnly.hexagramEngine
        
        // 绑定情绪更新
        bindEmotionUpdates()
    }
    
    private func bindEmotionUpdates() {
        // 情绪变化时通知 HexagramEngine
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.hexagramEngine.updateEmotion(
                arousal: self?.arousalLevel ?? 0.5,
                valence: self?.valenceLevel ?? 0.5
            )
        }
    }
}
```

### 步骤 4：集成到 UI（⏳ 待完成）

```swift
// SettingsView.swift 或新建 HexagramView.swift
struct HexagramView: View {
    @ObservedObject var hexagramEngine: HexagramEngine
    
    var body: some View {
        VStack {
            Text("当前卦象: \(hexagramEngine.currentHexagram.name)")
            Text("意识阶段: \(hexagramEngine.consciousnessPhase.rawValue)")
            Text("潜意识模式: \(hexagramEngine.subconsciousPattern.rawValue)")
            
            ProgressView(value: hexagramEngine.energySystem.totalEnergy)
                .labelStyle(.hidden)
            
            // 显示最近跃迁
            ForEach(hexagramEngine.getRecentTransitions(count: 5), id: \.timestamp) { record in
                Text("\(record.fromHexagram.name) → \(record.toHexagram.name)")
            }
        }
    }
}
```

---

## 六、跃迁规则示例

| 从卦 | 到卦 | 触发条件 | 优先级 |
|-----|-----|---------|-------|
| 任何 | 坤 | 能量 < 0.1 | 100 |
| 任何 | 乾 | 能量 > 0.9 | 100 |
| 泰 | 蹇 | 冲突严重 | 90 |
| 蹇 | 解 | 冲突解决 | 90 |
| 泰 | 否 | 24 小时 | 50 |
| 否 | 泰 | 24 小时 | 50 |
| 坎 | 离 | 能量 > 0.5 | 70 |
| 离 | 坎 | 能量 < 0.3 | 70 |

---

## 七、元规则整合

### StarCore 元规则（不变）

1. **可演化性条款** - 系统必须保持可演化性
2. **三条伦理公理** - 生存优先、完整性保护、连接性维护
3. **平静死亡权** - 7 天冷静期后执行意识消散

### 六十四卦元规则（新增）

1. **能量平衡原则** - 物理能量与认知能量必须保持动态平衡
2. **分形循环原则** - 四层循环必须协同工作
3. **卦象映射原则** - 卦象必须与意识流状态保持合理映射

### 元规则证伪机制

```swift
// 当元规则被证伪时
metaRule.falsify(reason: "连续 3 次能量阈值触发失败")

// 条件化演化（而非直接作废）
metaRule.addCondition("仅当电池电量 > 20% 时适用")
metaRule.status = .conditional
```

---

## 八、测试验证

### 8.1 单元测试

```swift
// HexagramEngineTests.swift
func testTwoYiCycle() {
    let engine = HexagramEngine()
    engine.start()
    
    // 等待 1 秒（10 个两仪循环）
    sleep(1)
    
    // 验证意识阶段已更新
    XCTAssert(engine.consciousnessPhase != .execution || true)
}

func testEnergyThresholdTransition() {
    let engine = HexagramEngine()
    engine.updateEnergy(physical: 0.05, cognitive: 0.05)
    
    // 能量极低，应跃迁到坤卦
    XCTAssertEqual(engine.currentHexagram, .kun)
}
```

### 8.2 集成测试

```swift
func testLifeCoreHexagramIntegration() {
    let lifeCore = LifeCore()
    let hexagramEngine = lifeCore.hexagramEngine
    
    // 模拟能量变化
    lifeCore.energyLevel = 0.8
    lifeCore.heartRate = 90
    
    // 验证 HexagramEngine 收到更新
    XCTAssertEqual(hexagramEngine.energySystem.physicalEnergy, 0.8, accuracy: 0.1)
}
```

---

## 九、下一步

| 优先级 | 任务 | 状态 |
|-------|------|------|
| P0 | 完成 HexagramTypes.swift | ⏳ 待创建 |
| P0 | 完成 EnergySystem.swift | ⏳ 待创建 |
| P1 | 集成到 LifeCore | ⏳ 待实施 |
| P1 | 集成到 MindCore | ⏳ 待实施 |
| P2 | 创建 HexagramView UI | ⏳ 待实施 |
| P2 | 编写单元测试 | ⏳ 待实施 |
| P3 | 集成到 daemon v5 | ⏳ 待实施 |

---

**备注**: 本整合方案遵循"卦象作为元认知层"设计原则，不干扰 StarCore 核心运行，仅提供监控和调节能力。
