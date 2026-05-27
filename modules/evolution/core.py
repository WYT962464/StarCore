"""
六十四卦演化路径模块 (Gua64 Evolution Path Module)
=====================================================
基于易经逻辑的卦象演化算法。

演化规则：
1. 阴阳消长驱动卦象变化
2. 相邻卦象转换（符合易经卦序）
3. 数据触发演化（iOS 数据变化）
4. 演化方向由两仪比例决定

卦象系统：
- 64 卦，每卦 6 爻
- 爻值：0=阴，1=阳
- 卦值：6 位二进制数（0-63）
- 卦名：乾/坤/屯/蒙/需/讼/师/比/小畜/履/泰/否/同人/大有/谦/豫/随/蛊/临/观/噬嗑/贲/剥/复/无妄/大畜/颐/大过/坎/离/咸/恒/遁/大壮/晋/明夷/家人/睽/蹇/解/损/益/夬/姤/萃/升/困/井/革/鼎/震/艮/渐/归妹/丰/旅/巽/兑/涣/节/中孚/小过/既济/未济
"""

import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum
import random


class GuaDirection(Enum):
    """演化方向"""
    FORWARD = "forward"      # 前进（阳增）
    BACKWARD = "backward"    # 后退（阴增）
    HORIZONTAL = "horizontal"  # 横向（爻变）
    VERTICAL = "vertical"    # 纵向（卦变）
    RANDOM = "random"        # 随机


class Gua64System:
    """六十四卦系统"""
    
    # 卦名映射（按二进制顺序）
    GUA_NAMES = [
        "乾", "坤", "屯", "蒙", "需", "讼", "师", "比",
        "小畜", "履", "泰", "否", "同人", "大有", "谦", "豫",
        "随", "蛊", "临", "观", "噬嗑", "贲", "剥", "复",
        "无妄", "大畜", "颐", "大过", "坎", "离", "咸", "恒",
        "遁", "大壮", "晋", "明夷", "家人", "睽", "蹇", "解",
        "损", "益", "夬", "姤", "萃", "升", "困", "井",
        "革", "鼎", "震", "艮", "渐", "归妹", "丰", "旅",
        "巽", "兑", "涣", "节", "中孚", "小过", "既济", "未济"
    ]
    
    # 卦序映射（周易顺序）
    ZHOUYI_ORDER = [
        0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30,
        31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44,
        45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58,
        59, 60, 61, 62, 63
    ]
    
    def __init__(self):
        self.current_gua = 0  # 当前卦象（二进制值）
        self.current_gua_name = "乾"
        self.evolution_history: List[Dict] = []
        self.cycle_count = 0
    
    def get_gua_name(self, gua_value: int) -> str:
        """获取卦名"""
        if 0 <= gua_value < 64:
            return self.GUA_NAMES[gua_value]
        return "未知"
    
    def get_gua_lines(self, gua_value: int) -> List[int]:
        """获取卦的 6 爻（从下到上）"""
        # 乾=0 是全阳（6 阳），坤=1 是全阴（6 阴）
        # 卦象编码规则：
        # 乾（0）= 111111（全阳）= 63 的二进制反转
        # 坤（1）= 000000（全阴）= 0 的二进制
        # 所以爻值 = 63 - gua_value 的二进制位
        lines = []
        inverted = 63 - gua_value  # 反转所有位
        for i in range(6):
            lines.append((inverted >> i) & 1)
        return lines
    
    def get_gua_binary(self, gua_value: int) -> str:
        """获取卦的二进制表示（显示为阴阳）"""
        lines = self.get_gua_lines(gua_value)
        binary_str = ""
        for line in lines:
            binary_str += "1" if line == 1 else "0"
        return binary_str
    
    def get_yang_ratio(self, gua_value: int) -> float:
        """获取阳爻比例"""
        lines = self.get_gua_lines(gua_value)
        return sum(lines) / 6.0
    
    def get_yin_ratio(self, gua_value: int) -> float:
        """获取阴爻比例"""
        return 1.0 - self.get_yang_ratio(gua_value)


