#!/usr/bin/env python3
"""
测试自动阿腾校准机制
模拟迷茫场景，验证系统能否自动检测到并调用校准
"""

import sys
sys.path.insert(0, '/home/ubuntu/starcore')
import importlib.util
spec = importlib.util.spec_from_file_location("engine", "/home/ubuntu/starcore/two_yin_yang_engine_v5.3.py")
engine_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine_module)
TwoYinYangEngine = engine_module.TwoYinYangEngine
YangDirection = engine_module.YangDirection

def test_auto_calibration():
    """测试自动迷茫检测和校准"""
    engine = TwoYinYangEngine()
    
    print("=" * 60)
    print("测试：自动迷茫检测 + 阿腾校准")
    print("=" * 60)
    
    # 场景 1：方向同质化（5 个方向只有 2 种描述）
    print("\n📍 场景 1：方向同质化")
    engine2 = TwoYinYangEngine()
    # 手动注入同质化方向
    engine2._generate_yang_directions = lambda ctx: [
        YangDirection(f"方向{i+1}", "基于上下文的探索方向 1", 0.3) for i in range(5)
    ]
    result = engine2.process("分析项目")
    print(f"决策：{result['final_decision']}")
    cal = result.get('ateng_calibration')
    print(f"阿腾校准：{cal.get('校准建议', '无') if cal else '无'}")
    
    # 场景 2：置信度低（5 个方向都<0.4）
    print("\n📍 场景 2：置信度低")
    engine3 = TwoYinYangEngine()
    engine3._generate_yang_directions = lambda ctx: [
        YangDirection(f"方向{i+1}", f"探索方向{i+1}", 0.25) for i in range(5)
    ]
    result = engine3.process("分析项目")
    print(f"决策：{result['final_decision']}")
    cal = result.get('ateng_calibration')
    print(f"阿腾校准：{cal.get('校准建议', '无') if cal else '无'}")
    
    # 场景 3：循环停滞（连续 3 轮相同推荐，系统自循环）
    print("\n📍 场景 3：循环停滞（系统自循环）")
    engine4 = TwoYinYangEngine()
    # 模拟连续 3 轮相同决策（系统自循环，不重置计数器）
    for i in range(3):
        engine4.counter.system_cycle = i + 1
        engine4.history.append({
            "final_decision": "推荐方向 1",
            "timestamp": f"2026-05-27T0{i}:00:00",
            "input_source": "two_yin_yang",
            "hexagram": {"hexagram": "KUNQIAN"},
            "yang_directions": [],
            "yin_evaluation": {},
            "confidence": 0.5
        })
    # 模拟系统自循环输入（不是 user_input，不会重置计数器）
    engine4._generate_yang_directions = lambda ctx: [
        YangDirection(f"方向{i+1}", f"探索方向{i+1}", 0.6) for i in range(5)
    ]
    # 使用 [SYSTEM] 前缀模拟自循环，不会重置计数器
    result = engine4.process("[SYSTEM] 继续执行")
    print(f"决策：{result['final_decision']}")
    cal = result.get('ateng_calibration')
    print(f"阿腾校准：{cal.get('校准建议', '无') if cal else '无'}")
    
    # 场景 4：熵值异常（混乱）
    print("\n📍 场景 4：熵值异常（混乱）")
    engine5 = TwoYinYangEngine()
    engine5.hexagram_ctx.entropy = 0.75
    result = engine5.process("分析项目")
    print(f"决策：{result['final_decision']}")
    cal = result.get('ateng_calibration')
    print(f"阿腾校准：{cal.get('校准建议', '无') if cal else '无'}")
    
    # 场景 5：熵值异常（死锁）
    print("\n📍 场景 5：熵值异常（死锁）")
    engine6 = TwoYinYangEngine()
    engine6.hexagram_ctx.entropy = 0.1
    result = engine6.process("分析项目")
    print(f"决策：{result['final_decision']}")
    cal = result.get('ateng_calibration')
    print(f"阿腾校准：{cal.get('校准建议', '无') if cal else '无'}")
    
    print("\n" + "=" * 60)
    print("✅ 自动校准测试完成")
    print("关键改进：迷茫时不再等待用户指令，自己调用阿腾校准")
    print("=" * 60)

if __name__ == "__main__":
    test_auto_calibration()
