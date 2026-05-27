"""
艮 ☶ 休眠控制器 (Hibernate Controller)
========================================
八卦之七，止，代表休眠与暂停能力。

功能：
- 系统休眠控制
- 暂停/恢复管理
- 休眠策略执行
- 唤醒机制

卦象：艮 ☶ (100) - 山，止
属性：止、静止、稳定、暂停
"""

import json
import time
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum


class SystemState(Enum):
    """系统状态"""
    ACTIVE = "active"           # 活跃
    IDLE = "idle"               # 空闲
    PAUSED = "paused"           # 暂停
    HIBERNATE = "hibernate"     # 休眠
    SHUTDOWN = "shutdown"       # 关闭


class HibernateReason(Enum):
    """休眠原因"""
    LOW_POWER = "low_power"         # 低电量
    LOW_ACTIVITY = "low_activity"   # 低活动
    SCHEDULED = "scheduled"         # 计划休眠
    MANUAL = "manual"               # 手动休眠
    ERROR = "error"                 # 错误触发
    RESOURCE = "resource"           # 资源不足


@dataclass
class HibernateRecord:
    """休眠记录"""
    id: str
    from_state: SystemState
    to_state: SystemState
    reason: HibernateReason
    timestamp: str
    duration_seconds: Optional[int] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class HibernateStrategy:
    """休眠策略"""
    name: str
    trigger_condition: Dict[str, Any]
    target_state: SystemState
    wake_condition: Optional[Dict[str, Any]] = None
    save_state: bool = True
    notify: bool = True


