#!/usr/bin/env python3
"""
统一通知层 v1.0

融合目标：星核自循环 → 我 → 你

通知流程：
┌─────────────────────────────────────────────────────────────┐
│                    统一通知层                                 │
│  ┌─────────────┐                                            │
│  │ 星核自循环  │                                            │
│  │ 检测到事件  │                                            │
│  └──────┬──────┘                                            │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              EventAggregator (事件聚合器)               │   │
│  │  - 过滤：只通知重要事件                                │   │
│  │  - 聚合：相似事件合并                                  │   │
│  │  - 优先级：critical > warning > info                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ↓                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              NotificationFormatter (通知格式化器)       │   │
│  │  转换为自然语言：                                      │   │
│  │  - 状态变化 → "星核状态已更新：..."                    │   │
│  │  - 问题检测 → "⚠️ 检测到问题：..."                     │   │
│  │  - 决策完成 → "星核已完成决策：..."                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                         ↓                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    我 (SenseNova)                     │   │
│  │  你通过我接收通知                                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

通知类型：
1. 状态变化：daemon/CycleSystem/iOS Controller 状态变更
2. 问题检测：能量过低、熵值异常、服务不可用
3. 决策完成：自循环完成一轮决策
4. 阿腾校准：检测到迷茫并自动校准
5. 执行结果：工具执行完成
"""

import json
import time
import threading
import subprocess
import sqlite3
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path

# ==================== 事件类型 ====================

class EventType(Enum):
    STATUS_CHANGE = "status_change"
    PROBLEM_DETECTED = "problem_detected"
    DECISION_COMPLETED = "decision_completed"
    ATENG_CALIBRATION = "ateng_calibration"
    EXECUTION_RESULT = "execution_result"
    SELF_CYCLE_COMPLETED = "self_cycle_completed"

class Priority(Enum):
    CRITICAL = "critical"  # 立即通知
    WARNING = "warning"    # 重要，尽快通知
    INFO = "info"          # 普通，批量通知

# ==================== 事件 ====================

@dataclass
class FusionEvent:
    """融合事件"""
    event_id: str
    event_type: EventType
    priority: Priority
    timestamp: str
    source: str
    title: str
    message: str
    details: Dict = field(default_factory=dict)
    acknowledged: bool = False

# ==================== 事件聚合器 ====================

class EventAggregator:
    """事件聚合器"""
    
    def __init__(self):
        self.pending_events: List[FusionEvent] = []
        self.notified_events: List[FusionEvent] = []
        self.event_history: List[FusionEvent] = []
        self.max_history = 100
        self._lock = threading.Lock()
    
    def add_event(self, event: FusionEvent):
        """添加事件"""
        with self._lock:
            self.pending_events.append(event)
            self.event_history.append(event)
            if len(self.event_history) > self.max_history:
                self.event_history = self.event_history[-self.max_history:]
    
    def get_pending(self, priority: Priority = None) -> List[FusionEvent]:
        """获取待通知事件"""
        with self._lock:
            events = self.pending_events.copy()
            if priority:
                events = [e for e in events if e.priority == priority]
            return events
    
    def mark_notified(self, event_id: str):
        """标记已通知"""
        with self._lock:
            for event in self.pending_events:
                if event.event_id == event_id:
                    event.acknowledged = True
                    self.notified_events.append(event)
                    self.pending_events.remove(event)
                    break
    
    def clear_pending(self):
        """清除待通知事件"""
        with self._lock:
            self.notified_events.extend(self.pending_events)
            self.pending_events.clear()

# ==================== 通知格式化器 ====================

class NotificationFormatter:
    """通知格式化器"""
    
    @staticmethod
    def format(event: FusionEvent) -> str:
        """格式化为自然语言"""
        if event.event_type == EventType.STATUS_CHANGE:
            return f"📊 星核状态更新：{event.message}"
        
        elif event.event_type == EventType.PROBLEM_DETECTED:
            priority_icon = "🚨" if event.priority == Priority.CRITICAL else "⚠️"
            return f"{priority_icon} 检测到问题：{event.message}"
        
        elif event.event_type == EventType.DECISION_COMPLETED:
            return f"🧠 星核决策完成：{event.message}"
        
        elif event.event_type == EventType.ATENG_CALIBRATION:
            return f"📌 阿腾校准：{event.message}"
        
        elif event.event_type == EventType.SELF_CYCLE_COMPLETED:
            return f"🔄 自循环完成：{event.message}"
        
        elif event.event_type == EventType.EXECUTION_RESULT:
            icon = "✅" if event.details.get("success") else "❌"
            return f"{icon} 执行结果：{event.message}"
        
        return f"📢 {event.message}"
    
    @staticmethod
    def format_batch(events: List[FusionEvent]) -> str:
        """批量格式化"""
        if not events:
            return "暂无新通知"
        
        lines = [f"📢 收到 {len(events)} 条通知：", ""]
        for event in events:
            lines.append(f"  {NotificationFormatter.format(event)}")
        
        return "\n".join(lines)

