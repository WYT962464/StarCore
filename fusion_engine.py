#!/usr/bin/env python3
"""
星核融合引擎 v1.0

四元融合：用户 + 我(SenseNova) + 星核系统 + Hermes

统一接口：
┌─────────────────────────────────────────────────────────────┐
│                    融合引擎 (FusionEngine)                     │
│                                                               │
│  你只需要跟我对话，剩下的我来协调：                             │
│                                                               │
│  1. 统一记忆层 (UnifiedMemory)                                 │
│     - 我的 memory + 星核决策数据库 + 自循环日志                 │
│     - save(), get(), search(), get_stats()                   │
│                                                               │
│  2. 统一路由层 (UnifiedRouter)                                 │
│     - 你的指令 → 自动路由到星核/Hermes/直接回答                 │
│     - route(message) → {route, result, explain}              │
│                                                               │
│  3. 统一通知层 (UnifiedNotifier)                               │
│     - 星核自循环结果 → 通过我通知你                            │
│     - start_monitoring(), get_notifications()                │
│                                                               │
│  4. 对话桥接层 (DialogueBridge)                                │
│     - 自然语言 → 星核 API                                      │
│     - chat(message) → 翻译解释后的响应                         │
└─────────────────────────────────────────────────────────────┘

使用方式：
    from fusion_engine import FusionEngine
    
    engine = FusionEngine()
    
    # 对话
    result = engine.chat("星核现在什么状态？")
    
    # 查询
    state = engine.get_state()
    
    # 获取通知
    notifications = engine.get_notifications()
    
    # 启动监控
    engine.start_monitoring()
"""

import json
import threading
from datetime import datetime
from typing import Dict, List, Optional, Any

# 导入各层
from unified_memory import UnifiedMemory
from unified_router import UnifiedRouter, RouteTarget
from unified_notifier import UnifiedNotifier, FusionEvent, EventType, Priority, NotificationFormatter

# Phase 5: 六十四卦集成
try:
    from phase5_gua_integration import GuaIntegration, FusionGuaBridge, GuaTriggerSource
    GUAINTEGRATION_AVAILABLE = True
except ImportError:
    GUAINTEGRATION_AVAILABLE = False
    print("⚠️ 六十四卦集成模块未找到，功能受限")

# 三位一体决策框架
try:
    from three_sages_framework import ThreeSagesFramework, ThreeSagesDecision
    THREE_SAGES_AVAILABLE = True
except ImportError:
    THREE_SAGES_AVAILABLE = False
    print("⚠️ 三位一体决策框架未找到，功能受限")

