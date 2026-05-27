"""
太极演化引擎 (Taiji Evolution Engine)
=======================================
基于两仪的四象流转与太极演化系统。

太极定义：
- 太极 = 两仪 + 四象 + 八卦的统一演化
- 演化逻辑：无极 → 太极 → 两仪 → 四象 → 八卦 → 万物

核心机制：
- 状态流转：自动 + 手动 + 事件驱动
- 演化循环：6 个阶段循环
- 万物归一：输出结果沉淀进无极
"""

import json
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum

# 导入两仪和四象
try:
    from modules.bagua.liangyi.switcher import LiangyiSwitcher, Liangyi
    from modules.bagua.sixiang.state_manager import FourSymbolManager, FourSymbol
except ImportError:
    Liangyi = None
    FourSymbol = None


class TaijiPhase(Enum):
    """太极演化阶段"""
    WUJI = "wuji"           # 无极
    TAIJI = "taiji"         # 太极
    LIANGYI = "liangyi"     # 两仪
    SIXIANG = "sixiang"     # 四象
    BAGUA = "bagua"         # 八卦
    WANWU = "wanwu"         # 万物


class EvolutionCycle(Enum):
    """演化循环"""
    PHASE_1 = "phase_1"  # 无极生太极
    PHASE_2 = "phase_2"  # 太极生两仪
    PHASE_3 = "phase_3"  # 两仪生四象
    PHASE_4 = "phase_4"  # 四象生八卦
    PHASE_5 = "phase_5"  # 八卦生万物
    PHASE_6 = "phase_6"  # 万物归无极


@dataclass
class EvolutionState:
    """演化状态"""
    phase: TaijiPhase
    cycle: EvolutionCycle
    cycle_count: int
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class EvolutionRecord:
    """演化记录"""
    id: str
    from_phase: TaijiPhase
    to_phase: TaijiPhase
    from_cycle: EvolutionCycle
    to_cycle: EvolutionCycle
    trigger: str
    timestamp: str
    context: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.context is None:
            self.context = {}


