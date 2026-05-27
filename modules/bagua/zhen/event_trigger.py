"""
震 ☳ 事件触发器 (Event Trigger)
================================
八卦之三，动，代表触发与响应能力。

功能：
- 事件检测与分类
- 触发条件匹配
- 响应动作执行
- 事件日志记录

卦象：震 ☳ (001) - 雷，动
属性：动、触发、响应、快速
"""

import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import threading


class EventType(Enum):
    """事件类型"""
    HARDWARE = "hardware"      # 硬件事件
    SYSTEM = "system"          # 系统事件
    USER = "user"              # 用户事件
    EXTERNAL = "external"      # 外部事件
    GUA_CHANGE = "gua_change"  # 卦变事件
    CYCLE = "cycle"            # 循环事件


class EventPriority(Enum):
    """事件优先级"""
    CRITICAL = "critical"  # 紧急
    HIGH = "high"          # 高
    NORMAL = "normal"      # 正常
    LOW = "low"            # 低


@dataclass
class Event:
    """事件对象"""
    id: str
    type: EventType
    priority: EventPriority
    source: str
    data: Dict[str, Any]
    timestamp: str
    processed: bool = False
    response: Optional[str] = None


@dataclass
class TriggerRule:
    """触发规则"""
    id: str
    name: str
    event_type: EventType
    condition: Dict[str, Any]
    action: str
    enabled: bool = True


