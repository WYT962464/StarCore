"""
无极层核心模块 (Wuji Core Module)
==================================
演化系统的起点和终点，潜能存储与万物归一机制。

无极定义：
- 无极 = 初始潜能 + 演化沉淀 + 万物归一
- 功能：
  1. 潜能存储：保存演化积累的能量
  2. 万物归一：输出结果沉淀进无极
  3. 潜能提升：循环次数增加初始潜能
  4. 螺旋演化：潜能提升 → 演化加速

卦象对应：无极 ☯ (混沌)
属性：混沌、潜能、起源、归宿
"""

import json
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum


class WujiState(Enum):
    """无极状态"""
    EMPTY = "empty"           # 空（初始）
    GATHERING = "gathering"   # 聚集（收集潜能）
    FULL = "full"             # 满（潜能充足）
    RELEASING = "releasing"   # 释放（输出潜能）
    TRANSFORMING = "transforming"  # 转化（螺旋升级）


@dataclass
class WujiPotential:
    """无极潜能"""
    base_potential: float          # 基础潜能 (0-1)
    accumulated_potential: float   # 积累潜能
    total_potential: float         # 总潜能
    cycle_count: int               # 演化循环次数
    evolution_speed: float         # 演化速度系数
    last_updated: str
    
    def __post_init__(self):
        self.total_potential = self.base_potential + self.accumulated_potential


@dataclass
class WujiRecord:
    """无极记录（万物归一）"""
    id: str
    source: str              # 来源（哪个模块/阶段）
    content_type: str        # 内容类型
    content: Dict[str, Any]  # 沉淀内容
    potential_added: float   # 贡献的潜能
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class SpiralEvolution:
    """螺旋演化记录"""
    cycle_number: int
    base_potential_before: float
    base_potential_after: float
    speed_multiplier: float
    timestamp: str
    trigger: str