class TaijiEngine:
    """太极演化引擎"""
    
    # 演化阶段定义
    PHASES = {
        TaijiPhase.WUJI: {
            "order": 0,
            "description": "无极 - 初始潜能",
            "next_phase": TaijiPhase.TAIJI,
            "next_cycle": EvolutionCycle.PHASE_1
        },
        TaijiPhase.TAIJI: {
            "order": 1,
            "description": "太极 - 混沌初开",
            "next_phase": TaijiPhase.LIANGYI,
            "next_cycle": EvolutionCycle.PHASE_2
        },
        TaijiPhase.LIANGYI: {
            "order": 2,
            "description": "两仪 - 阴阳分化",
            "next_phase": TaijiPhase.SIXIANG,
            "next_cycle": EvolutionCycle.PHASE_3
        },
        TaijiPhase.SIXIANG: {
            "order": 3,
            "description": "四象 - 四方确立",
            "next_phase": TaijiPhase.BAGUA,
            "next_cycle": EvolutionCycle.PHASE_4
        },
        TaijiPhase.BAGUA: {
            "order": 4,
            "description": "八卦 - 万物雏形",
            "next_phase": TaijiPhase.WANWU,
            "next_cycle": EvolutionCycle.PHASE_5
        },
        TaijiPhase.WANWU: {
            "order": 5,
            "description": "万物 - 演化完成",
            "next_phase": TaijiPhase.WUJI,
            "next_cycle": EvolutionCycle.PHASE_6
        }
    }
    
    def __init__(self, name: str = "TAIJI"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/taiji_engine")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.state_log_path = self.base_path / "state_log.jsonl"
        self.evolution_log_path = self.base_path / "evolution_log.jsonl"
        self.cycle_log_path = self.base_path / "cycle_log.jsonl"
        
        # 当前状态
        self.current_state: Optional[EvolutionState] = None
        self.state_lock = threading.Lock()
        
        # 状态历史
        self.state_history: List[EvolutionState] = []
        self.evolution_records: List[EvolutionRecord] = []
        
        # 回调
        self.phase_callbacks: List[Callable] = []
        self.cycle_callbacks: List[Callable] = []
        
        # 统计
        self.evolution_count = 0
        self.full_cycle_count = 0
        
        # 子管理器
        self.liangyi_switcher: Optional[LiangyiSwitcher] = None
        self.sixiang_manager: Optional[FourSymbolManager] = None
        
        # 自动演化
        self._auto_evolve_enabled = False
        self._auto_evolve_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        
        # 初始化
        self._initialize()
    
    def _initialize(self) -> None:
        """初始化到无极"""
        self.set_phase(TaijiPhase.WUJI, "初始化")
    
    def set_liangyi_switcher(self, switcher: LiangyiSwitcher) -> None:
        """设置两仪切换器"""
        self.liangyi_switcher = switcher
    
    def set_sixiang_manager(self, manager: FourSymbolManager) -> None:
        """设置四象管理器"""
        self.sixiang_manager = manager
    
    def register_phase_callback(self, callback: Callable) -> None:
        """注册阶段变化回调"""
        self.phase_callbacks.append(callback)
    
    def register_cycle_callback(self, callback: Callable) -> None:
        """注册循环变化回调"""
        self.cycle_callbacks.append(callback)
    
    def get_current_phase(self) -> TaijiPhase:
        """获取当前阶段"""
        with self.state_lock:
            return self.current_state.phase if self.current_state else TaijiPhase.WUJI
    
    def get_current_cycle(self) -> EvolutionCycle:
        """获取当前循环"""
        with self.state_lock:
            return self.current_state.cycle if self.current_state else EvolutionCycle.PHASE_1
    
    def set_phase(self, phase: TaijiPhase, trigger: str,
                  context: Optional[Dict[str, Any]] = None) -> bool:
        """
        设置演化阶段
        
        Args:
            phase: 目标阶段
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        with self.state_lock:
            old_state = self.current_state
            
            if old_state and old_state.phase == phase:
                return False
            
            # 确定循环
            phase_info = self.PHASES[phase]
            cycle = phase_info["next_cycle"]
            
            # 计算循环次数
            cycle_count = old_state.cycle_count if old_state else 0
            if (old_state and old_state.phase == TaijiPhase.WANWU and 
                phase == TaijiPhase.WUJI):
                cycle_count += 1
                self.full_cycle_count += 1
            
            # 创建新状态
            new_state = EvolutionState(
                phase=phase,
                cycle=cycle,
                cycle_count=cycle_count,
                timestamp=datetime.now().isoformat(),
                metadata=context or {}
            )
            
            # 记录演化
            if old_state:
                record = EvolutionRecord(
                    id=f"evo_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.evolution_records)}",
                    from_phase=old_state.phase,
                    to_phase=phase,
                    from_cycle=old_state.cycle,
                    to_cycle=cycle,
                    trigger=trigger,
                    timestamp=datetime.now().isoformat(),
                    context=context or {}
                )
                self.evolution_records.append(record)
                self.evolution_count += 1
                
                self._log_evolution(record)
                
                # 记录循环日志
                if record.to_phase == TaijiPhase.WUJI:
                    self._log_cycle(cycle_count)
            
            # 更新状态
            self.current_state = new_state
            self.state_history.append(new_state)
            
            self._log_state(new_state)
            
            # 触发回调
            self._notify_phase_change(old_state, new_state, trigger)
            
            # 联动子管理器
            self._sync_sub_managers(new_state)
            
            return True
    
    def evolve(self, trigger: str = "自动演化",
               context: Optional[Dict[str, Any]] = None) -> bool:
        """
        演化到下一阶段
        
        Args:
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        if not self.current_state:
            return False
        
        next_phase = self.PHASES[self.current_state.phase]["next_phase"]
        return self.set_phase(next_phase, trigger, context)
    
    def force_phase(self, phase: TaijiPhase,
                   context: Optional[Dict[str, Any]] = None) -> bool:
        """
        强制设置阶段
        
        Args:
            phase: 目标阶段
            context: 上下文
            
        Returns:
            是否成功
        """
        return self.set_phase(phase, "强制设置", context)
    
    def start_auto_evolve(self, interval: int = 10) -> None:
        """
        启动自动演化
        
        Args:
            interval: 演化间隔（秒）
        """
        if self._auto_evolve_enabled:
            return
        
        self._auto_evolve_enabled = True
        
        def evolve_loop():
            while not self._stop_event.is_set():
                self.evolve("自动演化")
                self._stop_event.wait(interval)
        
        self._auto_evolve_thread = threading.Thread(target=evolve_loop, daemon=True)
        self._auto_evolve_thread.start()
    
    def stop_auto_evolve(self) -> None:
        """停止自动演化"""
        self._auto_evolve_enabled = False
        self._stop_event.set()
        if self._auto_evolve_thread:
            self._auto_evolve_thread.join(timeout=5)
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.state_lock:
            return {
                "name": self.name,
                "current_phase": self.current_state.phase.value if self.current_state else None,
                "current_cycle": self.current_state.cycle.value if self.current_state else None,
                "cycle_count": self.current_state.cycle_count if self.current_state else 0,
                "total_evolutions": self.evolution_count,
                "full_cycles": self.full_cycle_count,
                "state_history_count": len(self.state_history),
                "evolution_history_count": len(self.evolution_records),
                "phase_definitions": {
                    p.value: {
                        "order": self.PHASES[p]["order"],
                        "description": self.PHASES[p]["description"],
                        "next_phase": self.PHASES[p]["next_phase"].value
                    }
                    for p in TaijiPhase
                }
            }
    
    def get_evolution_history(self, limit: int = 20) -> List[EvolutionRecord]:
        """获取演化历史"""
        with self.state_lock:
            return self.evolution_records[-limit:]
    
    def reset(self) -> None:
        """重置到无极"""
        with self.state_lock:
            self.state_history = []
            self.evolution_records = []
            self.evolution_count = 0
            self.full_cycle_count = 0
        self._initialize()
    
    def _notify_phase_change(self, old: Optional[EvolutionState],
                            new: EvolutionState, trigger: str) -> None:
        """通知阶段变化"""
        for callback in self.phase_callbacks:
            try:
                callback(old, new, trigger)
            except:
                pass
        
        # 循环变化回调
        if old and old.cycle != new.cycle:
            for callback in self.cycle_callbacks:
                try:
                    callback(old, new, trigger)
                except:
                    pass
    
    def _sync_sub_managers(self, state: EvolutionState) -> None:
        """同步子管理器"""
        # 根据阶段同步两仪和四象
        if self.liangyi_switcher:
            if state.phase in [TaijiPhase.LIANGYI, TaijiPhase.SIXIANG, TaijiPhase.BAGUA]:
                # 活跃阶段 → 阳仪
                if self.liangyi_switcher.get_current_liangyi() != Liangyi.YANG:
                    self.liangyi_switcher.switch("太极联动")
        
        if self.sixiang_manager:
            if state.phase in [TaijiPhase.SIXIANG, TaijiPhase.BAGUA]:
                # 四象阶段 → 自动流转
                self.sixiang_manager.auto_transition("太极联动")
    
    def _log_state(self, state: EvolutionState) -> None:
        """记录状态日志"""
        with open(self.state_log_path, "a") as f:
            f.write(json.dumps(asdict(state), default=str, ensure_ascii=False) + "\n")
    
    def _log_evolution(self, record: EvolutionRecord) -> None:
        """记录演化日志"""
        with open(self.evolution_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")
    
    def _log_cycle(self, cycle_count: int) -> None:
        """记录循环日志"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "cycle_count": cycle_count,
            "event": "full_cycle_complete",
            "message": f"完成第 {cycle_count} 个演化循环"
        }
        with open(self.cycle_log_path, "a") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☯ 太极演化引擎 测试")
    print("=" * 60)
    
    engine = TaijiEngine()
    
    # 测试 1：初始状态
    print("\n📝 测试 1：初始状态")
    state = engine.current_state
    print(f"   当前阶段：{state.phase.value}")
    print(f"   当前循环：{state.cycle.value}")
    print(f"   循环次数：{state.cycle_count}")
    
    # 测试 2：自动演化
    print("\n📝 测试 2：自动演化（完整循环）")
    for i in range(6):
        engine.evolve()
        state = engine.current_state
        print(f"   演化 {i+1}: {state.phase.value} ({state.cycle.value})")
    
    # 测试 3：获取统计
    print("\n📝 测试 3：获取统计")
    stats = engine.get_stats()
    print(f"   总演化：{stats['total_evolutions']}")
    print(f"   完整循环：{stats['full_cycles']}")
    print(f"   当前阶段：{stats['current_phase']}")
    
    # 测试 4：获取演化历史
    print("\n📝 测试 4：获取演化历史")
    history = engine.get_evolution_history()
    for r in history[-3:]:
        print(f"   {r.from_phase.value} → {r.to_phase.value} ({r.trigger})")
    
    print("\n✅ 太极演化引擎测试完成")
