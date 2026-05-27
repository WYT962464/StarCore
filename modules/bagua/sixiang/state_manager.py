"""
四象状态管理器 (Four Symbols State Manager)
============================================
基于八卦模块组合的四象状态系统。

四象定义：
- 太阳 ☰☲ (111111): 乾 + 离 = 活跃决策态
- 少阳 ☳☴ (011010): 震 + 巽 = 事件驱动态
- 太阴 ☷☵ (000010): 坤 + 坎 = 稳定存储态
- 少阴 ☶☱ (100011): 艮 + 兑 = 休眠反馈态

卦象组合逻辑：
- 阳卦（乾震坎艮）+ 阴卦（坤巽离兑）= 四象
- 状态流转：太阳 → 少阳 → 太阴 → 少阴 → 太阳（循环）
"""

import json
import threading
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum


class FourSymbol(Enum):
    """四象枚举"""
    TAIYANG = "taiyang"    # 太阳 ☰☲
    SHAOYANG = "shaoyang"  # 少阳 ☳☴
    TAIYIN = "taiyin"      # 太阴 ☷☵
    SHAOYIN = "shaoyin"    # 少阴 ☶☱


@dataclass
class SymbolState:
    """四象状态"""
    symbol: FourSymbol
    binary: str
    components: List[str]  # 组成八卦
    description: str
    characteristics: Dict[str, Any]
    transition_to: FourSymbol  # 下一个状态
    timestamp: str


@dataclass
class StateTransition:
    """状态流转记录"""
    from_symbol: FourSymbol
    to_symbol: FourSymbol
    trigger: str
    timestamp: str
    context: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.context is None:
            self.context = {}


