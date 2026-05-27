"""
iOS 数据接入集成测试
=====================
测试 iOS MCP 数据接入 + 数据→八卦映射的完整流程。
"""

import sys
from pathlib import Path
from datetime import datetime

starcore_root = Path(__file__).parent.parent
sys.path.insert(0, str(starcore_root))

def test_ios_integration():
    """测试 iOS 数据接入集成"""
    
    print("=" * 70)
    print("📱 iOS 数据接入集成测试")
    print("=" * 70)
    
    results = {}
    
    # 测试 1：iOS 数据适配器
    print("\n📝 测试 1：iOS 数据适配器")
    try:
        from modules.ios_adapter.data_adapter import iOSDataAdapter, DataType, DataQuality, DeviceData, DataSnapshot
        
        adapter = iOSDataAdapter()
        
        # 检查连接
        connected = adapter.check_connection()
        print(f"   MCP 连接：{'✅ 已连接' if connected else '⚠️ 未连接（使用降级数据）'}")
        
        # 获取电池
        battery = adapter.get_battery_status()
        print(f"   电池：{battery.value.get('level', 'N/A')}% ({battery.quality.value})")
        
        # 获取内存
        memory = adapter.get_memory_status()
        print(f"   内存：{memory.value.get('usage_percent', 'N/A')}% ({memory.quality.value})")
        
        # 获取存储
        storage = adapter.get_storage_status()
        print(f"   存储：{storage.value.get('usage_percent', 'N/A')}% ({storage.quality.value})")
        
        # 获取网络
        network = adapter.get_network_status()
        print(f"   网络：{'连接' if network.value.get('connected') else '断开'} ({network.quality.value})")
        
        # 获取活动
        activity = adapter.get_activity_status()
        print(f"   活动：{activity.value.get('activity_level', 'N/A')} ({activity.quality.value})")
        
        # 获取完整快照
        snapshot = adapter.get_full_snapshot()
        print(f"   快照质量：{snapshot.quality_score}")
        
        results["ios_adapter"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败：{e}")
        results["ios_adapter"] = f"FAIL: {e}"
    
    # 测试 2：数据→八卦映射
    print("\n📝 测试 2：数据→八卦映射")
    try:
        from modules.mapper.data_bagua_mapper import DataBaguaMapper, BaguaMapping, SignalLevel
        
        mapper = DataBaguaMapper()
        
        # 处理电池数据
        battery_data = DeviceData(
            id="test", type=DataType.BATTERY,
            value={"level": 85, "charging": False, "health": 95},
            unit="percent", quality=DataQuality.EXCELLENT,
            timestamp=datetime.now().isoformat(), source="test"
        )
        signal = mapper.process_data(battery_data)
        print(f"   电池→乾：{signal.normalized_value} ({signal.signal_level.value})")
        
        # 处理内存数据
        memory_data = DeviceData(
            id="test", type=DataType.MEMORY,
            value={"used_bytes": 1500000000, "total_bytes": 3000000000, "usage_percent": 50.0},
            unit="bytes", quality=DataQuality.GOOD,
            timestamp=datetime.now().isoformat(), source="test"
        )
        signal = mapper.process_data(memory_data)
        print(f"   内存→坤：{signal.normalized_value} (反向)")
        
        # 处理网络数据
        network_data = DeviceData(
            id="test", type=DataType.NETWORK,
            value={"connected": True, "type": "wifi", "signal_strength": 80},
            unit="status", quality=DataQuality.EXCELLENT,
            timestamp=datetime.now().isoformat(), source="test"
        )
        signal = mapper.process_data(network_data)
        print(f"   网络→震：{signal.normalized_value} (二进制)")
        
        # 生成八卦状态
        snapshot = DataSnapshot(
            id="test", timestamp=datetime.now().isoformat(),
            battery={"level": 85},
            memory={"usage_percent": 50.0},
            storage={"usage_percent": 25.0},
            network={"connected": True},
            activity={"activity_level": 0.75},
            system={"platform": "iOS"},
            quality_score=0.85
        )
        state = mapper.process_snapshot(snapshot)
        print(f"   八卦状态：")
        print(f"     乾 (能量): {state.qian}")
        print(f"     坤 (存储): {state.kun}")
        print(f"     震 (事件): {state.zhen}")
        print(f"     巽 (数据): {state.xun}")
        print(f"     坎 (风险): {state.kan}")
        print(f"   主导卦：{state.dominant_gua}")
        
        results["mapper"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败：{e}")
        results["mapper"] = f"FAIL: {e}"
    
    # 测试 3：完整流程
    print("\n📝 测试 3：完整流程（适配器→映射器）")
    try:
        from modules.ios_adapter.data_adapter import iOSDataAdapter
        from modules.mapper.data_bagua_mapper import DataBaguaMapper
        
        adapter = iOSDataAdapter()
        mapper = DataBaguaMapper()
        mapper.set_adapter(adapter)
        
        # 获取快照并映射
        snapshot = adapter.get_full_snapshot()
        state = mapper.process_snapshot(snapshot)
        
        print(f"   快照质量：{snapshot.quality_score}")
        print(f"   主导卦：{state.dominant_gua}")
        print(f"   信号数：{len(mapper.get_current_signals())}")
        
        results["full_flow"] = "PASS"
    except Exception as e:
        print(f"   ❌ 失败：{e}")
        results["full_flow"] = f"FAIL: {e}"
    
    # 汇总
    print("\n" + "=" * 70)
    print("测试结果汇总")
    print("=" * 70)
    
    passed = sum(1 for v in results.values() if v == "PASS")
    total = len(results)
    
    for name, result in results.items():
        status = "✅" if result == "PASS" else "❌"
        print(f"   {status} {name.upper()}: {result}")
    
    print(f"\n总计：{passed}/{total} 通过")
    
    if passed == total:
        print("\n🎉 iOS 数据接入测试通过！")
    else:
        print(f"\n⚠️ 有 {total - passed} 个模块测试失败")
    
    return results


if __name__ == "__main__":
    test_ios_integration()
