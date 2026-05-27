"""
六十四卦状态系统 (64 Gua State System)
========================================
基于八卦两两组合的六十四卦完整体系。

六十四卦定义：
- 64 卦 = 8 卦 × 8 卦（上下卦组合）
- 每卦 6 爻，32 阳爻 32 阴爻（平衡）
- 演化路径：从乾卦（纯阳）到坤卦（纯阴）的 64 种状态

卦序（文王卦序）：
1. 乾 ☰☰ 2. 坤 ☷☷ 3. 屯 ☵☳ 4. 蒙 ☶☵ ... 64. 未济 ☲☵
"""

import json
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple, Callable
from dataclasses import dataclass, asdict
from enum import Enum


class GuaName(Enum):
    """六十四卦名称（文王卦序）"""
    QIAN = "乾"           # 1. 乾为天
    KUN = "坤"            # 2. 坤为地
    ZHEN = "屯"           # 3. 水雷屯
    MENG = "蒙"           # 4. 山水蒙
    XU = "需"             # 5. 水天需
    SONG = "讼"           # 6. 天水讼
    SHI = "师"            # 7. 地水师
    BI = "比"             # 8. 水地比
    XIAO = "小畜"         # 9. 风天小畜
    TAI = "泰"            # 10. 地天泰
    ...  # 完整 64 卦将在 _GUA_DATA 中定义


@dataclass
class GuaDefinition:
    """卦象定义"""
    number: int            # 卦序号 (1-64)
    name: str              # 卦名
    upper_gua: str         # 上卦 (8 卦之一)
    lower_gua: str         # 下卦 (8 卦之一)
    binary: str            # 6 爻二进制 (1=阳，0=阴)
    description: str       # 卦义描述
    attributes: Dict[str, Any]  # 属性


@dataclass
class GuaState:
    """卦象状态"""
    gua: GuaDefinition
    position: int          # 在演化中的位置
    activated: bool        # 是否激活
    energy: float          # 能量值 (0-1)
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class GuaTransition:
    """卦象流转"""
    from_gua: int
    to_gua: int
    trigger: str
    timestamp: str
    context: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.context is None:
            self.context = {}