class WujiCore:
    """无极层核心"""
    
    # 潜能计算公式
    # 基础潜能 = 初始值 + 循环次数 × 提升系数
    # 演化速度 = 基础速度 × (1 + 总潜能 × 加速系数)
    POTENTIAL_PER_CYCLE = 0.05      # 每循环提升 5% 基础潜能
    MAX_BASE_POTENTIAL = 1.0        # 基础潜能上限
    SPEED_ACCELERATION = 0.5        # 速度加速系数
    MIN_EVOLUTION_SPEED = 1.0       # 最小演化速度
    MAX_EVOLUTION_SPEED = 10.0      # 最大演化速度
    
    def __init__(self, name: str = "WUJI", initial_potential: float = 0.1):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/wuji_core")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.potential_path = self.base_path / "potential.json"
        self.record_log_path = self.base_path / "wuji_records.jsonl"
        self.spiral_log_path = self.base_path / "spiral_evolution.jsonl"
        
        # 当前状态
        self.current_state = WujiState.EMPTY
        self.state_lock = threading.Lock()
        
        # 潜能数据
        self.potential = WujiPotential(
            base_potential=initial_potential,
            accumulated_potential=0.0,
            total_potential=initial_potential,
            cycle_count=0,
            evolution_speed=self.MIN_EVOLUTION_SPEED,
            last_updated=datetime.now().isoformat()
        )
        
        # 记录历史
        self.wuji_records: List[WujiRecord] = []
        self.spiral_history: List[SpiralEvolution] = []
        
        # 回调
        self.state_callbacks: List[Callable] = []
        self.potential_callbacks: List[Callable] = []
        
        # 统计
        self.total_added_potential = 0.0
        self.total_records = 0
        
        # 加载持久化数据
        self._load_potential()
    
    def register_state_callback(self, callback: Callable) -> None:
        """注册状态变化回调"""
        self.state_callbacks.append(callback)
    
    def register_potential_callback(self, callback: Callable) -> None:
        """注册潜能变化回调"""
        self.potential_callbacks.append(callback)
    
    def get_state(self) -> WujiState:
        """获取当前状态"""
        with self.state_lock:
            return self.current_state
    
    def get_potential(self) -> WujiPotential:
        """获取当前潜能"""
        with self.state_lock:
            return self.potential
    
    def get_potential_stats(self) -> Dict[str, Any]:
        """获取潜能统计"""
        with self.state_lock:
            return {
                "name": self.name,
                "state": self.current_state.value,
                "base_potential": round(self.potential.base_potential, 4),
                "accumulated_potential": round(self.potential.accumulated_potential, 4),
                "total_potential": round(self.potential.total_potential, 4),
                "cycle_count": self.potential.cycle_count,
                "evolution_speed": round(self.potential.evolution_speed, 2),
                "total_added_potential": round(self.total_added_potential, 4),
                "total_records": self.total_records,
                "potential_capacity": {
                    "max_base": self.MAX_BASE_POTENTIAL,
                    "potential_per_cycle": self.POTENTIAL_PER_CYCLE,
                    "speed_acceleration": self.SPEED_ACCELERATION
                }
            }
    
    def add_potential(self, amount: float, source: str = "system",
                     content: Optional[Dict[str, Any]] = None) -> WujiRecord:
        """
        添加潜能（万物归一）
        
        Args:
            amount: 潜能数量 (0-1)
            source: 来源
            content: 沉淀内容
            
        Returns:
            无极记录
        """
        with self.state_lock:
            # 创建记录
            record_id = f"wuji_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.wuji_records)}"
            
            record = WujiRecord(
                id=record_id,
                source=source,
                content_type=content.get("type", "unknown") if content else "unknown",
                content=content or {},
                potential_added=amount,
                timestamp=datetime.now().isoformat()
            )
            
            # 更新潜能
            old_potential = self.potential.total_potential
            self.potential.accumulated_potential += amount
            self.potential.total_potential = (
                self.potential.base_potential + self.potential.accumulated_potential
            )
            
            # 更新状态
            if self.potential.total_potential >= 0.8:
                self.current_state = WujiState.FULL
            elif self.potential.total_potential >= 0.3:
                self.current_state = WujiState.GATHERING
            else:
                self.current_state = WujiState.EMPTY
            
            # 更新演化速度
            self._update_evolution_speed()
            
            # 记录
            self.wuji_records.append(record)
            self.total_added_potential += amount
            self.total_records += 1
            
            # 保存
            self._save_potential()
            self._log_record(record)
            
            # 触发回调
            self._notify_potential_change(old_potential, self.potential.total_potential, amount)
            
            return record
    
    def consume_potential(self, amount: float, purpose: str = "evolution") -> bool:
        """
        消耗潜能
        
        Args:
            amount: 潜能数量
            purpose: 用途
            
        Returns:
            是否成功
        """
        with self.state_lock:
            if self.potential.total_potential < amount:
                return False  # 潜能不足
            
            self.potential.accumulated_potential -= amount
            self.potential.total_potential = (
                self.potential.base_potential + self.potential.accumulated_potential
            )
            
            # 更新状态
            if self.potential.total_potential < 0.3:
                self.current_state = WujiState.EMPTY
            
            # 更新演化速度
            self._update_evolution_speed()
            
            # 保存
            self._save_potential()
            
            return True
    
    def complete_cycle(self, cycle_number: int) -> SpiralEvolution:
        """
        完成一个演化循环，触发螺旋升级
        
        Args:
            cycle_number: 循环编号
            
        Returns:
            螺旋演化记录
        """
        with self.state_lock:
            # 记录升级前状态
            base_before = self.potential.base_potential
            
            # 提升基础潜能
            new_base = min(
                base_before + self.POTENTIAL_PER_CYCLE,
                self.MAX_BASE_POTENTIAL
            )
            
            # 计算速度提升
            old_speed = self.potential.evolution_speed
            self.potential.base_potential = new_base
            self.potential.cycle_count = cycle_number
            self._update_evolution_speed()
            
            speed_multiplier = self.potential.evolution_speed / old_speed if old_speed > 0 else 1.0
            
            # 创建记录
            spiral = SpiralEvolution(
                cycle_number=cycle_number,
                base_potential_before=base_before,
                base_potential_after=new_base,
                speed_multiplier=round(speed_multiplier, 2),
                timestamp=datetime.now().isoformat(),
                trigger="cycle_complete"
            )
            
            self.spiral_history.append(spiral)
            
            # 状态转换
            self.current_state = WujiState.TRANSFORMING
            
            # 保存
            self._save_potential()
            self._log_spiral(spiral)
            
            # 触发回调
            self._notify_potential_change(base_before, new_base, new_base - base_before)
            
            return spiral
    
    def reset(self, keep_cycles: bool = False) -> None:
        """
        重置无极
        
        Args:
            keep_cycles: 是否保留循环次数
        """
        with self.state_lock:
            cycles = self.potential.cycle_count if keep_cycles else 0
            base = self.POTENTIAL_PER_CYCLE * cycles if keep_cycles else 0.1
            
            self.potential = WujiPotential(
                base_potential=base,
                accumulated_potential=0.0,
                total_potential=base,
                cycle_count=cycles,
                evolution_speed=self.MIN_EVOLUTION_SPEED,
                last_updated=datetime.now().isoformat()
            )
            self.current_state = WujiState.EMPTY
            self.wuji_records = []
            self.total_added_potential = 0.0
            self.total_records = 0
            
            self._save_potential()
    
    def get_wuji_records(self, limit: int = 20) -> List[WujiRecord]:
        """获取无极记录"""
        with self.state_lock:
            return self.wuji_records[-limit:]
    
    def get_spiral_history(self, limit: int = 10) -> List[SpiralEvolution]:
        """获取螺旋演化历史"""
        with self.state_lock:
            return self.spiral_history[-limit:]
    
    def calculate_evolution_interval(self, base_interval: int = 10) -> int:
        """
        计算演化间隔（基于潜能加速）
        
        Args:
            base_interval: 基础间隔（秒）
            
        Returns:
            实际间隔（秒）
        """
        with self.state_lock:
            # 速度越快，间隔越短
            speed = self.potential.evolution_speed
            interval = base_interval / speed
            return max(1, int(interval))  # 最小 1 秒
    
    def _update_evolution_speed(self) -> None:
        """更新演化速度"""
        # 速度 = 基础速度 × (1 + 总潜能 × 加速系数)
        speed = self.MIN_EVOLUTION_SPEED * (1 + self.potential.total_potential * self.SPEED_ACCELERATION)
        self.potential.evolution_speed = min(speed, self.MAX_EVOLUTION_SPEED)
        self.potential.last_updated = datetime.now().isoformat()
    
    def _notify_potential_change(self, old: float, new: float, delta: float) -> None:
        """通知潜能变化"""
        for callback in self.potential_callbacks:
            try:
                callback(old, new, delta)
            except:
                pass
    
    def _save_potential(self) -> None:
        """保存潜能数据"""
        data = {
            "name": self.name,
            "potential": asdict(self.potential),
            "state": self.current_state.value,
            "total_added": self.total_added_potential,
            "record_count": self.total_records,
            "saved_at": datetime.now().isoformat()
        }
        
        with open(self.potential_path, "w") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    
    def _load_potential(self) -> None:
        """加载潜能数据"""
        if not self.potential_path.exists():
            return
        
        try:
            with open(self.potential_path, "r") as f:
                data = json.load(f)
            
            pot_data = data.get("potential", {})
            self.potential = WujiPotential(**pot_data)
            self.current_state = WujiState(data.get("state", "empty"))
            self.total_added_potential = data.get("total_added", 0.0)
            self.total_records = data.get("record_count", 0)
        except:
            pass
    
    def _log_record(self, record: WujiRecord) -> None:
        """记录无极日志"""
        with open(self.record_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")
    
    def _log_spiral(self, spiral: SpiralEvolution) -> None:
        """记录螺旋演化日志"""
        with open(self.spiral_log_path, "a") as f:
            f.write(json.dumps(asdict(spiral), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☯ 无极层核心模块 测试")
    print("=" * 60)
    
    wuji = WujiCore()
    
    # 测试 1：初始状态
    print("\n📝 测试 1：初始状态")
    stats = wuji.get_potential_stats()
    print(f"   状态：{stats['state']}")
    print(f"   基础潜能：{stats['base_potential']}")
    print(f"   总潜能：{stats['total_potential']}")
    print(f"   演化速度：{stats['evolution_speed']}")
    
    # 测试 2：添加潜能（万物归一）
    print("\n📝 测试 2：添加潜能（万物归一）")
    record = wuji.add_potential(
        amount=0.15,
        source="taiji_engine",
        content={"type": "evolution_output", "phase": "wanwu"}
    )
    print(f"   记录 ID: {record.id}")
    print(f"   贡献潜能：{record.potential_added}")
    
    stats = wuji.get_potential_stats()
    print(f"   新总潜能：{stats['total_potential']}")
    print(f"   新速度：{stats['evolution_speed']}")
    
    # 测试 3：完成循环（螺旋升级）
    print("\n📝 测试 3：完成循环（螺旋升级）")
    spiral = wuji.complete_cycle(1)
    print(f"   循环 {spiral.cycle_number}:")
    print(f"   基础潜能：{spiral.base_potential_before} → {spiral.base_potential_after}")
    print(f"   速度倍数：{spiral.speed_multiplier}x")
    
    # 测试 4：计算演化间隔
    print("\n📝 测试 4：计算演化间隔")
    interval = wuji.calculate_evolution_interval(base_interval=10)
    print(f"   基础间隔：10 秒")
    print(f"   实际间隔：{interval} 秒")
    
    # 测试 5：消耗潜能
    print("\n📝 测试 5：消耗潜能")
    success = wuji.consume_potential(0.1, purpose="test")
    print(f"   消耗成功：{success}")
    
    stats = wuji.get_potential_stats()
    print(f"   剩余总潜能：{stats['total_potential']}")
    
    # 测试 6：多次循环
    print("\n📝 测试 6：多次循环（模拟演化）")
    for i in range(5):
        wuji.add_potential(0.08, source=f"cycle_{i+1}")
        spiral = wuji.complete_cycle(i + 1)
        print(f"   循环 {i+1}: 基础潜能 {spiral.base_potential_after:.3f}, 速度 {spiral.speed_multiplier}x")
    
    # 测试 7：获取统计
    print("\n📝 测试 7：获取最终统计")
    stats = wuji.get_potential_stats()
    print(f"   总循环：{stats['cycle_count']}")
    print(f"   基础潜能：{stats['base_potential']}")
    print(f"   总潜能：{stats['total_potential']}")
    print(f"   演化速度：{stats['evolution_speed']}")
    print(f"   记录数：{stats['total_records']}")
    
    print("\n✅ 无极层核心模块测试完成")