class FusionEngine:
    """融合引擎"""
    
    def __init__(self):
        self.memory = UnifiedMemory()
        self.router = UnifiedRouter()
        self.notifier = UnifiedNotifier()
        self.running = False
        
        # Phase 5: 六十四卦集成
        if GUAINTEGRATION_AVAILABLE:
            self.gua = GuaIntegration()
            self.gua_bridge = FusionGuaBridge(fusion_engine=self, gua_integration=self.gua)
            print("✅ 六十四卦集成：已启用")
        else:
            self.gua = None
            self.gua_bridge = None
            print("⚠️ 六十四卦集成：不可用")
        
        # 三位一体决策框架
        if THREE_SAGES_AVAILABLE:
            self.three_sages = ThreeSagesFramework()
            print("✅ 三位一体决策框架：已启用")
        else:
            self.three_sages = None
            print("⚠️ 三位一体决策框架：不可用")
        
        print("✅ 融合引擎 v1.0 已初始化")
        print(f"   统一记忆：{self.memory.get_stats()}")
    
    def chat(self, message: str) -> Dict:
        """
        对话入口
        
        你只需要说自然语言，我自动：
        1. 路由到正确目标
        2. 执行操作
        3. 解释结果
        
        返回：{"route": ..., "result": ..., "explain": ..., "response": ...}
        """
        # 1. 路由
        route_result = self.router.route(message)
        
        # 2. 生成响应
        response = self._generate_response(route_result)
        
        # 3. 保存对话记录
        self.memory.save(
            key=f"conversation_{datetime.now().isoformat()}",
            value={
                "user_message": message,
                "route": route_result["route"],
                "response": response
            },
            source="fusion",
            category="conversation"
        )
        
        return {
            "timestamp": datetime.now().isoformat(),
            "user_message": message,
            "route": route_result["route"],
            "result": route_result["result"],
            "explain": route_result["explain"],
            "response": response
        }
    
    def _generate_response(self, route_result: Dict) -> str:
        """生成自然语言响应"""
        route = route_result["route"]
        result = route_result["result"]
        
        if route["target"] == "starcore":
            action = route["action"]
            
            if action == "status":
                components = result.get("components", {})
                lines = ["📊 星核系统状态：", ""]
                
                daemon = components.get("daemon")
                lines.append(f"  daemon: {'✅' if daemon else '❌'}")
                
                cycle = components.get("cycle_system")
                if cycle:
                    energy = cycle.get("energy", {}).get("cognitive", 0)
                    entropy = cycle.get("entropy", {}).get("value", 0)
                    icon = "✅" if energy > 30 else "⚠️"
                    lines.append(f"  CycleSystem: {icon} 卦象 {cycle.get('hexagram')}, 能量 {energy:.1f}%, 熵 {entropy:.2f}")
                else:
                    lines.append(f"  CycleSystem: ❌")
                
                controller = components.get("ios_controller")
                lines.append(f"  iOS Controller: {'✅' if controller else '❌'}")
                
                return "\n".join(lines)
            
            elif action == "decisions":
                decisions = result.get("decisions", [])
                lines = ["📝 星核最近决策：", ""]
                for d in decisions[:5]:
                    conf = d.get("confidence", 0)
                    icon = "✅" if conf > 0.6 else "⚠️" if conf > 0.4 else "❌"
                    ts = d.get("timestamp", "")[-12:] if d.get("timestamp") else "N/A"
                    lines.append(f"  {ts} | {icon} {d.get('decision', 'N/A')[:30]} (置信度 {conf:.2f})")
                return "\n".join(lines)
            
            elif action == "energy":
                cognitive = result.get("cognitive", 0)
                physical = result.get("physical", 0)
                lines = ["⚡ 星核能量状态：", ""]
                lines.append(f"  物理能量: {physical:.1f}%")
                lines.append(f"  认知能量: {cognitive:.1f}%")
                if cognitive < 30:
                    lines.append("  📉 认知能量偏低，建议减少任务")
                return "\n".join(lines)
            
            elif action == "restart":
                return f"✅ 已发送重启 {route['params'].get('target', 'cycle')} 的命令"
            
            elif action == "calibrate":
                cal = result.get("ateng_calibration", {})
                lines = ["🧭 阿腾认知校准：", ""]
                lines.append(f"  三层框架: {cal.get('三层框架', 'N/A')}")
                lines.append(f"  校准建议: {cal.get('校准建议', '无')}")
                return "\n".join(lines)
            
            elif action == "three_sages":
                ts_result = self.three_sages.get_status() if self.three_sages else None
                if ts_result:
                    lines = ["🧭 三位一体状态：", ""]
                    lines.append(f"  当前焦点: {ts_result['state']['current_sage_focus']}")
                    lines.append(f"  决策数: {ts_result['state']['decision_count']}")
                    lines.append(f"  口诀: {self.get_sage_motto()[:50]}...")
                    return "\n".join(lines)
                return "三位一体框架未启用"
            
            elif action == "assess":
                assessment = self.assess_three_sages()
                lines = ["📊 三位一体评估：", ""]
                if "assessments" in assessment:
                    for a in assessment["assessments"]:
                        lines.append(f"  {a['dimension']}: {a['score']:.2f} ({a['status']})")
                return "\n".join(lines)
            
            elif action == "decide":
                decision = self.decide_three_sages({"task_type": "general"})
                lines = ["🧭 三位一体决策：", ""]
                lines.append(f"  主要智者: {decision.get('primary_sage', 'N/A')}")
                lines.append(f"  决策: {decision.get('decision', 'N/A')}")
                lines.append(f"  建议卦象: {decision.get('next_gua', 'N/A')}")
                return "\n".join(lines)
            
            else:
                return f"已执行星核操作：{action}"
        
        elif route["target"] == "dialogue":
            return result.get("response", "已处理")
        
        elif route["target"] == "direct":
            return result.get("response", "已处理")
        
        return f"已路由到 {route['target']}"
    
    def get_state(self) -> Dict:
        """获取融合系统状态"""
        state = {
            "timestamp": datetime.now().isoformat(),
            "memory_stats": self.memory.get_stats(),
            "system_state": self.memory.get_system_state(),
            "fusion_status": {
                "version": "1.0",
                "layers": {
                    "memory": "active",
                    "router": "active",
                    "notifier": "active" if self.running else "inactive"
                }
            }
        }
        
        # Phase 5: 六十四卦状态
        if self.gua:
            state["gua_integration"] = self.gua.get_status()
        
        # 三位一体状态
        if self.three_sages:
            state["three_sages"] = self.three_sages.get_status()
        
        return state
    
    def get_notifications(self, limit: int = 10) -> List[Dict]:
        """获取通知"""
        return self.notifier.get_all_notifications(limit=limit)
    
    def start_monitoring(self, interval: int = 30):
        """启动后台监控"""
        self.notifier.start_monitoring(interval=interval)
        self.running = True
        
        # 注册回调，通过我接收通知
        def on_notify(event: FusionEvent, formatted: str):
            # 保存通知到记忆
            self.memory.save(
                key=f"notification_{event.event_id}",
                value={
                    "event_id": event.event_id,
                    "type": event.event_type.value,
                    "priority": event.priority.value,
                    "title": event.title,
                    "message": event.message,
                    "formatted": formatted
                },
                source="fusion",
                category="notification"
            )
        
        self.notifier.listener.register_callback(on_notify)
    
    def stop_monitoring(self):
        """停止监控"""
        self.notifier.stop_monitoring()
        self.running = False
    
    
    # ==================== 三位一体方法 ====================
    
    def assess_three_sages(self, context: Dict = None) -> Dict:
        """三位一体评估"""
        if self.three_sages:
            return self.three_sages.assess(context or {})
        return {"error": "三位一体框架未启用"}
    
    def decide_three_sages(self, context: Dict = None, options: List[str] = None) -> Dict:
        """三位一体决策"""
        if self.three_sages:
            result = self.three_sages.decide(context or {}, options or [])
            return {
                "decision_id": result.decision_id,
                "primary_sage": result.primary_sage,
                "decision": result.decision,
                "rationale": result.rationale,
                "priority": result.priority,
                "next_gua": result.next_gua,
                "assessments": result.assessments
            }
        return {"error": "三位一体框架未启用"}
    
    def get_three_sages_status(self) -> Dict:
        """获取三位一体状态"""
        if self.three_sages:
            return self.three_sages.get_status()
        return {"error": "三位一体框架未启用"}
    
    def get_sage_motto(self, sage: str = "integrated") -> str:
        """获取智者口诀"""
        if self.three_sages:
            return self.three_sages.get_sage_motto(sage)
        return "未知智者"