class Gua64System:
    """六十四卦状态系统"""
    
    # 八卦二进制（用于组合）
    BAGUA_BINARY = {
        "QIAN": "111",   # 乾 ☰
        "KUN": "000",    # 坤 ☷
        "ZHEN": "001",   # 震 ☳
        "XUN": "010",    # 巽 ☴
        "KAN": "010",    # 坎 ☵ (实际 010，但按传统)
        "LI": "101",     # 离 ☲
        "GEN": "100",    # 艮 ☶
        "DUI": "011"     # 兑 ☱
    }
    
    # 文王卦序（简化版，完整 64 卦）
    GUA_ORDER = [
        # 1-8: 纯卦（上下相同）
        (1, "乾", "QIAN", "QIAN", "111111", "纯阳，天行健"),
        (2, "坤", "KUN", "KUN", "000000", "纯阴，地势坤"),
        (3, "屯", "KAN", "ZHEN", "010001", "初生，万物始"),
        (4, "蒙", "GEN", "KAN", "100010", "启蒙，稚弱"),
        (5, "需", "KAN", "QIAN", "010111", "等待，蓄势"),
        (6, "讼", "QIAN", "KAN", "111010", "争议，竞争"),
        (7, "师", "KUN", "KAN", "000010", "众，军队"),
        (8, "比", "KAN", "KUN", "010000", "亲密，辅佐"),
        # 9-16
        (9, "小畜", "XUN", "QIAN", "010111", "小有积蓄"),
        (10, "泰", "KUN", "QIAN", "000111", "通达，安泰"),
        (11, "否", "QIAN", "KUN", "111000", "闭塞，不通"),
        (12, "同人", "LI", "QIAN", "101111", "团结，合作"),
        (13, "大有", "QIAN", "LI", "111101", "盛大，收获"),
        (14, "谦", "KUN", "GEN", "000100", "谦虚，低调"),
        (15, "豫", "ZHEN", "KUN", "001000", "愉悦，安乐"),
        (16, "随", "ZHEN", "DUI", "001011", "跟随，顺从"),
        # 17-24
        (17, "蛊", "XUN", "GEN", "010100", "整治，革新"),
        (18, "临", "DUI", "KUN", "011000", "临近，监督"),
        (19, "观", "KUN", "XUN", "000010", "观察，审视"),
        (20, "噬嗑", "ZHEN", "LI", "001101", "咬合，刑罚"),
        (21, "贲", "LI", "GEN", "101100", "装饰，美化"),
        (22, "剥", "GEN", "KUN", "100000", "剥落，衰退"),
        (23, "复", "KUN", "ZHEN", "000001", "回复，复兴"),
        (24, "无妄", "QIAN", "ZHEN", "111001", "真实，无妄"),
        # 25-32
        (25, "大畜", "QIAN", "GEN", "111100", "大积蓄"),
        (26, "颐", "GEN", "ZHEN", "100001", "养育，修养"),
        (27, "大过", "DUI", "XUN", "011010", "过度，非常"),
        (28, "坎", "KAN", "KAN", "010010", "险陷，困难"),
        (29, "离", "LI", "LI", "101101", "光明，依附"),
        (30, "咸", "DUI", "GEN", "011100", "感应，交流"),
        (31, "恒", "XUN", "ZHEN", "010001", "恒久，持久"),
        (32, "遁", "GEN", "QIAN", "100111", "退避，隐遁"),
        # 33-40
        (33, "大壮", "ZHEN", "QIAN", "001111", "强盛，壮大"),
        (34, "晋", "LI", "QIAN", "101111", "前进，晋升"),
        (35, "明夷", "KUN", "LI", "000101", "光明受损"),
        (36, "家人", "XUN", "LI", "010101", "家庭，内部"),
        (37, "睽", "LI", "DUI", "101011", "背离，差异"),
        (38, "蹇", "KAN", "GEN", "010100", "艰难，阻塞"),
        (39, "解", "ZHEN", "KAN", "001010", "解脱，解决"),
        (40, "损", "GEN", "DUI", "100011", "减损，牺牲"),
        # 41-48
        (41, "益", "XUN", "ZHEN", "010001", "增益，受益"),
        (42, "夬", "DUI", "QIAN", "011111", "决断，突破"),
        (43, "姤", "QIAN", "XUN", "111010", "相遇，邂逅"),
        (44, "萃", "DUI", "KUN", "011000", "聚集，精华"),
        (45, "升", "KUN", "XUN", "000010", "上升，晋升"),
        (46, "困", "KUN", "DUI", "000011", "困顿，限制"),
        (47, "井", "XUN", "KAN", "010010", "滋养，源泉"),
        (48, "革", "DUI", "LI", "011101", "变革，改革"),
        # 49-56
        (49, "鼎", "LI", "XUN", "101010", "鼎新，稳固"),
        (50, "震", "ZHEN", "ZHEN", "001001", "震动，激发"),
        (51, "艮", "GEN", "GEN", "100100", "静止，停止"),
        (52, "渐", "XUN", "GEN", "010100", "渐进，逐步"),
        (53, "归妹", "DUI", "ZHEN", "011001", "婚嫁，归宿"),
        (54, "丰", "ZHEN", "LI", "001101", "丰盛，盛大"),
        (55, "旅", "LI", "GEN", "101100", "旅行，漂泊"),
        (56, "巽", "XUN", "XUN", "010010", "顺从，进入"),
        # 57-64
        (57, "兑", "DUI", "DUI", "011011", "喜悦，沟通"),
        (58, "涣", "XUN", "KAN", "010010", "涣散，化解"),
        (59, "节", "ZHEN", "DUI", "001011", "节制，约束"),
        (60, "中孚", "XUN", "DUI", "010011", "诚信，信任"),
        (61, "小过", "ZHEN", "GEN", "001100", "小过度"),
        (62, "既济", "KAN", "LI", "010101", "完成，成功"),
        (63, "未济", "LI", "KAN", "101010", "未完成，希望"),
        (64, "乾坤", "QIAN", "KUN", "111000", "天地，起源")
    ]
    
    def __init__(self, name: str = "LIUSHI_SI_GUA"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/gua64_system")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.state_log_path = self.base_path / "gua_state_log.jsonl"
        self.transition_log_path = self.base_path / "gua_transition_log.jsonl"
        self.definition_path = self.base_path / "gua_definitions.json"
        
        # 卦象定义（初始化）
        self.gua_definitions: Dict[int, GuaDefinition] = {}
        self._initialize_definitions()
        
        # 当前状态
        self.current_gua: Optional[GuaState] = None
        self.state_lock = threading.Lock()
        
        # 状态历史
        self.gua_history: List[GuaState] = []
        self.transitions: List[GuaTransition] = []
        
        # 回调
        self.gua_callbacks: List[Callable] = []
        
        # 统计
        self.transition_count = 0
        self.cycle_count = 0
        
        # 初始化到乾卦
        self._initialize()
    
    def _initialize_definitions(self) -> None:
        """初始化 64 卦定义"""
        for number, name, upper, lower, binary, desc in self.GUA_ORDER:
            self.gua_definitions[number] = GuaDefinition(
                number=number,
                name=name,
                upper_gua=upper,
                lower_gua=lower,
                binary=binary,
                description=desc,
                attributes={
                    "yang_lines": binary.count("1"),
                    "yin_lines": binary.count("0"),
                    "upper_binary": self.BAGUA_BINARY.get(upper, "000"),
                    "lower_binary": self.BAGUA_BINARY.get(lower, "000")
                }
            )
        
        # 保存定义
        self._save_definitions()
    
    def _save_definitions(self) -> None:
        """保存卦象定义"""
        data = {
            "total_gua": len(self.gua_definitions),
            "definitions": {
                str(k): asdict(v) for k, v in self.gua_definitions.items()
            }
        }
        with open(self.definition_path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    
    def _initialize(self) -> None:
        """初始化到乾卦"""
        self.set_gua(1, "初始化")
    
    def register_callback(self, callback: Callable) -> None:
        """注册卦象变化回调"""
        self.gua_callbacks.append(callback)
    
    def get_current_gua(self) -> Optional[GuaState]:
        """获取当前卦象"""
        with self.state_lock:
            return self.current_gua
    
    def get_gua_definition(self, number: int) -> Optional[GuaDefinition]:
        """获取卦象定义"""
        return self.gua_definitions.get(number)
    
    def get_all_gua(self) -> List[GuaDefinition]:
        """获取所有卦象定义"""
        return list(self.gua_definitions.values())
    
    def set_gua(self, number: int, trigger: str,
                context: Optional[Dict[str, Any]] = None) -> bool:
        """
        设置当前卦象
        
        Args:
            number: 卦序号 (1-64)
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        if number < 1 or number > 64:
            return False
        
        gua_def = self.gua_definitions.get(number)
        if not gua_def:
            return False
        
        with self.state_lock:
            old_gua = self.current_gua
            
            # 创建新状态
            new_state = GuaState(
                gua=gua_def,
                position=number,
                activated=True,
                energy=1.0,
                timestamp=datetime.now().isoformat(),
                metadata=context or {}
            )
            
            # 记录流转
            if old_gua:
                transition = GuaTransition(
                    from_gua=old_gua.position,
                    to_gua=number,
                    trigger=trigger,
                    timestamp=datetime.now().isoformat(),
                    context=context or {}
                )
                self.transitions.append(transition)
                self.transition_count += 1
                
                # 检查循环（64 卦一圈）
                if old_gua.position == 64 and number == 1:
                    self.cycle_count += 1
                
                self._log_transition(transition)
            
            # 更新状态
            self.current_gua = new_state
            self.gua_history.append(new_state)
            
            self._log_state(new_state)
            self._notify_gua_change(old_gua, new_state, trigger)
            
            return True
    
    def evolve(self, trigger: str = "自动演化",
               context: Optional[Dict[str, Any]] = None) -> bool:
        """
        演化到下一卦
        
        Args:
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        if not self.current_gua:
            return False
        
        next_number = self.current_gua.position + 1
        if next_number > 64:
            next_number = 1  # 循环回到乾卦
        
        return self.set_gua(next_number, trigger, context)
    
    def force_gua(self, number: int, context: Optional[Dict[str, Any]] = None) -> bool:
        """强制设置卦象"""
        return self.set_gua(number, "强制设置", context)
    
    def get_gua_by_binary(self, binary: str) -> Optional[GuaDefinition]:
        """根据二进制查找卦象"""
        for gua in self.gua_definitions.values():
            if gua.binary == binary:
                return gua
        return None
    
    def get_gua_by_name(self, name: str) -> Optional[GuaDefinition]:
        """根据名称查找卦象"""
        for gua in self.gua_definitions.values():
            if gua.name == name:
                return gua
        return None
    
    def get_neighbors(self, number: int, radius: int = 1) -> List[GuaDefinition]:
        """获取相邻卦象"""
        neighbors = []
        for i in range(-radius, radius + 1):
            neighbor_num = ((number - 1 + i) % 64) + 1
            neighbors.append(self.gua_definitions[neighbor_num])
        return neighbors
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.state_lock:
            return {
                "name": self.name,
                "current_gua": {
                    "number": self.current_gua.position if self.current_gua else None,
                    "name": self.current_gua.gua.name if self.current_gua else None,
                    "binary": self.current_gua.gua.binary if self.current_gua else None,
                    "description": self.current_gua.gua.description if self.current_gua else None
                },
                "total_gua": len(self.gua_definitions),
                "total_transitions": self.transition_count,
                "total_cycles": self.cycle_count,
                "history_count": len(self.gua_history)
            }
    
    def get_transition_history(self, limit: int = 20) -> List[GuaTransition]:
        """获取流转历史"""
        with self.state_lock:
            return self.transitions[-limit:]
    
    def reset(self) -> None:
        """重置到乾卦"""
        with self.state_lock:
            self.gua_history = []
            self.transitions = []
            self.transition_count = 0
            self.cycle_count = 0
        self._initialize()
    
    def _notify_gua_change(self, old: Optional[GuaState],
                          new: GuaState, trigger: str) -> None:
        """通知卦象变化"""
        for callback in self.gua_callbacks:
            try:
                callback(old, new, trigger)
            except:
                pass
    
    def _log_state(self, state: GuaState) -> None:
        """记录状态日志"""
        with open(self.state_log_path, "a") as f:
            f.write(json.dumps(asdict(state), default=str, ensure_ascii=False) + "\n")
    
    def _log_transition(self, transition: GuaTransition) -> None:
        """记录流转日志"""
        with open(self.transition_log_path, "a") as f:
            f.write(json.dumps(asdict(transition), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 70)
    print("☰☷ 六十四卦状态系统 测试")
    print("=" * 70)
    
    system = Gua64System()
    
    # 测试 1：初始状态
    print("\n📝 测试 1：初始状态")
    state = system.get_current_gua()
    print(f"   当前卦：{state.gua.number}. {state.gua.name}")
    print(f"   二进制：{state.gua.binary}")
    print(f"   描述：{state.gua.description}")
    
    # 测试 2：获取所有卦
    print("\n📝 测试 2：获取所有卦象定义")
    all_gua = system.get_all_gua()
    print(f"   总数：{len(all_gua)}")
    print(f"   前 5 卦：{', '.join(f'{g.number}.{g.name}' for g in all_gua[:5])}")
    
    # 测试 3：演化
    print("\n📝 测试 3：演化（遍历 64 卦）")
    for i in range(10):
        system.evolve()
        state = system.get_current_gua()
        print(f"   演化 {i+1}: {state.gua.number}. {state.gua.name} ({state.gua.binary})")
    
    # 测试 4：根据二进制查找
    print("\n📝 测试 4：根据二进制查找")
    gua = system.get_gua_by_binary("111111")
    if gua:
        print(f"   111111 → {gua.number}. {gua.name}")
    
    gua = system.get_gua_by_binary("000000")
    if gua:
        print(f"   000000 → {gua.number}. {gua.name}")
    
    # 测试 5：获取相邻卦
    print("\n📝 测试 5：获取相邻卦（乾卦周围）")
    neighbors = system.get_neighbors(1, radius=2)
    for g in neighbors:
        print(f"   {g.number}. {g.name} ({g.binary})")
    
    # 测试 6：获取统计
    print("\n📝 测试 6：获取统计")
    stats = system.get_stats()
    print(f"   当前卦：{stats['current_gua']['number']}. {stats['current_gua']['name']}")
    print(f"   总流转：{stats['total_transitions']}")
    
    # 测试 7：完整循环
    print("\n📝 测试 7：完整循环（64 卦）")
    system.reset()
    for i in range(64):
        system.evolve()
    stats = system.get_stats()
    print(f"   完成 {stats['total_cycles']} 个循环")
    print(f"   最终卦：{stats['current_gua']['number']}. {stats['current_gua']['name']}")
    
    print("\n✅ 六十四卦状态系统测试完成")
