#!/usr/bin/env python3
"""
星核系统 - 与融合引擎集成测试
演示五引力如何驱动星核决策
"""

import sys
sys.path.insert(0, "/home/ubuntu/starcore")

from starcore_integration import get_starcore_status, get_decision_context
from fusion_engine import FusionEngine  # 如果存在

print("=" * 70)
print("🔗 星核系统 - 融合引擎集成测试")
print("=" * 70)

# 1. 获取星核系统状态
print("\n📊 星核系统状态")
status = get_starcore_status()
print(f"   健康度: {status['overall']['health'].upper()}")
print(f"   五引力: {status['components']['five_gravities']['status']}")
print(f"   元规则: {status['components']['meta_rules']['status']}")

# 2. 获取决策上下文
print("\n🧠 决策上下文")
context = get_decision_context()

print(f"   主导引力: {context['motivation'].get('dominant_gravity', '无')}")
print(f"   总能量: {context['motivation'].get('total_energy', 0):.2f}")

if context['motivation'].get('recommendations'):
    print(f"   建议:")
    for rec in context['motivation']['recommendations']:
        print(f"      [{rec['priority']}] {rec['action']}")

# 3. 模拟融合引擎调用
print("\n🔄 模拟融合引擎调用")

# 模拟感知阶段
print("   [感知] 获取系统状态...")
print(f"          五引力总能量: {context['motivation']['total_energy']:.2f}")
print(f"          主导引力: {context['motivation']['dominant_gravity']}")

# 模拟决策阶段
print("   [决策] 基于五引力生成建议...")
if context['motivation'].get('recommendations'):
    top_rec = context['motivation']['recommendations'][0]
    print(f"          推荐行动: {top_rec['action']}")
    print(f"          优先级: {top_rec['priority']}")
    print(f"          原因: {top_rec['reason']}")
else:
    print("          无紧急建议")

# 模拟执行阶段
print("   [执行] 行动评估...")
from starcore_integration import evaluate_action

if context['motivation'].get('recommendations'):
    action = {
        "description": context['motivation']['recommendations'][0]['action'],
        "priority": context['motivation']['recommendations'][0]['priority']
    }
    result = evaluate_action(action)
    print(f"          元规则合规: {'✅' if result['meta_rules_compliant'] else '❌'}")
    print(f"          推荐: {result['recommendation']}")

# 4. 与 Hermes 对话桥接
print("\n📡 与 Hermes 对话桥接")
print("   星核决策可通过以下接口暴露给 Hermes:")
print("   ```python")
print("   from starcore_integration import get_decision_context")
print("   context = get_decision_context()")
print("   # context 包含: 主导引力、决策偏向、伦理约束、建议")
print("   ```")

# 5. 自循环示例
print("\n🔄 自循环示例（60 秒周期）")
print("   伪代码:")
print("   ```python")
print("   import time")
print("   from starcore_integration import get_decision_context, evaluate_action")
print("   ")
print("   while True:")
print("       # 感知")
print("       context = get_decision_context()")
print("       ")
print("       # 决策")
print("       if context['motivation']['recommendations']:")
print("           action = context['motivation']['recommendations'][0]")
print("           # 评估并执行")
print("           result = evaluate_action(action)")
print("           if result['recommendation'] == 'approve':")
print("               execute_action(action)")
print("       ")
print("       time.sleep(60)")
print("   ```")

print("\n" + "=" * 70)
print("✅ 集成测试完成")
print("=" * 70)