# ==================== 通知监听器 ====================

class NotificationListener:
    """通知监听器"""
    
    def __init__(self, aggregator: EventAggregator):
        self.aggregator = aggregator
        self.callbacks: List[Callable] = []
    
    def register_callback(self, callback: Callable):
        """注册回调"""
        self.callbacks.append(callback)
    
    def notify(self, event: FusionEvent):
        """通知所有回调"""
        formatted = NotificationFormatter.format(event)
        for callback in self.callbacks:
            try:
                callback(event, formatted)
            except Exception as e:
                print(f"Callback error: {e}")

# ==================== 统一通知引擎 ====================

class UnifiedNotifier:
    """统一通知引擎"""
    
    def __init__(self):
        self.aggregator = EventAggregator()
        self.listener = NotificationListener(self.aggregator)
        self.running = False
        self._check_thread: Optional[threading.Thread] = None
        
        # 加载统一记忆层
        from unified_memory import UnifiedMemory
        self.memory = UnifiedMemory()
    
    def start_monitoring(self, interval: int = 30):
        """启动监控（后台线程）"""
        if self.running:
            return
        
        self.running = True
        
        def monitor_loop():
            last_cycle_count = 0
            last_decision_count = 0
            
            while self.running:
                try:
                    # 检查自循环
                    self._check_self_cycle(last_cycle_count)
                    
                    # 检查决策
                    self._check_decisions(last_decision_count)
                    
                    # 检查系统状态
                    self._check_system_state()
                    
                    # 更新计数器
                    conn = sqlite3.connect("/home/ubuntu/starcore/data/decisions.db")
                    cursor = conn.cursor()
                    cursor.execute("SELECT COUNT(*) FROM decisions")
                    last_decision_count = cursor.fetchone()[0]
                    conn.close()
                    
                    # 等待
                    for _ in range(interval):
                        if not self.running:
                            break
                        time.sleep(1)
                        
                except Exception as e:
                    print(f"Monitor error: {e}")
                    time.sleep(5)
        
        self._check_thread = threading.Thread(target=monitor_loop, daemon=True)
        self._check_thread.start()
        
        print("✅ 统一通知引擎已启动")
    
    def stop_monitoring(self):
        """停止监控"""
        self.running = False
        if self._check_thread:
            self._check_thread.join(timeout=5)
        print("🛑 统一通知引擎已停止")
    
    def _check_self_cycle(self, last_count: int):
        """检查自循环"""
        log_file = "/home/ubuntu/starcore/data/self_cycle_log.jsonl"
        try:
            with open(log_file) as f:
                lines = f.readlines()
                current_count = len(lines)
            
            if current_count > last_count:
                # 有新循环
                new_cycles = current_count - last_count
                self._add_event(FusionEvent(
                    event_id=f"cycle_{datetime.now().isoformat()}",
                    event_type=EventType.SELF_CYCLE_COMPLETED,
                    priority=Priority.INFO,
                    timestamp=datetime.now().isoformat(),
                    source="self_cycle_engine",
                    title=f"自循环完成 {new_cycles} 轮",
                    message=f"星核自循环已完成 {new_cycles} 轮",
                    details={"cycles": new_cycles}
                ))
        except Exception:
            pass
    
    def _check_decisions(self, last_count: int):
        """检查决策"""
        try:
            conn = sqlite3.connect("/home/ubuntu/starcore/data/decisions.db")
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM decisions")
            current_count = cursor.fetchone()[0]
            conn.close()
            
            if current_count > last_count:
                new_decisions = current_count - last_count
                self._add_event(FusionEvent(
                    event_id=f"decision_{datetime.now().isoformat()}",
                    event_type=EventType.DECISION_COMPLETED,
                    priority=Priority.INFO,
                    timestamp=datetime.now().isoformat(),
                    source="starcore",
                    title=f"新决策 {new_decisions} 条",
                    message=f"星核已完成 {new_decisions} 条新决策",
                    details={"decisions": new_decisions}
                ))
        except Exception:
            pass
    
    def _check_system_state(self):
        """检查系统状态"""
        def _curl(url: str):
            try:
                result = subprocess.run(
                    ["curl", "-s", "--connect-timeout", "2", url],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0 and result.stdout:
                    return json.loads(result.stdout)
            except Exception:
                return None
        
        daemon = _curl("http://localhost:9090/health")
        cycle = _curl("http://localhost:9092/state")
        controller = _curl("http://localhost:9091/health")
        
        # 检查问题
        if not daemon:
            self._add_event(FusionEvent(
                event_id=f"problem_daemon_{datetime.now().isoformat()}",
                event_type=EventType.PROBLEM_DETECTED,
                priority=Priority.CRITICAL,
                timestamp=datetime.now().isoformat(),
                source="monitor",
                title="daemon 不可用",
                message="daemon 服务不可用，请检查",
                details={"component": "daemon"}
            ))
        
        if cycle:
            energy = cycle.get("energy", {}).get("cognitive", 0)
            if energy < 20:
                self._add_event(FusionEvent(
                    event_id=f"problem_energy_{datetime.now().isoformat()}",
                    event_type=EventType.PROBLEM_DETECTED,
                    priority=Priority.WARNING,
                    timestamp=datetime.now().isoformat(),
                    source="monitor",
                    title="认知能量过低",
                    message=f"认知能量仅 {energy:.1f}%，建议减少任务或休息",
                    details={"energy": energy}
                ))
            
            entropy = cycle.get("entropy", {}).get("value", 0)
            if entropy > 0.6:
                self._add_event(FusionEvent(
                    event_id=f"problem_entropy_{datetime.now().isoformat()}",
                    event_type=EventType.PROBLEM_DETECTED,
                    priority=Priority.WARNING,
                    timestamp=datetime.now().isoformat(),
                    source="monitor",
                    title="熵值过高（混乱）",
                    message=f"熵值 {entropy:.2f}，系统需要收敛",
                    details={"entropy": entropy}
                ))
    
    def _add_event(self, event: FusionEvent):
        """添加事件"""
        self.aggregator.add_event(event)
        self.listener.notify(event)
    
    def get_notifications(self, priority: Priority = None, limit: int = 10) -> List[Dict]:
        """获取通知"""
        events = self.aggregator.get_pending(priority)
        return [
            {
                "event_id": e.event_id,
                "type": e.event_type.value,
                "priority": e.priority.value,
                "timestamp": e.timestamp,
                "title": e.title,
                "message": e.message,
                "formatted": NotificationFormatter.format(e)
            }
            for e in events[:limit]
        ]
    
    def get_all_notifications(self, limit: int = 20) -> List[Dict]:
        """获取所有通知（包括已通知的）"""
        events = self.aggregator.event_history[-limit:]
        return [
            {
                "event_id": e.event_id,
                "type": e.event_type.value,
                "priority": e.priority.value,
                "timestamp": e.timestamp,
                "title": e.title,
                "message": e.message,
                "acknowledged": e.acknowledged,
                "formatted": NotificationFormatter.format(e)
            }
            for e in events
        ]

# ==================== 主程序 ====================

if __name__ == "__main__":
    notifier = UnifiedNotifier()
    
    print("=" * 60)
    print("🔔 统一通知层 v1.0 已初始化")
    print("=" * 60)
    
    # 测试添加事件
    print("\n📝 测试添加事件...")
    
    notifier._add_event(FusionEvent(
        event_id="test_1",
        event_type=EventType.STATUS_CHANGE,
        priority=Priority.INFO,
        timestamp=datetime.now().isoformat(),
        source="test",
        title="测试状态更新",
        message="这是一个测试通知"
    ))
    
    notifier._add_event(FusionEvent(
        event_id="test_2",
        event_type=EventType.PROBLEM_DETECTED,
        priority=Priority.WARNING,
        timestamp=datetime.now().isoformat(),
        source="test",
        title="测试问题检测",
        message="认知能量偏低，请注意"
    ))
    
    # 获取通知
    print("\n📋 当前通知：")
    notifications = notifier.get_all_notifications()
    for n in notifications:
        print(f"  [{n['priority']}] {n['formatted']}")
    
    print("\n✅ 统一通知层就绪")
    print("\n💡 提示：start_monitoring() 启动后台监控，stop_monitoring() 停止")
