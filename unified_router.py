#!/usr/bin/env python3
"""
统一路由层 v1.0

融合目标：用户指令 → 统一路由 → 星核决策层 / Hermes 工具 / 直接回答

路由决策树：
┌─────────────────────────────────────────────────────────────┐
│                    统一路由层                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              IntentClassifier (意图分类器)             │   │
│  │  输入：用户自然语言                                    │   │
│  │  输出：(route_target, params)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                          ↓                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ starcore │  │ hermes   │  │ dialogue │  │ direct   │  │
│  │ 决策层   │  │ 工具层   │  │ 桥接层   │  │ 回答     │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │             │             │             │         │
│       └─────────────┴─────────────┴─────────────┘         │
│                          ↓                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ResponseAggregator (响应聚合器)           │   │
│  │  统一格式：{"route": ..., "result": ..., "explain": ...}│   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

路由规则：
1. 查询星核状态 → starcore (GET /state)
2. 查询决策历史 → starcore (查询数据库)
3. 执行工具操作 → hermes (terminal/file/search 等)
4. 对话式查询 → dialogue (对话桥接器)
5. 简单问答 → direct (我直接回答)
6. 复杂任务 → starcore + hermes (星核决策 + 工具执行)
"""

import json
import subprocess
import sqlite3
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum

# 导入统一记忆层
import sys
sys.path.insert(0, '/home/ubuntu/starcore')
from unified_memory import UnifiedMemory

# ==================== 路由目标 ====================

class RouteTarget(Enum):
    STARCORE = "starcore"      # 星核决策层
    HERMES = "hermes"          # Hermes 工具层
    DIALOGUE = "dialogue"      # 对话桥接层
    DIRECT = "direct"          # 直接回答
    UNKNOWN = "unknown"        # 未知

# ==================== 路由指令 ====================

@dataclass
class RouteCommand:
    """路由命令"""
    target: RouteTarget
    action: str
    params: Dict
    priority: int = 0  # 优先级，高的先匹配

# ==================== 意图分类器 ====================