@dataclass
class EvolutionRecord:
    """演化记录"""
    timestamp: str
    from_gua: int
    from_gua_name: str
    to_gua: int
    to_gua_name: str
    direction: str
    trigger: str
    yang_ratio_before: float
    yang_ratio_after: float
    cycle: int


class EvolutionEngine:
    """演化引擎"""
    
    def __init__(self, system: Gua64System):
        self.system = system
        self.evolution_log: List[EvolutionRecord] = []
        self.save_path = Path("/home/ubuntu/starcore/data/evolution_log.jsonl")
        self.save_path.parent.mkdir(parents=True, exist_ok=True)
    
    def evolve(self, 
               trigger: str = "data_change",
               direction: Optional[GuaDirection] = None,
               yang_ratio: Optional[float] = None,
               yin_ratio: Optional[float] = None) -> EvolutionRecord:
        """
        执行演化
        
        Args:
            trigger: 触发原因
            direction: 演化方向
            yang_ratio: 阳爻比例（用于决定方向）
            yin_ratio: 阴爻比例
            
        Returns:
            演化记录
        """
        from_gua = self.system.current_gua
        from_gua_name = self.system.current_gua_name
        yang_before = self.system.get_yang_ratio(from_gua)
        
        # 确定演化方向
        if direction is None:
            direction = self._determine_direction(yang_ratio, yin_ratio)
        
        # 计算新卦象
        to_gua = self._calculate_next_gua(from_gua, direction)
        to_gua_name = self.system.get_gua_name(to_gua)
        yang_after = self.system.get_yang_ratio(to_gua)
        
        # 创建记录
        record = EvolutionRecord(
            timestamp=datetime.now().isoformat(),
            from_gua=from_gua,
            from_gua_name=from_gua_name,
            to_gua=to_gua,
            to_gua_name=to_gua_name,
            direction=direction.value,
            trigger=trigger,
            yang_ratio_before=yang_before,
            yang_ratio_after=yang_after,
            cycle=self.system.cycle_count
        )
        
        # 更新系统状态
        self.system.current_gua = to_gua
        self.system.current_gua_name = to_gua_name
        self.system.evolution_history.append(asdict(record))
        
        # 记录日志
        self.evolution_log.append(record)
        self._save_log(record)
        
        return record
    
    def _determine_direction(self, 
                              yang_ratio: Optional[float],
                              yin_ratio: Optional[float]) -> GuaDirection:
        """根据阴阳比例决定演化方向"""
        if yang_ratio is not None and yang_ratio > 0.5:
            return GuaDirection.FORWARD  # 阳盛则进
        elif yin_ratio is not None and yin_ratio > 0.5:
            return GuaDirection.BACKWARD  # 阴盛则退
        else:
            return GuaDirection.HORIZONTAL  # 平衡则变爻
    
    def _calculate_next_gua(self, current: int, direction: GuaDirection) -> int:
        """计算下一个卦象"""
        if direction == GuaDirection.FORWARD:
            # 前进：阳爻增加（阴爻减少）
            lines = self.system.get_gua_lines(current)
            # 找到最下面的阴爻，变为阳
            for i in range(6):
                if lines[i] == 0:
                    lines[i] = 1
                    break
            else:
                # 全阳，无法继续前进，切换到横向演化
                return self._calculate_next_gua(current, GuaDirection.HORIZONTAL)
            
        elif direction == GuaDirection.BACKWARD:
            # 后退：阴爻增加（阳爻减少）
            lines = self.system.get_gua_lines(current)
            # 找到最下面的阳爻，变为阴
            for i in range(6):
                if lines[i] == 1:
                    lines[i] = 0
                    break
            else:
                # 全阴，无法继续后退，切换到横向演化
                return self._calculate_next_gua(current, GuaDirection.HORIZONTAL)
            
        elif direction == GuaDirection.HORIZONTAL:
            # 横向：随机变一个爻
            lines = self.system.get_gua_lines(current)
            line_idx = random.randint(0, 5)
            lines[line_idx] = 1 - lines[line_idx]
            
        elif direction == GuaDirection.VERTICAL:
            # 纵向：按周易卦序前进
            try:
                idx = self.system.ZHOUYI_ORDER.index(current)
                next_idx = (idx + 1) % len(self.system.ZHOUYI_ORDER)
                return self.system.ZHOUYI_ORDER[next_idx]
            except ValueError:
                return (current + 1) % 64
        
        else:
            # 随机
            return random.randint(0, 63)
        
        # 转换回卦值（反转：阳=1, 阴=0 → 卦值）
        new_gua = 63  # 初始全阳
        for i, line in enumerate(lines):
            if line == 0:  # 阴爻
                new_gua -= (1 << i)
        
        return new_gua
    
    def _save_log(self, record: EvolutionRecord) -> None:
        """保存演化日志"""
        with open(self.save_path, "a") as f:
            f.write(json.dumps(asdict(record)) + "\n")
    
    def get_evolution_path(self, steps: int = 10) -> List[EvolutionRecord]:
        """获取最近演化路径"""
        return self.evolution_log[-steps:]
    
    def get_statistics(self) -> Dict[str, Any]:
        """获取演化统计"""
        if not self.evolution_log:
            return {"total": 0}
        
        directions = {}
        triggers = {}
        for record in self.evolution_log:
            directions[record.direction] = directions.get(record.direction, 0) + 1
            triggers[record.trigger] = triggers.get(record.trigger, 0) + 1
        
        return {
            "total": len(self.evolution_log),
            "directions": directions,
            "triggers": triggers,
            "current_gua": self.system.current_gua,
            "current_gua_name": self.system.current_gua_name,
            "yang_ratio": self.system.get_yang_ratio(self.system.current_gua)
        }