# ==================== Phase 5: 六十四卦方法 ====================
    
    def get_gua_status(self) -> Dict:
        """获取六十四卦状态"""
        if self.gua:
            return self.gua.get_status()
        return {"error": "六十四卦集成未启用"}
    
    def run_gua_cycle(self, input_data: Dict = None) -> Dict:
        """运行六环节闭环"""
        if self.gua:
            result = self.gua.run_cycle(input_data)
            return result.to_dict()
        return {"error": "六十四卦集成未启用"}
    
    def get_gua_decision(self, context: Dict = None) -> Dict:
        """获取卦象决策建议"""
        if self.gua:
            return self.gua.get_decision_suggestion(context)
        return {"error": "六十四卦集成未启用"}
    
    def start_gua_auto_cycle(self, interval: int = 60) -> Dict:
        """启动六环节自动循环"""
        if self.gua:
            return self.gua.start_auto_cycle(interval)
        return {"error": "六十四卦集成未启用"}
    
    def stop_gua_auto_cycle(self) -> Dict:
        """停止六环节自动循环"""
        if self.gua:
            return self.gua.stop_auto_cycle()
        return {"error": "六十四卦集成未启用"}
    
    def chat_with_gua(self, message: str) -> Dict:
        """结合卦象的对话"""
        if self.gua_bridge:
            return self.gua_bridge.chat_with_gua(message)
        return self.chat(message)
    
    def summary(self) -> str:
        """生成融合摘要"""
        stats = self.memory.get_stats()
        state = self.memory.get_system_state()
        
        lines = [
            "=" * 60,
            "🌟 星核融合引擎 v1.0 摘要",
            "=" * 60,
            "",
            "📊 记忆统计：",
            f"   决策记录: {stats['decisions']} 条",
            f"   记忆条目: {stats['memory_entries']} 条",
            f"   融合日志: {stats['fusion_logs']} 条",
            "",
            "🔧 系统状态：",
            f"   daemon: {'✅' if state['components']['daemon'] else '❌'}",
            f"   CycleSystem: {'✅' if state['components']['cycle_system'] else '❌'}",
            f"   iOS Controller: {'✅' if state['components']['ios_controller'] else '❌'}",
            "",
        ]
        
        # Phase 5: 六十四卦状态
        if self.gua:
            gua_status = self.gua.get_status()
            current_gua = gua_status.get("gua_state", {}).get("current_gua", {})
            lines.append("🔮 六十四卦：")
            lines.append(f"   当前卦象: {current_gua.get('name', 'N/A')}({current_gua.get('number', 'N/A')})")
            lines.append(f"   周期数: {gua_status.get('gua_state', {}).get('cycle_count', 0)}")
            lines.append(f"   自动循环: {'✅ 运行中' if self.gua.self_cycle and self.gua.self_cycle._running else '❌ 未启动'}")
            lines.append("")
        
        # 三位一体状态
        if self.three_sages:
            ts_status = self.three_sages.get_status()
            lines.append("🧭 三位一体：")
            lines.append(f"   当前焦点: {ts_status['state']['current_sage_focus']}")
            lines.append(f"   决策数: {ts_status['state']['decision_count']}")
            lines.append(f"   口诀: {self.get_sage_motto()}")
            lines.append("")
        
        lines.extend([
            "🔔 监控状态：",
            f"   {'✅ 运行中' if self.running else '❌ 未启动'}",
            "",
            "💡 你可以这样跟我对话：",
            '   "星核现在什么状态？"',
            '   "星核在做什么？"',
            '   "星核能量多少？"',
            '   "重启 daemon"',
            '   "星核迷茫吗？"',
            '   "当前卦象是什么？"',
            '   "运行六环节"',
            '   "三位一体现在什么状态？"',
            '   "评估当前状态"',
            '   "基于三位一体做决策"',
            "",
            "=" * 60
        ])
        
        return "\n".join(lines)


# ==================== 主程序 ====================

if __name__ == "__main__":
    engine = FusionEngine()
    
    print(engine.summary())
    
    # 测试对话
    print("\n🧪 测试对话...")
    
    tests = [
        "星核现在什么状态？",
        "星核在做什么？",
        "星核能量多少？",
        "星核迷茫吗？",
    ]
    
    for msg in tests:
        print(f"\n👤 {msg}")
        result = engine.chat(msg)
        print(f"💬 {result['response']}")
    
    print("\n✅ 融合引擎测试完成")
    print("\n💡 提示：engine.start_monitoring() 启动后台监控")