class IntentClassifier:
    """意图分类器"""
    
    # 路由规则（按优先级排序）
    ROUTES = [
        # 高优先级：明确命令
        RouteCommand(RouteTarget.STARCORE, "restart", {"target": "daemon"}, priority=100),
        RouteCommand(RouteTarget.STARCORE, "restart", {"target": "cycle"}, priority=100),
        RouteCommand(RouteTarget.STARCORE, "transition", {}, priority=100),
        
        # 中优先级：星核查询
        RouteCommand(RouteTarget.STARCORE, "status", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "decisions", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "energy", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "entropy", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "hexagram", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "lifecycle", {}, priority=50),
        RouteCommand(RouteTarget.STARCORE, "calibrate", {}, priority=50),
        
        # 工具操作
        RouteCommand(RouteTarget.HERMES, "terminal", {}, priority=30),
        RouteCommand(RouteTarget.HERMES, "file_read", {}, priority=30),
        RouteCommand(RouteTarget.HERMES, "file_write", {}, priority=30),
        RouteCommand(RouteTarget.HERMES, "search", {}, priority=30),
        
        # 对话查询
        RouteCommand(RouteTarget.DIALOGUE, "chat", {}, priority=20),
        
        # 低优先级：默认
        RouteCommand(RouteTarget.DIRECT, "answer", {}, priority=0),
    ]
    
    # 关键词映射
    KEYWORD_MAP = {
        "starcore_status": ["星核状态", "星核现在", "星核情况", "星核怎么样", "系统状态", "现在什么状态"],
        "starcore_decisions": ["星核决策", "星核在做什么", "星核做了什么", "最近决策", "决策历史"],
        "starcore_energy": ["星核能量", "能量多少", "认知能量", "物理能量"],
        "starcore_entropy": ["星核熵", "熵值", "混乱度", "秩序"],
        "starcore_hexagram": ["星核卦象", "卦象", "六十四卦", "当前卦"],
        "starcore_lifecycle": ["生命周期", "星核阶段", "未济", "既济", "复盘"],
        "starcore_calibrate": ["星核迷茫", "迷茫吗", "阿腾", "校准"],
        "starcore_restart": ["重启 daemon", "重启 cycle", "重启星核", "恢复"],
        "hermes_terminal": ["执行命令", "运行", "shell", "终端", "bash"],
        "hermes_file": ["读取文件", "写入文件", "查看文件", "编辑文件"],
        "hermes_search": ["搜索", "查找", "grep", "find"],
        "dialogue_help": ["帮助", "能做什么", "指令", "怎么用"],
    }
    
    @classmethod
    def classify(cls, message: str) -> RouteCommand:
        """
        分类用户意图，返回路由命令
        
        流程：
        1. 检查明确命令（重启、切换卦象等）
        2. 检查关键词匹配
        3. 默认直接回答
        """
        message_lower = message.lower()
        
        # 1. 检查明确命令
        if "重启" in message:
            if "daemon" in message:
                return RouteCommand(RouteTarget.STARCORE, "restart", {"target": "daemon"}, priority=100)
            elif "cycle" in message or "六十四卦" in message:
                return RouteCommand(RouteTarget.STARCORE, "restart", {"target": "cycle"}, priority=100)
            else:
                return RouteCommand(RouteTarget.STARCORE, "restart", {"target": "cycle"}, priority=100)
        
        if "切换卦象" in message or "改变卦象" in message:
            hexagram = "TAI"  # 默认
            for h in ["QIAN", "KUN", "TAI", "PI", "JIAN", "JIE"]:
                if h.lower() in message_lower:
                    hexagram = h
                    break
            return RouteCommand(RouteTarget.STARCORE, "transition", {"hexagram": hexagram}, priority=100)
        
        # 2. 检查关键词匹配
        for route_name, keywords in cls.KEYWORD_MAP.items():
            for kw in keywords:
                if kw in message:
                    # 根据 route_name 确定目标
                    if route_name.startswith("starcore_"):
                        action = route_name.replace("starcore_", "")
                        return RouteCommand(RouteTarget.STARCORE, action, {}, priority=50)
                    elif route_name.startswith("hermes_"):
                        action = route_name.replace("hermes_", "")
                        return RouteCommand(RouteTarget.HERMES, action, {}, priority=30)
                    elif route_name.startswith("dialogue_"):
                        return RouteCommand(RouteTarget.DIALOGUE, "chat", {}, priority=20)
        
        # 3. 默认直接回答
        return RouteCommand(RouteTarget.DIRECT, "answer", {"message": message}, priority=0)

# ==================== 执行器 ====================

