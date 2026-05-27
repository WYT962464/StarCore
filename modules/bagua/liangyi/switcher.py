"""
两仪切换机制 (Liangyi Switching Mechanism)
===========================================
基于四象的两仪（阴阳）状态切换系统。

两仪定义：
- 阳仪 (YANG): 太阳 + 少阳 = 活跃态
- 阴仪 (YIN): 太阴 + 少阴 = 静稳态

切换逻辑：
- 阳仪 → 阴仪：能量下降、活动减少
- 阴仪 → 阳仪：能量上升、活动增加
- 自动切换：基于系统状态监测
"""

import json
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum

# 导入四象
try:
    from modules.bagua.sixiang.state_manager import FourSymbol, FourSymbolManager
except ImportError:
    # 测试时直接定义
    class FourSymbol(Enum):
        TAIYANG = "taiyang"
        SHAOYANG = "shaoyang"
        TAIYIN = "taiyin"
        SHAOYIN = "shaoyin"


class Liangyi(Enum):
    """两仪枚举"""
    YANG = "yang"   # 阳仪
    YIN = "yin"     # 阴仪


@dataclass
class LiangyiState:
    """两仪状态"""
    liangyi: Liangyi
    binary: str
    symbols: List[FourSymbol]
    description: str
    characteristics: Dict[str, Any]
    timestamp: str


@dataclass
class LiangyiTransition:
    """两仪流转记录"""
    from_liangyi: Liangyi
    to_liangyi: Liangyi
    trigger: str
    timestamp: str
    context: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.context is None:
            self.context = {}


