"""
八卦模块集成测试
=================
测试所有八卦核心模块的加载和基本功能。
"""

import sys
from pathlib import Path

# 添加 starcore 根目录到路径
starcore_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(starcore_root))

def test_all_modules():
    """测试所有八卦模块"""
    
    print("=" * 60)
    print("☰ 八卦模块集成测试")
    print("=" * 60)
    
    results = {}
    
    # 测试 1：乾决策引擎
    print("\n📝 测试 1：乾决策引擎 (QIAN)")
    try:
        from modules.bagua.qian.decision_engine import DecisionEngine
        engine = DecisionEngine()
        decision = engine.decide({"priority": 5, "context": "test"})
        print(f"   ✅ 加载成功")
        print(f"   决策内容: {decision.get('content', 'N/A')[:50]}...")
        results["qian"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["qian"] = f"FAIL: {e}"
    
    # 测试 2：坤存储系统
    print("\n📝 测试 2：坤存储系统 (KUN)")
    try:
        from modules.bagua.kun.storage_system import StorageSystem
        storage = StorageSystem()
        entry_id = storage.store("test", {"data": "test_value"})
        retrieved = storage.retrieve(entry_id)
        print(f"   ✅ 加载成功")
        print(f"   存储测试: {'成功' if retrieved else '失败'}")
        results["kun"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["kun"] = f"FAIL: {e}"
    
    # 测试 3：震事件触发器
    print("\n📝 测试 3：震事件触发器 (ZHEN)")
    try:
        from modules.bagua.zhen.event_trigger import EventTrigger, EventType
        trigger = EventTrigger()
        event = trigger.detect_event(EventType.SYSTEM, "test", {"key": "value"})
        print(f"   ✅ 加载成功")
        print(f"   事件 ID: {event.id}")
        results["zhen"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["zhen"] = f"FAIL: {e}"
    
    # 测试 4：巽数据采集器
    print("\n📝 测试 4：巽数据采集器 (XUN)")
    try:
        from modules.bagua.xun.data_collector import DataCollector, DataSource
        collector = DataCollector()
        data = collector.collect(DataSource.SYSTEM, "test", {"key": "value"})
        print(f"   ✅ 加载成功")
        print(f"   采集数据量: {len(data.items) if hasattr(data, 'items') else 'N/A'}")
        results["xun"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["xun"] = f"FAIL: {e}"
    
    # 测试 5：坎异常处理器
    print("\n📝 测试 5：坎异常处理器 (KAN)")
    try:
        from modules.bagua.kan.error_handler import ErrorHandler, ErrorLevel, ErrorCategory
        handler = ErrorHandler()
        error = handler.record_error(
            level=ErrorLevel.ERROR,
            category=ErrorCategory.PROCESSING,
            message="测试错误",
            source="test"
        )
        print(f"   ✅ 加载成功")
        print(f"   错误 ID: {error.id}")
        results["kan"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["kan"] = f"FAIL: {e}"
    
    # 测试 6：离状态渲染器
    print("\n📝 测试 6：离状态渲染器 (LI)")
    try:
        from modules.bagua.li.state_renderer import StateRenderer, RenderFormat, StateCategory
        renderer = StateRenderer()
        output = renderer.render({"test": "data"}, RenderFormat.TEXT, StateCategory.SYSTEM)
        print(f"   ✅ 加载成功")
        print(f"   渲染内容长度: {len(output.content)}")
        results["li"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["li"] = f"FAIL: {e}"
    
    # 测试 7：艮休眠控制器
    print("\n📝 测试 7：艮休眠控制器 (GEN)")
    try:
        from modules.bagua.gen.hibernate_controller import HibernateController, SystemState, HibernateReason
        controller = HibernateController()
        current = controller.get_state()
        controller.hibernate(HibernateReason.MANUAL)
        after = controller.get_state()
        controller.wake()
        print(f"   ✅ 加载成功")
        print(f"   状态转换: {current.value} → {after.value} → {controller.get_state().value}")
        results["gen"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["gen"] = f"FAIL: {e}"
    
    # 测试 8：兑反馈回传器
    print("\n📝 测试 8：兑反馈回传器 (DUI)")
    try:
        from modules.bagua.dui.feedback_transmitter import FeedbackTransmitter, FeedbackType, FeedbackSource
        transmitter = FeedbackTransmitter()
        record = transmitter.submit_feedback(
            content="测试反馈",
            feedback_type=FeedbackType.NEUTRAL,
            source=FeedbackSource.USER
        )
        print(f"   ✅ 加载成功")
        print(f"   反馈 ID: {record.id}")
        results["dui"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败: {e}")
        results["dui"] = f"FAIL: {e}"
    
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
        print("\n🎉 所有八卦模块测试通过！")
    else:
        print(f"\n⚠️ 有 {total - passed} 个模块测试失败")
    
    return results


if __name__ == "__main__":
    test_all_modules()