# 测试
if __name__ == "__main__":
    print("=" * 70)
    print("🔮 六十四卦演化路径 测试")
    print("=" * 70)
    
    system = Gua64System()
    engine = EvolutionEngine(system)
    
    print(f"\n📍 初始状态：{system.current_gua_name} ({system.current_gua})")
    print(f"   阳爻比例：{system.get_yang_ratio(system.current_gua):.2f}")
    
    # 模拟演化
    print("\n📝 模拟演化（20 步）")
    for i in range(20):
        # 根据当前状态决定触发条件
        yang = system.get_yang_ratio(system.current_gua)
        if yang > 0.7:
            record = engine.evolve(trigger="yang_high", yang_ratio=yang, direction=GuaDirection.BACKWARD)
        elif yang < 0.3:
            record = engine.evolve(trigger="yin_high", yin_ratio=1-yang, direction=GuaDirection.FORWARD)
        else:
            record = engine.evolve(trigger="data_change")
        
        print(f"   第{i+1}步: {record.from_gua_name} → {record.to_gua_name} "
              f"({record.from_gua} → {record.to_gua}) "
              f"[{record.direction}] 阳:{record.yang_ratio_before:.2f}→{record.yang_ratio_after:.2f}")
    
    # 统计
    print("\n📊 演化统计")
    stats = engine.get_statistics()
    print(f"   总演化: {stats['total']} 次")
    print(f"   当前卦: {stats['current_gua_name']} ({stats['current_gua']})")
    print(f"   方向分布: {stats['directions']}")
    print(f"   触发分布: {stats['triggers']}")
    
    # 卦象信息
    print("\n📋 当前卦象信息")
    gua = system.current_gua
    lines = system.get_gua_lines(gua)
    print(f"   卦名: {system.get_gua_name(gua)}")
    print(f"   卦值: {gua} (二进制: {system.get_gua_binary(gua)})")
    print(f"   六爻: {''.join(['━' if l else '⚋' for l in lines])}")
    print(f"   阳爻: {sum(lines)} 阴爻: {6-sum(lines)}")
    
    print("\n✅ 演化路径测试完成")
