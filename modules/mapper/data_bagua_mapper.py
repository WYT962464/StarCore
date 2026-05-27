"""
数据→八卦映射层 (Data-to-Bagua Mapper)
=========================================
将 iOS 设备数据映射到八卦模块，驱动演化系统。

映射规则：
- 电池电量 → 乾（决策能量）
- 内存使用 → 坤（存储压力）
- 网络状态 → 震（事件触发）
- 活动水平 → 巽（数据活跃）
- 存储使用 → 坎（风险预警）
- 系统温度 → 离（状态热度）
- 休眠状态 → 艮（休眠控制）
- 用户反馈 → 兑（反馈收集）
"""

import json
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum

# 导入数据适配器
try:
    from modules.ios_adapter.data_adapter import iOSDataAdapter, DataType, DeviceData, DataSnapshot, DataQuality
except ImportError:
    iOSDataAdapter = None
    DataType = None
    DeviceData = None
    DataSnapshot = None


class BaguaMapping(Enum):
    """八卦映射"""
    QIAN = "qian"      # 乾 - 电池/能量
    KUN = "kun"        # 坤 - 存储/压力
    ZHEN = "zhen"      # 震 - 网络/事件
    XUN = "xun"        # 巽 - 活动/数据
    KAN = "kan"        # 坎 - 存储风险
    LI = "li"          # 离 - 温度/热度
    GEN = "gen"        # 艮 - 休眠
    DUI = "dui"        # 兑 - 反馈


class SignalLevel(Enum):
    """信号级别"""
    STRONG = "strong"     # 强
    MODERATE = "moderate" # 中等
    WEAK = "weak"         # 弱
    NONE = "none"         # 无


@dataclass
class BaguaSignal:
    """八卦信号"""
    mapping: BaguaMapping
    source_type: DataType
    raw_value: Any
    normalized_value: float  # 0-1
    signal_level: SignalLevel
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class BaguaState:
    """八卦状态（基于数据）"""
    qian: float  # 乾 - 能量
    kun: float   # 坤 - 存储
    zhen: float  # 震 - 事件
    xun: float   # 巽 - 数据
    kan: float   # 坎 - 风险
    li: float    # 离 - 热度
    gen: float   # 艮 - 休眠
    dui: float   # 兑 - 反馈
    timestamp: str
    dominant_gua: str  # 主导卦


