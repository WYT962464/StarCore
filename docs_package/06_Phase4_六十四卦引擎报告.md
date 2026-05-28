# Phase 4: 六十四卦自循环演化系统

## 完成状态
✅ **Phase 4 核心引擎已实现并测试通过**

## 核心架构

### 1. 阴阳爻二进制映射
| 爻象 | 二进制 | 状态含义 |
|------|--------|----------|
| 阴爻 ⚋ | 0 | 静默、存储、休眠、低算力 |
| 阳爻 ⚊ | 1 | 活跃、运算、输出、高算力 |

### 2. 六十四卦状态集合
- 64 个卦象，每个卦象 6 爻（6 位二进制）
- 核心卦象已定义：乾、坤、屯、蒙、泰、否、既济、未济等
- 卦象解释库：自然语言解读

### 3. 六环节闭环
```
收集（取象）→ 存储（藏卦）→ 处理（演卦）→ 输出（释卦）→ 执行（行卦）→ 获取（反馈）
```

### 4. 自循环演化
- 定时触发（默认 60 秒）
- 数据驱动演化
- 版本快照
- 演化等级：0→1→2→4→8→64

## 核心模块

### GuaState - 卦态类
```python
GuaState(number=1)              # 创建卦态
gua.binary                      # 二进制表示
gua.yin_count                   # 阴爻数量
gua.yang_count                  # 阳爻数量
gua.change_yao(position, value) # 爻变
```

### GuaEngine - 推演引擎
```python
engine.cycle(input_data)        # 执行六环节闭环
engine.get_current_gua()        # 获取当前卦态
engine.set_gua(number)          # 手动设置卦态
engine.get_status()             # 获取引擎状态
```

### SelfCycleEngine - 自循环引擎
```python
cycle.start()                   # 启动自循环
cycle.stop()                    # 停止自循环
cycle.run_once()                # 运行单轮
cycle.get_status()              # 获取状态
```

## 数据文件

| 文件 | 说明 |
|------|------|
| `data/gua/current_gua.json` | 当前卦态 |
| `data/gua/gua_history.jsonl` | 卦变历史 |
| `data/gua/six_cycle_log.jsonl` | 六环节日志 |

## 测试输出

```
🔮 1. 当前卦态
   卦象: QIAN(1)
   二进制: 000000
   阴阳比: 0.00 (阳:0/阴:6)

🔄 2. 运行六环节闭环
   周期 ID: 1
   新卦象: KUN(2)
   爻变:
      位置 6: yin → yang
      位置 5: yin → yang
      位置 4: yin → yang
      位置 3: yin → yang

🔀 3. 测试爻变
   初始: QIAN(1) 000000
   初爻变阴: QIAN(1) 000000 (QIAN)

⏱️ 4. 自循环测试（单轮）
   完成: 2
```

## 下一步

**Phase 5: 六十四卦与融合引擎集成**

- 将六十四卦引擎集成到融合引擎
- 卦态作为决策输入源
- 六环节闭环作为执行框架
- 卦变触发条件与系统状态绑定

---
*Phase 4 完成时间: 2026-05-27*