class RouteExecutor:
    """路由执行器"""
    
    def __init__(self):
        self.memory = UnifiedMemory()
    
    def execute(self, cmd: RouteCommand) -> Dict:
        """执行路由命令"""
        if cmd.target == RouteTarget.STARCORE:
            return self._execute_starcore(cmd)
        elif cmd.target == RouteTarget.HERMES:
            return self._execute_hermes(cmd)
        elif cmd.target == RouteTarget.DIALOGUE:
            return self._execute_dialogue(cmd)
        elif cmd.target == RouteTarget.DIRECT:
            return self._execute_direct(cmd)
        else:
            return {"error": f"Unknown route target: {cmd.target}"}
    
    def _execute_starcore(self, cmd: RouteCommand) -> Dict:
        """执行星核操作"""
        action = cmd.action
        params = cmd.params
        
        if action == "status":
            return self.memory.get_system_state()
        
        elif action == "decisions":
            decisions = self.memory.get_decisions(limit=10)
            return {"decisions": decisions, "count": len(decisions)}
        
        elif action == "energy":
            state = self.memory.get_system_state()
            cycle = state.get("components", {}).get("cycle_system", {})
            energy = cycle.get("energy", {})
            return {
                "physical": energy.get("physical", 0),
                "cognitive": energy.get("cognitive", 0),
                "total": energy.get("total", 0),
                "status": "low" if energy.get("cognitive", 0) < 30 else "normal"
            }
        
        elif action == "entropy":
            state = self.memory.get_system_state()
            cycle = state.get("components", {}).get("cycle_system", {})
            entropy = cycle.get("entropy", {})
            return {
                "value": entropy.get("value", 0),
                "trend": entropy.get("trend", 0),
                "status": "high" if entropy.get("value", 0) > 0.6 else "low" if entropy.get("value", 0) < 0.2 else "normal"
            }
        
        elif action == "hexagram":
            state = self.memory.get_system_state()
            cycle = state.get("components", {}).get("cycle_system", {})
            return {
                "hexagram": cycle.get("hexagram", "UNKNOWN"),
                "meaning": self._get_hexagram_meaning(cycle.get("hexagram", ""))
            }
        
        elif action == "lifecycle":
            state = self.memory.get_system_state()
            cycle = state.get("components", {}).get("cycle_system", {})
            return {
                "phase": cycle.get("lifecycle", "UNKNOWN"),
                "description": self._get_lifecycle_description(cycle.get("lifecycle", ""))
            }
        
        elif action == "calibrate":
            # 模拟阿腾校准
            state = self.memory.get_system_state()
            cycle = state.get("components", {}).get("cycle_system", {})
            energy = cycle.get("energy", {}).get("cognitive", 0)
            entropy = cycle.get("entropy", {}).get("value", 0)
            
            return {
                "ateng_calibration": {
                    "三层框架": "现实" if energy < 50 else "理想",
                    "去伪存真结果": True,
                    "校准建议": f"认知能量 {energy:.1f}%, 熵 {entropy:.2f}"
                }
            }
        
        elif action == "restart":
            target = params.get("target", "cycle")
            # 发送重启命令
            try:
                result = subprocess.run(
                    ["curl", "-s", "-X", "POST", "http://localhost:9092/command",
                     "-H", "Content-Type: application/json",
                     "-d", json.dumps({"action": "review"})],
                    capture_output=True, text=True, timeout=5
                )
                return {"status": "accepted", "target": target, "message": "命令已发送"}
            except Exception as e:
                return {"status": "error", "error": str(e)}
        
        elif action == "transition":
            hexagram = params.get("hexagram", "TAI")
            try:
                result = subprocess.run(
                    ["curl", "-s", "-X", "POST", "http://localhost:9092/command",
                     "-H", "Content-Type: application/json",
                     "-d", json.dumps({"action": "transition", "hexagram": hexagram})],
                    capture_output=True, text=True, timeout=5
                )
                return {"status": "accepted", "hexagram": hexagram}
            except Exception as e:
                return {"status": "error", "error": str(e)}
        
        return {"error": f"Unknown starcore action: {action}"}
    
    def _execute_hermes(self, cmd: RouteCommand) -> Dict:
        """执行 Hermes 工具操作"""
        action = cmd.action
        
        if action == "terminal":
            # 执行 shell 命令（需要具体命令）
            return {"error": "需要具体命令，例如：'执行命令 ls -la'"}
        
        elif action == "file_read":
            return {"error": "需要文件路径，例如：'读取文件 /path/to/file'"}
        
        elif action == "search":
            return {"error": "需要搜索内容，例如：'搜索关键词 xxx'"}
        
        return {"error": f"Unknown hermes action: {action}"}
    
    def _execute_dialogue(self, cmd: RouteCommand) -> Dict:
        """执行对话操作"""
        # 导入对话桥接器
        try:
            from dialogue_bridge import StarCoreDialogue
            dialogue = StarCoreDialogue()
            message = cmd.params.get("message", "")
            response = dialogue.chat(message)
            return {"response": response, "type": "dialogue"}
        except Exception as e:
            return {"error": f"Dialogue error: {e}"}
    
    def _execute_direct(self, cmd: RouteCommand) -> Dict:
        """直接回答"""
        message = cmd.params.get("message", "")
        return {
            "response": f"收到：{message}。如需操作星核系统，请说'星核现在什么状态？'或'重启 daemon'等指令。",
            "type": "direct"
        }
    
    def _get_hexagram_meaning(self, hexagram: str) -> str:
        """获取卦象含义"""
        meanings = {
            "KUNQIAN": "地天泰 → 天地否：初始态，阴阳未交",
            "QIANKUN": "天地否：阴阳不交，需要变革",
            "ZHEN": "震卦：启动，雷动",
            "GENG": "革卦：变革，革新",
            "DING": "鼎卦：稳固，建立",
            "JIAN": "渐卦：渐进，逐步",
            "FENG": "丰卦：丰盛，成就",
            "XUN": "巽卦：深入，渗透",
            "QIAN": "乾为天：刚健，创造",
            "KUN": "坤为地：柔顺，承载",
        }
        return meanings.get(hexagram, "未知卦象")
    
    def _get_lifecycle_description(self, phase: str) -> str:
        """获取生命周期描述"""
        descriptions = {
            "未济": "未济卦：事情未完成，正在努力中",
            "演化": "演化阶段：卦象变化，系统演进",
            "既济": "既济卦：事情完成，暂时稳定",
            "复盘": "复盘阶段：总结经验，反思改进",
            "重置": "重置阶段：回到初始，准备新一轮",
        }
        return descriptions.get(phase, "未知阶段")