class EventTrigger:
    """震事件触发器"""
    
    def __init__(self, name: str = "ZHEN"):
        self.name = name
        self.binary = "001"  # 震卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/zhen_trigger")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.event_log_path = self.base_path / "event_log.jsonl"
        self.trigger_log_path = self.base_path / "trigger_log.jsonl"
        
        # 事件队列
        self.event_queue: List[Event] = []
        self.queue_lock = threading.Lock()
        
        # 触发规则
        self.trigger_rules: List[TriggerRule] = []
        self._load_default_rules()
        
        # 事件处理器映射
        self.handlers: Dict[EventType, Callable] = {}
        
        # 统计
        self.event_count = 0
        self.trigger_count = 0
    
    def register_handler(self, event_type: EventType, handler: Callable) -> None:
        """注册事件处理器"""
        self.handlers[event_type] = handler
    
    def detect_event(self, event_type: EventType, source: str, data: Dict[str, Any], 
                     priority: EventPriority = EventPriority.NORMAL) -> Event:
        """
        检测并创建事件
        
        Args:
            event_type: 事件类型
            source: 事件来源
            data: 事件数据
            priority: 优先级
            
        Returns:
            事件对象
        """
        event_id = f"{event_type.value}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.event_queue)}"
        
        event = Event(
            id=event_id,
            type=event_type,
            priority=priority,
            source=source,
            data=data,
            timestamp=datetime.now().isoformat()
        )
        
        # 加入队列
        with self.queue_lock:
            self.event_queue.append(event)
        
        self.event_count += 1
        
        # 记录事件日志
        self._log_event(event)
        
        return event
    
    def check_triggers(self, event: Event) -> List[str]:
        """
        检查触发规则
        
        Args:
            event: 事件对象
            
        Returns:
            触发的动作列表
        """
        triggered_actions = []
        
        for rule in self.trigger_rules:
            if not rule.enabled:
                continue
            
            # 检查事件类型匹配
            if rule.event_type != event.type:
                continue
            
            # 检查条件匹配
            if self._check_condition(rule.condition, event.data):
                triggered_actions.append(rule.action)
                self.trigger_count += 1
                
                # 记录触发日志
                self._log_trigger(rule, event)
        
        return triggered_actions
    
    def execute_response(self, event: Event, actions: List[str]) -> Dict[str, Any]:
        """
        执行响应动作
        
        Args:
            event: 事件对象
            actions: 动作列表
            
        Returns:
            执行结果
        """
        results = []
        
        for action in actions:
            result = {
                "action": action,
                "event_id": event.id,
                "timestamp": datetime.now().isoformat(),
                "status": "executed"
            }
            results.append(result)
            
            # 更新事件状态
            event.processed = True
            event.response = action
        
        # 记录执行结果
        self._log_execution(event, results)
        
        return {"event_id": event.id, "results": results}
    
    def process_event(self, event: Event) -> Dict[str, Any]:
        """
        完整处理事件（检测→触发→执行）
        
        Args:
            event: 事件对象
            
        Returns:
            处理结果
        """
        # 1. 检查触发规则
        actions = self.check_triggers(event)
        
        # 2. 执行响应
        if actions:
            return self.execute_response(event, actions)
        else:
            return {
                "event_id": event.id,
                "status": "no_trigger",
                "message": "无匹配的触发规则"
            }
    
    def get_pending_events(self, priority: Optional[EventPriority] = None) -> List[Event]:
        """获取待处理事件"""
        with self.queue_lock:
            events = [e for e in self.event_queue if not e.processed]
        
        if priority:
            events = [e for e in events if e.priority == priority]
        
        # 按优先级排序
        priority_order = {EventPriority.CRITICAL: 0, EventPriority.HIGH: 1, 
                         EventPriority.NORMAL: 2, EventPriority.LOW: 3}
        events.sort(key=lambda e: priority_order[e.priority])
        
        return events
    
    def get_status(self) -> Dict[str, Any]:
        """获取触发器状态"""
        return {
            "name": self.name,
            "binary": self.binary,
            "event_count": self.event_count,
            "trigger_count": self.trigger_count,
            "pending_events": len(self.get_pending_events()),
            "rules_count": len(self.trigger_rules),
            "handlers_count": len(self.handlers)
        }
    
    def _load_default_rules(self) -> None:
        """加载默认触发规则"""
        default_rules = [
            TriggerRule(
                id="RULE_001",
                name="CPU高负载触发",
                event_type=EventType.HARDWARE,
                condition={"key": "cpu_load", "operator": ">", "value": 0.8},
                action="optimize_performance"
            ),
            TriggerRule(
                id="RULE_002",
                name="电池低电量触发",
                event_type=EventType.HARDWARE,
                condition={"key": "battery", "operator": "<", "value": 0.2},
                action="enter_power_save"
            ),
            TriggerRule(
                id="RULE_003",
                name="卦变触发",
                event_type=EventType.GUA_CHANGE,
                condition={"key": "change_type", "operator": "==", "value": "major"},
                action="recalculate_strategy"
            ),
            TriggerRule(
                id="RULE_004",
                name="循环完成触发",
                event_type=EventType.CYCLE,
                condition={"key": "cycle_complete", "operator": "==", "value": True},
                action="save_snapshot"
            ),
            TriggerRule(
                id="RULE_005",
                name="用户指令触发",
                event_type=EventType.USER,
                condition={"key": "command", "operator": "in", "value": ["start", "stop", "reset"]},
                action="execute_command"
            )
        ]
        
        self.trigger_rules = default_rules
    
    def _check_condition(self, condition: Dict[str, Any], data: Dict[str, Any]) -> bool:
        """检查条件是否匹配"""
        key = condition.get("key")
        operator = condition.get("operator")
        value = condition.get("value")
        
        if key not in data:
            return False
        
        data_value = data[key]
        
        if operator == ">":
            return data_value > value
        elif operator == "<":
            return data_value < value
        elif operator == "==":
            return data_value == value
        elif operator == ">=":
            return data_value >= value
        elif operator == "<=":
            return data_value <= value
        elif operator == "in":
            return data_value in value
        
        return False
    
    def _log_event(self, event: Event) -> None:
        """记录事件日志"""
        with open(self.event_log_path, "a") as f:
            f.write(json.dumps(asdict(event), default=str, ensure_ascii=False) + "\n")
    
    def _log_trigger(self, rule: TriggerRule, event: Event) -> None:
        """记录触发日志"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "rule_id": rule.id,
            "rule_name": rule.name,
            "event_id": event.id,
            "event_type": event.type.value,
            "action": rule.action
        }
        
        with open(self.trigger_log_path, "a") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
    
    def _log_execution(self, event: Event, results: List[Dict]) -> None:
        """记录执行日志"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "event_id": event.id,
            "event_type": event.type.value,
            "results": results
        }
        
        with open(self.event_log_path, "a") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("⚡ 震事件触发器 测试")
    print("=" * 60)
    
    trigger = EventTrigger()
    
    # 测试1：检测硬件事件
    print("\n📝 测试1：检测硬件事件 (CPU高负载)")
    event = trigger.detect_event(
        event_type=EventType.HARDWARE,
        source="system_monitor",
        data={"cpu_load": 0.85, "memory": 0.7},
        priority=EventPriority.HIGH
    )
    print(f"   事件ID: {event.id}")
    print(f"   类型: {event.type.value}")
    print(f"   优先级: {event.priority.value}")
    
    # 测试2：检查触发规则
    print("\n📝 测试2：检查触发规则")
    actions = trigger.check_triggers(event)
    print(f"   触发动作: {actions}")
    
    # 测试3：完整处理事件
    print("\n📝 测试3：完整处理事件")
    result = trigger.process_event(event)
    print(f"   状态: {result.get('status')}")
    if "results" in result:
        print(f"   执行结果: {result['results']}")
    
    # 测试4：检测卦变事件
    print("\n📝 测试4：检测卦变事件")
    gua_event = trigger.detect_event(
        event_type=EventType.GUA_CHANGE,
        source="gua_engine",
        data={"change_type": "major", "from_gua": "QIAN", "to_gua": "KUN"},
        priority=EventPriority.CRITICAL
    )
    actions = trigger.check_triggers(gua_event)
    print(f"   触发动作: {actions}")
    
    # 获取状态
    print("\n📊 触发器状态:")
    status = trigger.get_status()
    print(f"   事件数: {status['event_count']}")
    print(f"   触发数: {status['trigger_count']}")
    print(f"   规则数: {status['rules_count']}")
    
    print("\n✅ 震事件触发器测试完成")