class DataBaguaMapper:
    """数据→八卦映射器"""
    
    # 映射配置
    MAPPING_CONFIG = {
        DataType.BATTERY: {
            "target": BaguaMapping.QIAN,
            "normalization": "direct",  # 直接映射
            "weight": 1.0
        },
        DataType.MEMORY: {
            "target": BaguaMapping.KUN,
            "normalization": "inverse",  # 反向映射（使用率越高，坤越弱）
            "weight": 1.0
        },
        DataType.NETWORK: {
            "target": BaguaMapping.ZHEN,
            "normalization": "binary",  # 二进制（连接=1，断开=0）
            "weight": 1.0
        },
        DataType.ACTIVITY: {
            "target": BaguaMapping.XUN,
            "normalization": "direct",
            "weight": 1.0
        },
        DataType.STORAGE: {
            "target": BaguaMapping.KAN,
            "normalization": "inverse",
            "weight": 1.0
        },
        DataType.TEMPERATURE: {
            "target": BaguaMapping.LI,
            "normalization": "scale",  # 温度映射到 0-1
            "weight": 1.0,
            "min_temp": 25,
            "max_temp": 45
        }
    }
    
    def __init__(self, name: str = "DATA_BAGUA_MAPPER"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/mapper")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.signal_log_path = self.base_path / "signals.jsonl"
        self.state_log_path = self.base_path / "states.jsonl"
        
        # 数据适配器
        self.adapter: Optional[iOSDataAdapter] = None
        
        # 当前信号
        self.current_signals: Dict[BaguaMapping, BaguaSignal] = {}
        self.signals_lock = threading.Lock()
        
        # 当前八卦状态
        self.current_state: Optional[BaguaState] = None
        self.state_lock = threading.Lock()
        
        # 信号历史
        self.signal_history: List[BaguaSignal] = []
        self.state_history: List[BaguaState] = []
        
        # 回调
        self.signal_callbacks: List[Callable] = []
        self.state_callbacks: List[Callable] = []
        
        # 统计
        self.signal_count = 0
        self.state_count = 0
    
    def set_adapter(self, adapter: iOSDataAdapter) -> None:
        """设置数据适配器"""
        self.adapter = adapter
        # 注册回调
        if adapter:
            adapter.register_snapshot_callback(self._on_snapshot)
    
    def register_signal_callback(self, callback: Callable) -> None:
        """注册信号回调"""
        self.signal_callbacks.append(callback)
    
    def register_state_callback(self, callback: Callable) -> None:
        """注册状态回调"""
        self.state_callbacks.append(callback)
    
    def process_data(self, data: DeviceData) -> Optional[BaguaSignal]:
        """
        处理单个数据，生成八卦信号
        
        Args:
            data: 设备数据
            
        Returns:
            八卦信号
        """
        config = self.MAPPING_CONFIG.get(data.type)
        if not config:
            return None
        
        target = config["target"]
        normalization = config["normalization"]
        weight = config.get("weight", 1.0)
        
        # 归一化
        normalized = self._normalize_value(data, normalization, config)
        
        # 确定信号级别
        signal_level = self._determine_signal_level(normalized)
        
        # 创建信号
        signal = BaguaSignal(
            mapping=target,
            source_type=data.type,
            raw_value=data.value,
            normalized_value=normalized,
            signal_level=signal_level,
            timestamp=datetime.now().isoformat(),
            metadata={"weight": weight, "quality": data.quality.value}
        )
        
        # 缓存
        with self.signals_lock:
            self.current_signals[target] = signal
            self.signal_history.append(signal)
            self.signal_count += 1
        
        self._log_signal(signal)
        self._notify_signal(signal)
        
        return signal
    
    def process_snapshot(self, snapshot: DataSnapshot) -> BaguaState:
        """
        处理完整快照，生成八卦状态
        
        Args:
            snapshot: 数据快照
            
        Returns:
            八卦状态
        """
        # 处理每个数据
        if snapshot.battery:
            self.process_data(DeviceData(
                id="temp", type=DataType.BATTERY, value=snapshot.battery,
                unit="percent", quality=DataQuality.GOOD, timestamp=snapshot.timestamp, source="snapshot"
            ))
        
        if snapshot.memory:
            self.process_data(DeviceData(
                id="temp", type=DataType.MEMORY, value=snapshot.memory,
                unit="bytes", quality=DataQuality.GOOD, timestamp=snapshot.timestamp, source="snapshot"
            ))
        
        if snapshot.storage:
            self.process_data(DeviceData(
                id="temp", type=DataType.STORAGE, value=snapshot.storage,
                unit="bytes", quality=DataQuality.GOOD, timestamp=snapshot.timestamp, source="snapshot"
            ))
        
        if snapshot.network:
            self.process_data(DeviceData(
                id="temp", type=DataType.NETWORK, value=snapshot.network,
                unit="status", quality=DataQuality.GOOD, timestamp=snapshot.timestamp, source="snapshot"
            ))
        
        if snapshot.activity:
            self.process_data(DeviceData(
                id="temp", type=DataType.ACTIVITY, value=snapshot.activity,
                unit="minutes", quality=DataQuality.GOOD, timestamp=snapshot.timestamp, source="snapshot"
            ))
        
        # 计算八卦状态
        with self.signals_lock:
            qian = self.current_signals.get(BaguaMapping.QIAN, BaguaSignal(BaguaMapping.QIAN, DataType.BATTERY, {}, 0, SignalLevel.NONE, "")).normalized_value
            kun = self.current_signals.get(BaguaMapping.KUN, BaguaSignal(BaguaMapping.KUN, DataType.MEMORY, {}, 0, SignalLevel.NONE, "")).normalized_value
            zhen = self.current_signals.get(BaguaMapping.ZHEN, BaguaSignal(BaguaMapping.ZHEN, DataType.NETWORK, {}, 0, SignalLevel.NONE, "")).normalized_value
            xun = self.current_signals.get(BaguaMapping.XUN, BaguaSignal(BaguaMapping.XUN, DataType.ACTIVITY, {}, 0, SignalLevel.NONE, "")).normalized_value
            kan = self.current_signals.get(BaguaMapping.KAN, BaguaSignal(BaguaMapping.KAN, DataType.STORAGE, {}, 0, SignalLevel.NONE, "")).normalized_value
            li = self.current_signals.get(BaguaMapping.LI, BaguaSignal(BaguaMapping.LI, DataType.TEMPERATURE, {}, 0, SignalLevel.NONE, "")).normalized_value
            gen = 0.5  # 休眠状态需单独获取
            dui = 0.5  # 反馈需单独获取
        
        # 确定主导卦
        values = {"qian": qian, "kun": kun, "zhen": zhen, "xun": xun, 
                  "kan": kan, "li": li, "gen": gen, "dui": dui}
        dominant = max(values, key=values.get)
        
        state = BaguaState(
            qian=round(qian, 3),
            kun=round(kun, 3),
            zhen=round(zhen, 3),
            xun=round(xun, 3),
            kan=round(kan, 3),
            li=round(li, 3),
            gen=round(gen, 3),
            dui=round(dui, 3),
            timestamp=datetime.now().isoformat(),
            dominant_gua=dominant
        )
        
        with self.state_lock:
            self.current_state = state
            self.state_history.append(state)
            self.state_count += 1
        
        self._log_state(state)
        self._notify_state(state)
        
        return state
    
    def get_current_state(self) -> Optional[BaguaState]:
        """获取当前八卦状态"""
        with self.state_lock:
            return self.current_state
    
    def get_current_signals(self) -> Dict[BaguaMapping, BaguaSignal]:
        """获取当前所有信号"""
        with self.signals_lock:
            return dict(self.current_signals)
    
    def get_dominant_gua(self) -> Optional[str]:
        """获取主导卦"""
        with self.state_lock:
            return self.current_state.dominant_gua if self.current_state else None
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计"""
        with self.signals_lock:
            with self.state_lock:
                return {
                    "name": self.name,
                    "signal_count": self.signal_count,
                    "state_count": self.state_count,
                    "current_signals": {k.value: v.normalized_value for k, v in self.current_signals.items()},
                    "current_state": asdict(self.current_state) if self.current_state else None,
                    "dominant_gua": self.current_state.dominant_gua if self.current_state else None
                }
    
    def _normalize_value(self, data: DeviceData, normalization: str, config: Dict) -> float:
        """归一化数据值到 0-1"""
        if normalization == "direct":
            # 直接映射（如电池电量）
            if isinstance(data.value, dict):
                return data.value.get("level", 0) / 100.0
            return min(1.0, max(0.0, float(data.value) / 100.0))
        
        elif normalization == "inverse":
            # 反向映射（如内存使用率，越低越好）
            if isinstance(data.value, dict):
                usage = data.value.get("usage_percent", 0) / 100.0
                return 1.0 - usage  # 反向
            return 1.0 - min(1.0, max(0.0, float(data.value)))
        
        elif normalization == "binary":
            # 二进制（如网络状态）
            if isinstance(data.value, dict):
                return 1.0 if data.value.get("connected", False) else 0.0
            return 1.0 if data.value else 0.0
        
        elif normalization == "scale":
            # 缩放映射（如温度）
            min_val = config.get("min_temp", 25)
            max_val = config.get("max_temp", 45)
            if isinstance(data.value, dict):
                temp = data.value.get("temperature", min_val)
            else:
                temp = float(data.value)
            
            if max_val > min_val:
                return (temp - min_val) / (max_val - min_val)
            return 0.5
        
        return 0.5
    
    def _determine_signal_level(self, normalized: float) -> SignalLevel:
        """确定信号级别"""
        if normalized >= 0.7:
            return SignalLevel.STRONG
        elif normalized >= 0.4:
            return SignalLevel.MODERATE
        elif normalized > 0:
            return SignalLevel.WEAK
        return SignalLevel.NONE
    
    def _on_snapshot(self, snapshot: DataSnapshot) -> None:
        """快照回调"""
        self.process_snapshot(snapshot)
    
    def _notify_signal(self, signal: BaguaSignal) -> None:
        """通知信号更新"""
        for callback in self.signal_callbacks:
            try:
                callback(signal)
            except:
                pass
    
    def _notify_state(self, state: BaguaState) -> None:
        """通知状态更新"""
        for callback in self.state_callbacks:
            try:
                callback(state)
            except:
                pass
    
    def _log_signal(self, signal: BaguaSignal) -> None:
        """记录信号日志"""
        with open(self.signal_log_path, "a") as f:
            f.write(json.dumps(asdict(signal), default=str, ensure_ascii=False) + "\n")
    
    def _log_state(self, state: BaguaState) -> None:
        """记录状态日志"""
        with open(self.state_log_path, "a") as f:
            f.write(json.dumps(asdict(state), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 70)
    print("📊 数据→八卦映射层 测试")
    print("=" * 70)
    
    mapper = DataBaguaMapper()
    
    # 测试 1：处理电池数据
    print("\n📝 测试 1：处理电池数据 → 乾")
    from modules.ios_adapter.data_adapter import DeviceData, DataType, DataQuality
    
    battery_data = DeviceData(
        id="test", type=DataType.BATTERY,
        value={"level": 85, "charging": False, "health": 95},
        unit="percent", quality=DataQuality.EXCELLENT,
        timestamp=datetime.now().isoformat(), source="test"
    )
    signal = mapper.process_data(battery_data)
    if signal:
        print(f"   信号：{signal.mapping.value}")
        print(f"   归一化：{signal.normalized_value}")
        print(f"   级别：{signal.signal_level.value}")
    
    # 测试 2：处理内存数据
    print("\n📝 测试 2：处理内存数据 → 坤")
    memory_data = DeviceData(
        id="test", type=DataType.MEMORY,
        value={"used_bytes": 1500000000, "total_bytes": 3000000000, "usage_percent": 50.0},
        unit="bytes", quality=DataQuality.GOOD,
        timestamp=datetime.now().isoformat(), source="test"
    )
    signal = mapper.process_data(memory_data)
    if signal:
        print(f"   信号：{signal.mapping.value}")
        print(f"   归一化：{signal.normalized_value} (反向)")
    
    # 测试 3：处理网络数据
    print("\n📝 测试 3：处理网络数据 → 震")
    network_data = DeviceData(
        id="test", type=DataType.NETWORK,
        value={"connected": True, "type": "wifi", "signal_strength": 80},
        unit="status", quality=DataQuality.EXCELLENT,
        timestamp=datetime.now().isoformat(), source="test"
    )
    signal = mapper.process_data(network_data)
    if signal:
        print(f"   信号：{signal.mapping.value}")
        print(f"   归一化：{signal.normalized_value} (二进制)")
    
    # 测试 4：生成八卦状态
    print("\n📝 测试 4：生成八卦状态")
    from modules.ios_adapter.data_adapter import DataSnapshot
    
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
    if state:
        print(f"   乾 (能量): {state.qian}")
        print(f"   坤 (存储): {state.kun}")
        print(f"   震 (事件): {state.zhen}")
        print(f"   巽 (数据): {state.xun}")
        print(f"   坎 (风险): {state.kan}")
        print(f"   主导卦：{state.dominant_gua}")
    
    # 测试 5：获取统计
    print("\n📝 测试 5：获取统计")
    stats = mapper.get_stats()
    print(f"   信号数：{stats['signal_count']}")
    print(f"   状态数：{stats['state_count']}")
    print(f"   主导卦：{stats['dominant_gua']}")
    
    print("\n✅ 数据→八卦映射层测试完成")