class LiangyiSwitcher:
    """两仪切换机制"""
    
    # 两仪定义
    LIANGYI_DEFINITIONS = {
        Liangyi.YANG: {
            "binary": "11",
            "symbols": [FourSymbol.TAIYANG, FourSymbol.SHAOYANG],
            "description": "阳仪 - 活跃态",
            "characteristics": {
                "energy": "high",
                "activity": "active",
                "mode": "yang",
                "color": "white"
            }
        },
        Liangyi.YIN: {
            "binary": "00",
            "symbols": [FourSymbol.TAIYIN, FourSymbol.SHAOYIN],
            "description": "阴仪 - 静稳态",
            "characteristics": {
                "energy": "low",
                "activity": "stable",
                "mode": "yin",
                "color": "black"
            }
        }
    }
    
    def __init__(self, name: str = "LIANGYI"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/liangyi_switcher")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.state_log_path = self.base_path / "state_log.jsonl"
        self.transition_log_path = self.base_path / "transition_log.jsonl"
        
        # 当前状态
        self.current_state: Optional[LiangyiState] = None
        self.state_lock = threading.Lock()
        
        # 状态历史
        self.state_history: List[LiangyiState] = []
        self.transitions: List[LiangyiTransition] = []
        
        # 回调
        self.state_callbacks: List[Callable] = []
        
        # 统计
        self.transition_count = 0
        self.cycle_count = 0
        
        # 四象管理器（可选集成）
        self.sixiang_manager: Optional[FourSymbolManager] = None
        
        # 初始化到阳仪
        self._initialize()
    
    def set_sixiang_manager(self, manager: FourSymbolManager) -> None:
        """设置四象管理器进行联动"""
        self.sixiang_manager = manager
        # 注册回调，实现联动
        manager.register_callback(self._on_sixiang_change)
    
    def _initialize(self) -> None:
        """初始化到阳仪"""
        self.set_state(Liangyi.YANG, "初始化")
    
    def register_callback(self, callback: Callable) -> None:
        """注册状态变化回调"""
        self.state_callbacks.append(callback)
    
    def _on_sixiang_change(self, old_state, new_state, trigger: str) -> None:
        """四象变化时的联动处理"""
        if not self.sixiang_manager:
            return
        
        # 根据四象判断两仪
        if new_state.symbol in [FourSymbol.TAIYANG, FourSymbol.SHAOYANG]:
            target = Liangyi.YANG
        else:
            target = Liangyi.YIN
        
        current = self.get_current_liangyi()
        if current != target:
            self.set_state(target, f"四象联动: {new_state.symbol.value}")
    
    def get_current_liangyi(self) -> Liangyi:
        """获取当前两仪"""
        with self.state_lock:
            return self.current_state.liangyi if self.current_state else Liangyi.YANG
    
    def set_state(self, liangyi: Liangyi, trigger: str,
                  context: Optional[Dict[str, Any]] = None) -> bool:
        """
        设置两仪状态
        
        Args:
            liangyi: 目标两仪
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        with self.state_lock:
            old_state = self.current_state
            
            if old_state and old_state.liangyi == liangyi:
                return False
            
            # 创建新状态
            def_info = self.LIANGYI_DEFINITIONS[liangyi]
            new_state = LiangyiState(
                liangyi=liangyi,
                binary=def_info["binary"],
                symbols=def_info["symbols"],
                description=def_info["description"],
                characteristics=def_info["characteristics"],
                timestamp=datetime.now().isoformat()
            )
            
            # 记录流转
            if old_state:
                transition = LiangyiTransition(
                    from_liangyi=old_state.liangyi,
                    to_liangyi=liangyi,
                    trigger=trigger,
                    timestamp=datetime.now().isoformat(),
                    context=context or {}
                )
                self.transitions.append(transition)
                self.transition_count += 1
                
                # 检查循环
                if (old_state.liangyi == Liangyi.YIN and liangyi == Liangyi.YANG):
                    self.cycle_count += 1
                
                self._log_transition(transition)
            
            # 更新状态
            self.current_state = new_state
            self.state_history.append(new_state)
            
            self._log_state(new_state)
            self._notify_state_change(old_state, new_state, trigger)
            
            return True
    
    def switch(self, trigger: str = "手动切换",
               context: Optional[Dict[str, Any]] = None) -> bool:
        """
        切换到另一仪
        
        Args:
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        current = self.get_current_liangyi()
        target = Liangyi.YIN if current == Liangyi.YANG else Liangyi.YANG
        return self.set_state(target, trigger, context)
    
    def auto_switch(self, energy_level: float, activity_level: float,
                   context: Optional[Dict[str, Any]] = None) -> bool:
        """
        基于能量和活动度自动切换
        
        Args:
            energy_level: 能量水平 (0-1)
            activity_level: 活动度 (0-1)
            context: 上下文
            
        Returns:
            是否切换
        """
        # 综合评分
        score = (energy_level + activity_level) / 2
        
        target = Liangyi.YANG if score > 0.5 else Liangyi.YIN
        current = self.get_current_liangyi()
        
        if current != target:
            return self.set_state(target, "自动切换", {
                "energy": energy_level,
                "activity": activity_level,
                "score": score,
                **(context or {})
            })
        
        return False
    
    def get_state_sequence(self, limit: int = 10) -> List[LiangyiState]:
        """获取状态序列"""
        with self.state_lock:
            return self.state_history[-limit:]
    
    def get_transition_history(self, limit: int = 20) -> List[LiangyiTransition]:
        """获取流转历史"""
        with self.state_lock:
            return self.transitions[-limit:]
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.state_lock:
            return {
                "name": self.name,
                "current_liangyi": self.current_state.liangyi.value if self.current_state else None,
                "current_binary": self.current_state.binary if self.current_state else None,
                "total_transitions": self.transition_count,
                "total_cycles": self.cycle_count,
                "state_history_count": len(self.state_history),
                "transition_history_count": len(self.transitions),
                "liangyi_definitions": {
                    l.value: {
                        "binary": self.LIANGYI_DEFINITIONS[l]["binary"],
                        "symbols": [s.value for s in self.LIANGYI_DEFINITIONS[l]["symbols"]],
                        "description": self.LIANGYI_DEFINITIONS[l]["description"]
                    }
                    for l in Liangyi
                }
            }
    
    def reset(self) -> None:
        """重置到阳仪"""
        with self.state_lock:
            self.state_history = []
            self.transitions = []
            self.transition_count = 0
            self.cycle_count = 0
        self._initialize()
    
    def _notify_state_change(self, old: Optional[LiangyiState],
                            new: LiangyiState, trigger: str) -> None:
        """通知状态变化"""
        for callback in self.state_callbacks:
            try:
                callback(old, new, trigger)
            except:
                pass
    
    def _log_state(self, state: LiangyiState) -> None:
        """记录状态日志"""
        with open(self.state_log_path, "a") as f:
            f.write(json.dumps(asdict(state), default=str, ensure_ascii=False) + "\n")
    
    def _log_transition(self, transition: LiangyiTransition) -> None:
        """记录流转日志"""
        with open(self.transition_log_path, "a") as f:
            f.write(json.dumps(asdict(transition), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☯ 两仪切换机制 测试")
    print("=" * 60)
    
    switcher = LiangyiSwitcher()
    
    # 测试 1：初始状态
    print("\n📝 测试 1：初始状态")
    state = switcher.current_state
    print(f"   当前两仪：{state.liangyi.value}")
    print(f"   二进制：{state.binary}")
    print(f"   描述：{state.description}")
    print(f"   包含四象：{', '.join(s.symbol.value for s in state.symbols)}")
    
    # 测试 2：手动切换
    print("\n📝 测试 2：手动切换")
    switcher.switch("手动测试")
    state = switcher.current_state
    print(f"   切换后：{state.liangyi.value}")
    
    switcher.switch("手动测试 2")
    state = switcher.current_state
    print(f"   再切换：{state.liangyi.value}")
    
    # 测试 3：自动切换
    print("\n📝 测试 3：自动切换")
    switcher.auto_switch(energy_level=0.8, activity_level=0.9, context={"test": "high"})
    state = switcher.current_state
    print(f"   高能量：{state.liangyi.value}")
    
    switcher.auto_switch(energy_level=0.2, activity_level=0.1, context={"test": "low"})
    state = switcher.current_state
    print(f"   低能量：{state.liangyi.value}")
    
    # 测试 4：获取统计
    print("\n📝 测试 4：获取统计")
    stats = switcher.get_stats()
    print(f"   总切换：{stats['total_transitions']}")
    print(f"   总循环：{stats['total_cycles']}")
    print(f"   当前：{stats['current_liangyi']}")
    
    # 测试 5：获取流转历史
    print("\n📝 测试 5：获取流转历史")
    history = switcher.get_transition_history()
    for t in history[-3:]:
        print(f"   {t.from_liangyi.value} → {t.to_liangyi.value} ({t.trigger})")
    
    print("\n✅ 两仪切换机制测试完成")