# ==================== 统一路由引擎 ====================

class UnifiedRouter:
    """统一路由引擎"""
    
    def __init__(self):
        self.classifier = IntentClassifier()
        self.executor = RouteExecutor()
        self.memory = UnifiedMemory()
    
    def route(self, message: str) -> Dict:
        """
        统一路由入口
        
        输入：用户自然语言
        输出：{"route": ..., "result": ..., "explain": ...}
        """
        timestamp = datetime.now().isoformat()
        
        # 1. 分类意图
        cmd = self.classifier.classify(message)
        
        # 2. 执行路由
        result = self.executor.execute(cmd)
        
        # 3. 记录路由日志
        self.memory.save(
            key=f"route_{timestamp}",
            value={
                "message": message,
                "route": cmd.target.value,
                "action": cmd.action,
                "result": result
            },
            source="fusion",
            category="routing"
        )
        
        # 4. 生成解释
        explain = self._generate_explanation(cmd, result)
        
        return {
            "timestamp": timestamp,
            "message": message,
            "route": {
                "target": cmd.target.value,
                "action": cmd.action,
                "params": cmd.params
            },
            "result": result,
            "explain": explain
        }
    
    def _generate_explanation(self, cmd: RouteCommand, result: Dict) -> str:
        """生成自然语言解释"""
        if cmd.target == RouteTarget.STARCORE:
            if cmd.action == "status":
                return "已查询星核系统状态"
            elif cmd.action == "decisions":
                return f"已获取最近 {result.get('count', 0)} 条决策记录"
            elif cmd.action == "energy":
                cognitive = result.get("cognitive", 0)
                return f"认知能量 {cognitive:.1f}%，{'偏低' if cognitive < 30 else '正常'}"
            elif cmd.action == "restart":
                return f"已发送重启 {cmd.params.get('target', 'cycle')} 的命令"
            else:
                return f"已执行星核操作：{cmd.action}"
        
        elif cmd.target == RouteTarget.HERMES:
            return f"已路由到 Hermes 工具层：{cmd.action}"
        
        elif cmd.target == RouteTarget.DIALOGUE:
            return "已通过对话桥接器处理"
        
        elif cmd.target == RouteTarget.DIRECT:
            return "已直接回答"
        
        return "已处理"

# ==================== 主程序 ====================

if __name__ == "__main__":
    router = UnifiedRouter()
    
    print("=" * 60)
    print("🔀 统一路由层 v1.0 已初始化")
    print("=" * 60)
    
    # 测试路由
    tests = [
        "星核现在什么状态？",
        "星核在做什么？",
        "星核能量多少？",
        "重启 daemon",
        "星核迷茫吗？",
        "帮我执行 ls -la",
        "星核能做什么？",
    ]
    
    for msg in tests:
        print(f"\n👤 {msg}")
        result = router.route(msg)
        print(f"🔀 路由到: {result['route']['target']} → {result['route']['action']}")
        print(f"💬 {result['explain']}")
        if "error" not in result.get("result", {}):
            if result["route"]["target"] == "starcore":
                r = result["result"]
                if "energy" in r:
                    print(f"   能量: 物理 {r.get('physical', 0):.1f}%, 认知 {r.get('cognitive', 0):.1f}%")
                if "decisions" in r:
                    print(f"   决策: {r.get('count', 0)} 条")
    
    print("\n✅ 统一路由层就绪")
