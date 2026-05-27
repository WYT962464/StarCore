"""
完整体系集成测试
=================
测试无极→太极→两仪→四象→八卦→万物的完整闭环系统。
"""

import sys
from pathlib import Path

starcore_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(starcore_root))

def test_complete_system():
    """测试完整体系"""
    
    print("=" * 70)
    print("☯ 完整体系集成测试")
    print("=" * 70)
    
    results = {}
    
    # 测试 1-8：八卦模块
    print("\n📝 测试 1-8：八卦核心模块")
    
    modules = [
        ("qian", "乾决策引擎"),
        ("kun", "坤存储系统"),
        ("zhen", "震事件触发器"),
        ("xun", "巽数据采集器"),
        ("kan", "坎异常处理器"),
        ("li", "离状态渲染器"),
        ("gen", "艮休眠控制器"),
        ("dui", "兑反馈回传器")
    ]
    
    for name, desc in modules:
        try:
            if name == "qian":
                from modules.bagua.qian.decision_engine import DecisionEngine
                e = DecisionEngine()
                d = e.decide({"test": True})
            elif name == "kun":
                from modules.bagua.kun.storage_system import StorageSystem
                s = StorageSystem()
                s.store("test", {"x": 1})
            elif name == "zhen":
                from modules.bagua.zhen.event_trigger import EventTrigger, EventType
                t = EventTrigger()
                t.detect_event(EventType.SYSTEM, "test", {})
            elif name == "xun":
                from modules.bagua.xun.data_collector import DataCollector, DataSource
                c = DataCollector()
                c.collect(DataSource.SYSTEM, "test", {})
            elif name == "kan":
                from modules.bagua.kan.error_handler import ErrorHandler, ErrorLevel, ErrorCategory
                h = ErrorHandler()
                h.record_error(ErrorLevel.ERROR, ErrorCategory.PROCESSING, "test", "test")
            elif name == "li":
                from modules.bagua.li.state_renderer import StateRenderer, RenderFormat, StateCategory
                r = StateRenderer()
                r.render({"x": 1}, RenderFormat.TEXT, StateCategory.SYSTEM)
            elif name == "gen":
                from modules.bagua.gen.hibernate_controller import HibernateController, HibernateReason
                c = HibernateController()
                c.hibernate(HibernateReason.MANUAL)
                c.wake()
            elif name == "dui":
                from modules.bagua.dui.feedback_transmitter import FeedbackTransmitter, FeedbackType, FeedbackSource
                t = FeedbackTransmitter()
                t.submit_feedback("test", FeedbackType.NEUTRAL, FeedbackSource.USER)
            
            print(f"   ✅ {name.upper()} ({desc})")
            results[name] = "PASS"
        except Exception as e:
            print(f"   ❌ {name.upper()} ({desc}): {e}")
            results[name] = f"FAIL: {e}"
    
    # 测试 9：四象
    print("\n📝 测试 9：四象状态管理器")
    try:
        from modules.bagua.sixiang.state_manager import FourSymbolManager
        m = FourSymbolManager()
        m.auto_transition()
        m.auto_transition()
        m.auto_transition()
        m.auto_transition()
        stats = m.get_stats()
        assert stats["total_cycles"] >= 1
        print(f"   ✅ 流转 {stats['total_transitions']} 次，循环 {stats['total_cycles']} 次")
        results["sixiang"] = "PASS"
    except Exception as e:
        print(f"   ❌ SIXIANG: {e}")
        results["sixiang"] = f"FAIL: {e}"
    
    # 测试 10：两仪
    print("\n📝 测试 10：两仪切换机制")
    try:
        from modules.bagua.liangyi.switcher import LiangyiSwitcher
        s = LiangyiSwitcher()
        s.switch()
        s.switch()
        stats = s.get_stats()
        assert stats["total_cycles"] >= 1
        print(f"   ✅ 切换 {stats['total_transitions']} 次，循环 {stats['total_cycles']} 次")
        results["liangyi"] = "PASS"
    except Exception as e:
        print(f"   ❌ LIANGYI: {e}")
        results["liangyi"] = f"FAIL: {e}"
    
    # 测试 11：太极
    print("\n📝 测试 11：太极演化引擎")
    try:
        from modules.bagua.taiji.engine import TaijiEngine
        e = TaijiEngine()
        for _ in range(6):
            e.evolve()
        stats = e.get_stats()
        assert stats["full_cycles"] >= 1
        print(f"   ✅ 演化 {stats['total_evolutions']} 次，循环 {stats['full_cycles']} 次")
        results["taiji"] = "PASS"
    except Exception as e:
        print(f"   ❌ TAIJI: {e}")
        results["taiji"] = f"FAIL: {e}"
    
    # 测试 12：无极
    print("\n📝 测试 12：无极层核心")
    try:
        from modules.bagua.wuji.core import WujiCore
        w = WujiCore()
        w.add_potential(0.1, source="test")
        w.complete_cycle(1)
        stats = w.get_potential_stats()
        print(f"   ✅ 潜能 {stats['total_potential']}, 速度 {stats['evolution_speed']}, 循环 {stats['cycle_count']}")
        results["wuji"] = "PASS"
    except Exception as e:
        print(f"   ❌ WUJI: {e}")
        results["wuji"] = f"FAIL: {e}"
    
    # 测试 13：六环节闭环执行器
    print("\n📝 测试 13：六环节闭环执行器")
    try:
        from modules.bagua.sixcycle.executor import SixCycleExecutor
        exec = SixCycleExecutor()
        init = exec.initialize()
        
        if init["success"]:
            result = exec.execute_full_cycle()
            print(f"   ✅ 循环 {result.cycle_number}, 时长 {result.total_duration:.2f}s, 成功 {result.success}")
            print(f"   ✅ 潜能 {result.wuji_potential_before} → {result.wuji_potential_after}")
            results["sixcycle"] = "PASS"
        else:
            print(f"   ⚠️ 初始化部分失败：{init['modules']}")
            results["sixcycle"] = "PARTIAL"
    except Exception as e:
        print(f"   ❌ SIXCYCLE: {e}")
        results["sixcycle"] = f"FAIL: {e}"
    
    # 汇总
    print("\n" + "=" * 70)
    print("测试结果汇总")
    print("=" * 70)
    
    passed = sum(1 for v in results.values() if v == "PASS")
    partial = sum(1 for v in results.values() if v == "PARTIAL")
    total = len(results)
    
    for name, result in results.items():
        if result == "PASS":
            status = "✅"
        elif result == "PARTIAL":
            status = "⚠️"
        else:
            status = "❌"
        print(f"   {status} {name.upper()}: {result}")
    
    print(f"\n总计：{passed}/{total} 通过，{partial} 部分通过")
    
    if passed == total:
        print("\n🎉 完整体系测试通过！")
    elif passed + partial == total:
        print("\n✅ 完整体系基本通过！")
    else:
        print(f"\n⚠️ 有 {total - passed - partial} 个模块测试失败")
    
    return results


if __name__ == "__main__":
    test_complete_system()