class FourSymbolManager:
    """四象状态管理器"""
    
    # 四象定义
    SYMBOLS = {
        FourSymbol.TAIYANG: {
            "binary": "111111",
            "components": ["QIAN", "LI"],
            "description": "太阳 - 活跃决策态",
            "characteristics": {
                "energy": "high",
                "activity": "max",
                "decision_mode": "active",
                "output_mode": "rendering"
            },
            "transition_to": FourSymbol.SHAOYANG
        },
        FourSymbol.SHAOYANG: {
            "binary": "011010",
            "components": ["ZHEN", "XUN"],
            "description": "少阳 - 事件驱动态",
            "characteristics": {
                "energy": "medium-high",
                "activity": "reactive",
                "decision_mode": "event-driven",
                "output_mode": "collecting"
            },
            "transition_to": FourSymbol.TAIYIN
        },
        FourSymbol.TAIYIN: {
            "binary": "000010",
            "components": ["KUN", "KAN"],
            "description": "太阴 - 稳定存储态",
            "characteristics": {
                "energy": "low",
                "activity": "stable",
                "decision_mode": "passive",
                "output_mode": "storage"
            },
            "transition_to": FourSymbol.SHAOYIN
        },
        FourSymbol.SHAOYIN: {
            "binary": "100011",
            "components": ["GEN", "DUI"],
            "description": "少阴 - 休眠反馈态",
            "characteristics": {
                "energy": "medium-low",
                "activity": "hibernating",
                "decision_mode": "minimal",
                "output_mode": "feedback"
            },
            "transition_to": FourSymbol.TAIYANG
        }
    }
    
    def __init__(self, name: str = "SIXIANG"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/sixiang_manager")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.state_log_path = self.base_path / "state_log.jsonl"
        self.transition_log_path = self.base_path / "transition_log.jsonl"
        
        # 当前状态
        self.current_state: Optional[SymbolState] = None
        self.state_lock = threading.Lock()
        
        # 状态历史
        self.state_history: List[SymbolState] = []
        self.transitions: List[StateTransition] = []
        
        # 回调
        self.state_callbacks: List[Callable] = []
        
        # 统计
        self.transition_count = 0
        self.cycle_count = 0
        
        # 初始化到太阳
        self._initialize()
    
    def _initialize(self) -> None:
        """初始化到太阳状态"""
        self.set_state(FourSymbol.TAIYANG, "初始化")
    
    def register_callback(self, callback: Callable) -> None:
        """注册状态变化回调"""
        self.state_callbacks.append(callback)
    
    def get_current_state(self) -> SymbolState:
        """获取当前状态"""
        with self.state_lock:
            return self.current_state
    
    def set_state(self, symbol: FourSymbol, trigger: str,
                  context: Optional[Dict[str, Any]] = None) -> bool:
        """
        设置四象状态
        
        Args:
            symbol: 目标四象
            trigger: 触发原因
            context: 上下文
            
        Returns:
            是否成功
        """
        with self.state_lock:
            old_state = self.current_state
            
            if old_state and old_state.symbol == symbol:
                return False  # 状态不变
            
            # 创建新状态
            symbol_info = self.SYMBOLS[symbol]
            new_state = SymbolState(
                symbol=symbol,
                binary=symbol_info["binary"],
                components=symbol_info["components"],
                description=symbol_info["description"],
                characteristics=symbol_info["characteristics"],
                transition_to=symbol_info["transition_to"],
                timestamp=datetime.now().isoformat()
            )
            
            # 记录流转
            if old_state:
                transition = StateTransition(
                    from_symbol=old_state.symbol,
                    to_symbol=symbol,
                    trigger=trigger,
                    timestamp=datetime.now().isoformat(),
                    context=context or {}
                )
                self.transitions.append(transition)
                self.transition_count += 1
                
                # 检查是否完成一个循环
                if (old_state.symbol == FourSymbol.SHAOYIN and 
                    symbol == FourSymbol.TAIYANG):
                    self.cycle_count += 1
                
                # 记录日志
                self._log_transition(transition)
            
            # 更新状态
            self.current_state = new_state
            self.state_history.append(new_state)
            
            # 保存日志
            self._log_state(new_state)
            
            # 触发回调
            self._notify_state_change(old_state, new_state, trigger)
            
            return True
    
    def auto_transition(self, context: Optional[Dict[str, Any]] = None) -> bool:
        """
        自动流转到下一个状态
        
        Args:
            context: 上下文
            
        Returns:
            是否流转
        """
        if not self.current_state:
            return False
        
        next_symbol = self.current_state.transition_to
        return self.set_state(next_symbol, "自动流转", context)
    
    def force_transition(self, symbol: FourSymbol, context: Optional[Dict[str, Any]] = None) -> bool:
        """
        强制流转到指定状态
        
        Args:
            symbol: 目标四象
            context: 上下文
            
        Returns:
            是否成功
        """
        return self.set_state(symbol, "强制流转", context)
    
    def get_state_sequence(self, limit: int = 10) -> List[SymbolState]:
        """获取状态序列"""
        with self.state_lock:
            return self.state_history[-limit:]
    
    def get_transition_history(self, limit: int = 20) -> List[StateTransition]:
        """获取流转历史"""
        with self.state_lock:
            return self.transitions[-limit:]
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.state_lock:
            return {
                "name": self.name,
                "current_state": {
                    "symbol": self.current_state.symbol.value if self.current_state else None,
                    "binary": self.current_state.binary if self.current_state else None,
                    "description": self.current_state.description if self.current_state else None,
                    "timestamp": self.current_state.timestamp if self.current_state else None
                },
                "total_transitions": self.transition_count,
                "total_cycles": self.cycle_count,
                "state_history_count": len(self.state_history),
                "transition_history_count": len(self.transitions),
                "symbol_definitions": {
                    s.value: {
                        "binary": self.SYMBOLS[s]["binary"],
                        "components": self.SYMBOLS[s]["components"],
                        "description": self.SYMBOLS[s]["description"]
                    }
                    for s in FourSymbol
                }
            }
    
    def reset(self) -> None:
        """重置到太阳状态"""
        with self.state_lock:
            self.state_history = []
            self.transitions = []
            self.transition_count = 0
            self.cycle_count = 0
        self._initialize()
    
    def _notify_state_change(self, old: Optional[SymbolState], 
                            new: SymbolState, trigger: str) -> None:
        """通知状态变化"""
        for callback in self.state_callbacks:
            try:
                callback(old, new, trigger)
            except:
                pass
    
    def _log_state(self, state: SymbolState) -> None:
        """记录状态日志"""
        with open(self.state_log_path, "a") as f:
            f.write(json.dumps(asdict(state), default=str, ensure_ascii=False) + "\n")
    
    def _log_transition(self, transition: StateTransition) -> None:
        """记录流转日志"""
        with open(self.transition_log_path, "a") as f:
            f.write(json.dumps(asdict(transition), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☰☲☳☴☷☵☶☱ 四象状态管理器 测试")
    print("=" * 60)
    
    manager = FourSymbolManager()
    
    # 测试 1：初始状态
    print("\n📝 测试 1：初始状态")
    state = manager.get_current_state()
    print(f"   当前四象：{state.symbol.value}")
    print(f"   二进制：{state.binary}")
    print(f"   描述：{state.description}")
    print(f"   组成：{', '.join(state.components)}")
    
    # 测试 2：自动流转
    print("\n📝 测试 2：自动流转")
    for i in range(4):
        manager.auto_transition()
        state = manager.get_current_state()
        print(f"   流转 {i+1}: {state.symbol.value} ({state.binary})")
    
    # 测试 3：强制流转
    print("\n📝 测试 3：强制流转")
    manager.force_transition(FourSymbol.TAIYIN, {"reason": "测试"})
    state = manager.get_current_state()
    print(f"   强制到：{state.symbol.value}")
    
    # 测试 4：获取统计
    print("\n📝 测试 4：获取统计")
    stats = manager.get_stats()
    print(f"   总流转：{stats['total_transitions']}")
    print(f"   总循环：{stats['total_cycles']}")
    print(f"   当前状态：{stats['current_state']['symbol']}")
    
    # 测试 5：获取流转历史
    print("\n📝 测试 5：获取流转历史")
    history = manager.get_transition_history()
    for t in history[-3:]:
        print(f"   {t.from_symbol.value} → {t.to_symbol.value} ({t.trigger})")
    
    print("\n✅ 四象状态管理器测试完成")
