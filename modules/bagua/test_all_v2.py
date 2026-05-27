"""
八卦模块集成测试 v2
====================
测试所有八卦模块 + 四象 + 两仪 + 太极的完整集成。
"""

import sys
from pathlib import Path

# 添加 starcore 根目录到路径
starcore_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(starcore_root))

def test_all_modules():
    """测试所有八卦模块"""
    
    print("=" * 60)
    print("☰ 八卦模块集成测试 v2")
    print("=" * 60)
    
    results = {}
    
    # 测试 1-8：八卦模块
    print("\n📝 测试 1-8：八卦核心模块")
    
    # 乾
    try:
        from modules.bagua.qian.decision_engine import DecisionEngine
        engine = DecisionEngine()
        decision = engine.decide({"priority": 5, "context": "test"})
        print(f"   ✅ QIAN (乾): 决策引擎")
        results["qian"] = "PASS"
    except Exception as e:
        print(f"   ❌ QIAN (乾): {e}")
        results["qian"] = f"FAIL: {e}"
    
    # 坤
    try:
        from modules.bagua.kun.storage_system import StorageSystem
        storage = StorageSystem()
        entry_id = storage.store("test", {"data": "test_value"})
        retrieved = storage.retrieve(entry_id)
        print(f"   ✅ KUN (坤): 存储系统")
        results["kun"] = "PASS"
    except Exception as e:
        print(f"   ❌ KUN (坤): {e}")
        results["kun"] = f"FAIL: {e}"
    
    # 震
    try:
        from modules.bagua.zhen.event_trigger import EventTrigger, EventType
        trigger = EventTrigger()
        event = trigger.detect_event(EventType.SYSTEM, "test", {"key": "value"})
        print(f"   ✅ ZHEN (震): 事件触发器")
        results["zhen"] = "PASS"
    except Exception as e:
        print(f"   ❌ ZHEN (震): {e}")
        results["zhen"] = f"FAIL: {e}"
    
    # 巽
    try:
        from modules.bagua.xun.data_collector import DataCollector, DataSource
        collector = DataCollector()
        data = collector.collect(DataSource.SYSTEM, "test", {"key": "value"})
        print(f"   ✅ XUN (巽): 数据采集器")
        results["xun"] = "PASS"
    except Exception as e:
        print(f"   ❌ XUN (巽): {e}")
        results["xun"] = f"FAIL: {e}"
    
    # 坎
    try:
        from modules.bagua.kan.error_handler import ErrorHandler, ErrorLevel, ErrorCategory
        handler = ErrorHandler()
        error = handler.record_error(
            level=ErrorLevel.ERROR,
            category=ErrorCategory.PROCESSING,
            message="测试错误",
            source="test"
        )
        print(f"   ✅ KAN (坎): 异常处理器")
        results["kan"] = "PASS"
    except Exception as e:
        print(f"   ❌ KAN (坎): {e}")
        results["kan"] = f"FAIL: {e}"
    
    # 离
    try:
        from modules.bagua.li.state_renderer import StateRenderer, RenderFormat, StateCategory
        renderer = StateRenderer()
        output = renderer.render({"test": "data"}, RenderFormat.TEXT, StateCategory.SYSTEM)
        print(f"   ✅ LI (离): 状态渲染器")
        results["li"] = "PASS"
    except Exception as e:
        print(f"   ❌ LI (离): {e}")
        results["li"] = f"FAIL: {e}"
    
    # 艮
    try:
        from modules.bagua.gen.hibernate_controller import HibernateController, SystemState, HibernateReason
        controller = HibernateController()
        current = controller.get_state()
        controller.hibernate(HibernateReason.MANUAL)
        after = controller.get_state()
        controller.wake()
        print(f"   ✅ GEN (艮): 休眠控制器")
        results["gen"] = "PASS"
    except Exception as e:
        print(f"   ❌ GEN (艮): {e}")
        results["gen"] = f"FAIL: {e}"
    
    # 兑
    try:
        from modules.bagua.dui.feedback_transmitter import FeedbackTransmitter, FeedbackType, FeedbackSource
        transmitter = FeedbackTransmitter()
        record = transmitter.submit_feedback(
            content="测试反馈",
            feedback_type=FeedbackType.NEUTRAL,
            source=FeedbackSource.USER
        )
        print(f"   ✅ DUI (兑): 反馈回传器")
        results["dui"] = "PASS"
    except Exception as e:
        print(f"   ❌ DUI (兑): {e}")
        results["dui"] = f"FAIL: {e}"
    
    # 测试 9：四象状态管理器
    print("\n📝 测试 9：四象状态管理器 (SIXIANG)")
    try:
        from modules.bagua.sixiang.state_manager import FourSymbolManager, FourSymbol
        manager = FourSymbolManager()
        state = manager.get_current_state()
        print(f"   ✅ 初始状态：{state.symbol.value}")
        
        # 完整流转
        for _ in range(4):
            manager.auto_transition()
        
        stats = manager.get_stats()
        print(f"   ✅ 流转次数：{stats['total_transitions']}")
        print(f"   ✅ 循环次数：{stats['total_cycles']}")
        results["sixiang"] = "PASS"
    except Exception as e:
        print(f"   ❌ SIXIANG (四象): {e}")
        results["sixiang"] = f"FAIL: {e}"
    
    # 测试 10：两仪切换机制
    print("\n📝 测试 10：两仪切换机制 (LIANGYI)")
    try:
        from modules.bagua.liangyi.switcher import LiangyiSwitcher, Liangyi
        switcher = LiangyiSwitcher()
        current = switcher.get_current_liangyi()
        print(f"   ✅ 初始两仪：{current.value}")
        
        # 切换测试
        switcher.switch("测试")
        switcher.switch("测试")
        
        stats = switcher.get_stats()
        print(f"   ✅ 切换次数：{stats['total_transitions']}")
        print(f"   ✅ 循环次数：{stats['total_cycles']}")
        results["liangyi"] = "PASS"
    except Exception as e:
        print(f"   ❌ LIANGYI (两仪): {e}")
        results["liangyi"] = f"FAIL: {e}"
    
    # 测试 11：太极演化引擎
    print("\n📝 测试 11：太极演化引擎 (TAIJI)")
    try:
        from modules.bagua.taiji.engine import TaijiEngine, TaijiPhase
        engine = TaijiEngine()
        phase = engine.get_current_phase()
        print(f"   ✅ 初始阶段：{phase.value}")
        
        # 完整演化循环
        for _ in range(6):
            engine.evolve()
        
        stats = engine.get_stats()
        print(f"   ✅ 演化次数：{stats['total_evolutions']}")
        print(f"   ✅ 完整循环：{stats['full_cycles']}")
        print(f"   ✅ 当前阶段：{stats['current_phase']}")
        results["taiji"] = "PASS"
    except Exception as e:
        print(f"   ❌ TAIJI (太极): {e}")
        results["taiji"] = f"FAIL: {e}"
    
    # 汇总
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)
    
    passed = sum(1 for v in results.values() if v == "PASS")
    total = len(results)
    
    for name, result in results.items():
        status = "✅" if result == "PASS" else "❌"
        print(f"   {status} {name.upper()}: {result}")
    
    print(f"\n总计：{passed}/{total} 通过")
    
    if passed == total:
        print("\n🎉 所有模块测试通过！")
    else:
        print(f"\n⚠️ 有 {total - passed} 个模块测试失败")
    
    return results


if __name__ == "__main__":
    test_all_modules()