class HibernateController:
    """艮休眠控制器"""
    
    def __init__(self, name: str = "GEN"):
        self.name = name
        self.binary = "100"  # 艮卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/gen_hibernate")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.hibernate_log_path = self.base_path / "hibernate_log.jsonl"
        self.state_path = self.base_path / "current_state.json"
        
        # 当前状态
        self.current_state = SystemState.ACTIVE
        self.state_lock = threading.Lock()
        
        # 休眠记录
        self.hibernate_history: List[HibernateRecord] = []
        self.active_hibernate: Optional[HibernateRecord] = None
        
        # 休眠策略
        self.strategies: List[HibernateStrategy] = []
        self._load_default_strategies()
        
        # 状态回调
        self.state_callbacks: List[Callable] = []
        
        # 定时器
        self._stop_event = threading.Event()
        self._monitor_thread: Optional[threading.Thread] = None
        
        # 统计
        self.hibernate_count = 0
        self.wake_count = 0
        self.total_hibernate_time = 0
    
    def _load_default_strategies(self) -> None:
        """加载默认休眠策略"""
        default_strategies = [
            HibernateStrategy(
                name="low_power",
                trigger_condition={"battery": "<", "value": 0.2},
                target_state=SystemState.HIBERNATE,
                wake_condition={"battery": ">", "value": 0.5},
                save_state=True,
                notify=True
            ),
            HibernateStrategy(
                name="low_activity",
                trigger_condition={"idle_time": ">", "value": 300},  # 5 分钟
                target_state=SystemState.IDLE,
                wake_condition={"activity": ">", "value": 0},
                save_state=False,
                notify=False
            ),
            HibernateStrategy(
                name="scheduled_night",
                trigger_condition={"hour": "between", "value": [23, 6]},
                target_state=SystemState.HIBERNATE,
                wake_condition={"hour": "between", "value": [6, 8]},
                save_state=True,
                notify=True
            ),
            HibernateStrategy(
                name="resource_low",
                trigger_condition={"memory": ">", "value": 0.9},
                target_state=SystemState.PAUSED,
                wake_condition={"memory": "<", "value": 0.7},
                save_state=True,
                notify=True
            )
        ]
        
        self.strategies = default_strategies
    
    def register_callback(self, callback: Callable) -> None:
        """注册状态变化回调"""
        self.state_callbacks.append(callback)
    
    def get_state(self) -> SystemState:
        """获取当前状态"""
        with self.state_lock:
            return self.current_state
    
    def set_state(self, new_state: SystemState, reason: HibernateReason = HibernateReason.MANUAL) -> bool:
        """
        设置系统状态
        
        Args:
            new_state: 新状态
            reason: 原因
            
        Returns:
            是否成功
        """
        with self.state_lock:
            old_state = self.current_state
            
            if old_state == new_state:
                return True
            
            # 检查状态转换是否合法
            if not self._is_valid_transition(old_state, new_state):
                return False
            
            # 执行状态转换
            if new_state in [SystemState.HIBERNATE, SystemState.PAUSED, SystemState.IDLE]:
                # 休眠前保存状态
                if self._should_save_state(new_state):
                    self._save_state()
                
                # 创建休眠记录
                record = HibernateRecord(
                    id=f"hibernate_{datetime.now().strftime('%Y%m%d%H%M%S')}",
                    from_state=old_state,
                    to_state=new_state,
                    reason=reason,
                    timestamp=datetime.now().isoformat()
                )
                
                self.active_hibernate = record
                self.hibernate_history.append(record)
                self.hibernate_count += 1
                
                # 记录日志
                self._log_hibernate(record)
            
            # 更新状态
            self.current_state = new_state
            
            # 保存状态文件
            self._save_state_file()
            
            # 触发回调
            self._notify_state_change(old_state, new_state, reason)
            
            # 如果是唤醒，记录唤醒
            if new_state == SystemState.ACTIVE and old_state != SystemState.ACTIVE:
                self.wake_count += 1
                if self.active_hibernate:
                    self.active_hibernate.duration_seconds = int(
                        (datetime.now() - datetime.fromisoformat(self.active_hibernate.timestamp)).total_seconds()
                    )
                    self.total_hibernate_time += self.active_hibernate.duration_seconds
                    self.active_hibernate = None
            
            return True
    
    def hibernate(self, reason: HibernateReason = HibernateReason.MANUAL) -> bool:
        """进入休眠"""
        return self.set_state(SystemState.HIBERNATE, reason)
    
    def wake(self) -> bool:
        """唤醒系统"""
        return self.set_state(SystemState.ACTIVE, HibernateReason.MANUAL)
    
    def pause(self, reason: HibernateReason = HibernateReason.MANUAL) -> bool:
        """暂停"""
        return self.set_state(SystemState.PAUSED, reason)
    
    def resume(self) -> bool:
        """恢复"""
        return self.set_state(SystemState.ACTIVE, HibernateReason.MANUAL)
    
    def check_strategies(self, context: Dict[str, Any]) -> Optional[HibernateStrategy]:
        """
        检查休眠策略
        
        Args:
            context: 上下文（电池、活动、时间等）
            
        Returns:
            匹配的策略（如果有）
        """
        for strategy in self.strategies:
            if self._check_condition(strategy.trigger_condition, context):
                return strategy
        
        return None
    
    def auto_manage(self, context: Dict[str, Any]) -> bool:
        """
        自动管理状态
        
        Args:
            context: 上下文
            
        Returns:
            是否触发了状态变化
        """
        strategy = self.check_strategies(context)
        
        if strategy:
            return self.set_state(strategy.target_state, 
                                 self._reason_from_strategy(strategy))
        
        return False
    
    def start_monitor(self, interval: int = 60) -> None:
        """
        启动自动监控
        
        Args:
            interval: 检查间隔（秒）
        """
        def monitor_loop():
            while not self._stop_event.is_set():
                # 获取系统上下文
                context = self._get_system_context()
                
                # 自动管理
                self.auto_manage(context)
                
                # 等待
                self._stop_event.wait(interval)
        
        self._monitor_thread = threading.Thread(target=monitor_loop, daemon=True)
        self._monitor_thread.start()
    
    def stop_monitor(self) -> None:
        """停止监控"""
        self._stop_event.set()
        if self._monitor_thread:
            self._monitor_thread.join(timeout=5)
    
    def get_hibernate_stats(self) -> Dict[str, Any]:
        """获取休眠统计"""
        return {
            "name": self.name,
            "binary": self.binary,
            "current_state": self.current_state.value,
            "hibernate_count": self.hibernate_count,
            "wake_count": self.wake_count,
            "total_hibernate_time_seconds": self.total_hibernate_time,
            "total_hibernate_time_hours": round(self.total_hibernate_time / 3600, 2),
            "active_hibernate": asdict(self.active_hibernate) if self.active_hibernate else None,
            "recent_history": [asdict(r) for r in self.hibernate_history[-5:]]
        }
    
    def _is_valid_transition(self, from_state: SystemState, to_state: SystemState) -> bool:
        """检查状态转换是否合法"""
        valid_transitions = {
            SystemState.ACTIVE: [SystemState.IDLE, SystemState.PAUSED, SystemState.HIBERNATE, SystemState.SHUTDOWN],
            SystemState.IDLE: [SystemState.ACTIVE, SystemState.PAUSED, SystemState.HIBERNATE, SystemState.SHUTDOWN],
            SystemState.PAUSED: [SystemState.ACTIVE, SystemState.HIBERNATE, SystemState.SHUTDOWN],
            SystemState.HIBERNATE: [SystemState.ACTIVE, SystemState.SHUTDOWN],
            SystemState.SHUTDOWN: []  # 关闭后不能转换
        }
        
        return to_state in valid_transitions.get(from_state, [])
    
    def _should_save_state(self, state: SystemState) -> bool:
        """检查是否应该保存状态"""
        for strategy in self.strategies:
            if strategy.target_state == state and strategy.save_state:
                return True
        return state in [SystemState.HIBERNATE, SystemState.SHUTDOWN]
    
    def _check_condition(self, condition: Dict[str, Any], context: Dict[str, Any]) -> bool:
        """检查条件是否满足"""
        if not condition:
            return False
        
        key = condition.get("key")
        operator = condition.get("operator")
        value = condition.get("value")
        
        if key not in context:
            return False
        
        context_value = context[key]
        
        if operator == "<":
            return context_value < value
        elif operator == ">":
            return context_value > value
        elif operator == "==":
            return context_value == value
        elif operator == "between":
            return value[0] <= context_value <= value[1]
        elif operator == ">=":
            return context_value >= value
        elif operator == "<=":
            return context_value <= value
        
        return False
    
    def _reason_from_strategy(self, strategy: HibernateStrategy) -> HibernateReason:
        """从策略获取原因"""
        reason_map = {
            "low_power": HibernateReason.LOW_POWER,
            "low_activity": HibernateReason.LOW_ACTIVITY,
            "scheduled_night": HibernateReason.SCHEDULED,
            "resource_low": HibernateReason.RESOURCE
        }
        
        return reason_map.get(strategy.name, HibernateReason.MANUAL)
    
    def _get_system_context(self) -> Dict[str, Any]:
        """获取系统上下文"""
        # 这里可以集成实际的系统监控
        return {
            "battery": 0.8,  # 示例值
            "idle_time": 0,
            "hour": datetime.now().hour,
            "memory": 0.6,
            "activity": 1
        }
    
    def _save_state(self) -> None:
        """保存当前状态"""
        # 保存需要休眠的状态数据
        pass
    
    def _save_state_file(self) -> None:
        """保存状态文件"""
        state_data = {
            "current_state": self.current_state.value,
            "timestamp": datetime.now().isoformat(),
            "hibernate_count": self.hibernate_count,
            "wake_count": self.wake_count
        }
        
        with open(self.state_path, "w") as f:
            json.dump(state_data, f, indent=2, ensure_ascii=False)
    
    def _notify_state_change(self, old_state: SystemState, new_state: SystemState, 
                            reason: HibernateReason) -> None:
        """通知状态变化"""
        for callback in self.state_callbacks:
            try:
                callback(old_state, new_state, reason)
            except:
                pass
    
    def _log_hibernate(self, record: HibernateRecord) -> None:
        """记录休眠日志"""
        with open(self.hibernate_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☶ 艮休眠控制器 测试")
    print("=" * 60)
    
    controller = HibernateController()
    
    # 测试 1：状态转换
    print("\n📝 测试 1：状态转换")
    print(f"   初始状态: {controller.get_state().value}")
    
    controller.hibernate(HibernateReason.MANUAL)
    print(f"   休眠后: {controller.get_state().value}")
    
    controller.wake()
    print(f"   唤醒后: {controller.get_state().value}")
    
    # 测试 2：检查策略
    print("\n📝 测试 2：检查休眠策略")
    context = {"battery": 0.15, "hour": 2, "idle_time": 600, "memory": 0.85}
    strategy = controller.check_strategies(context)
    if strategy:
        print(f"   匹配策略: {strategy.name} → {strategy.target_state.value}")
    else:
        print("   无匹配策略")
    
    # 测试 3：自动管理
    print("\n📝 测试 3：自动管理")
    context = {"battery": 0.1, "hour": 3, "idle_time": 1000, "memory": 0.95}
    changed = controller.auto_manage(context)
    print(f"   状态变化: {changed}")
    print(f"   当前状态: {controller.get_state().value}")
    
    # 测试 4：获取统计
    print("\n📝 测试 4：获取休眠统计")
    stats = controller.get_hibernate_stats()
    print(f"   休眠次数: {stats['hibernate_count']}")
    print(f"   唤醒次数: {stats['wake_count']}")
    print(f"   当前状态: {stats['current_state']}")
    
    print("\n✅ 艮休眠控制器测试完成")
