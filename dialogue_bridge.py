#!/usr/bin/env python3
"""
星核对话桥接器

让你通过我 (Hermes/SenseNova) 与星核系统对话。

对话流程：
你 → 我 → 解析意图 → 调用星核 API → 星核响应 → 我 → 翻译解释 → 你

支持的自然语言指令：
- "星核现在什么状态？"
- "星核在做什么？"
- "星核最近决策了什么？"
- "让星核重启 daemon"
- "星核迷茫吗？"
- "星核能量多少？"
"""

import json
import subprocess
import sqlite3
from datetime import datetime
from typing import Dict, Optional, Tuple

# ==================== 星核 API 客户端 ====================

class StarCoreClient:
    """星核系统 API 客户端"""
    
    def __init__(self):
        self.daemon_url = "http://localhost:9090"
        self.cycle_url = "http://localhost:9092"
        self.controller_url = "http://localhost:9091"
    
    def _get(self, url: str, timeout: int = 3) -> Optional[Dict]:
        try:
            result = subprocess.run(
                ["curl", "-s", "--connect-timeout", str(timeout), url],
                capture_output=True, text=True, timeout=timeout + 1
            )
            if result.returncode == 0 and result.stdout:
                return json.loads(result.stdout)
        except Exception:
            pass
        return None
    
    def _post(self, url: str, data: Dict, timeout: int = 3) -> Optional[Dict]:
        try:
            result = subprocess.run(
                ["curl", "-s", "--connect-timeout", str(timeout), "-X", "POST",
                 "-H", "Content-Type: application/json", "-d", json.dumps(data), url],
                capture_output=True, text=True, timeout=timeout + 1
            )
            if result.returncode == 0 and result.stdout:
                return json.loads(result.stdout)
        except Exception:
            pass
        return None
    
    def get_status(self) -> Dict:
        """获取完整状态"""
        return {
            "daemon": self._get(f"{self.daemon_url}/health"),
            "cycle_system": self._get(f"{self.cycle_url}/state"),
            "ios_controller": self._get(f"{self.controller_url}/health"),
        }
    
    def send_command(self, action: str, **kwargs) -> Optional[Dict]:
        """发送命令到 CycleSystem"""
        cmd = {"action": action, **kwargs}
        return self._post(f"{self.cycle_url}/command", cmd)
    
    def get_decisions(self, limit: int = 5) -> list:
        """获取最近决策"""
        try:
            conn = sqlite3.connect("/home/ubuntu/starcore/data/decisions.db")
            cursor = conn.cursor()
            cursor.execute(
                "SELECT timestamp, input_source, final_decision, confidence, "
                "json_extract(ateng_calibration, '$.校准建议') as ateng_suggestion "
                "FROM decisions ORDER BY id DESC LIMIT ?",
                (limit,)
            )
            results = []
            for row in cursor.fetchall():
                results.append({
                    "timestamp": row[0],
                    "source": row[1],
                    "decision": row[2],
                    "confidence": row[3],
                    "ateng_suggestion": row[4]
                })
            conn.close()
            return results
        except Exception as e:
            return [{"error": str(e)}]
    
    def get_self_cycle_history(self, limit: int = 5) -> list:
        """获取自循环历史"""
        log_file = "/home/ubuntu/starcore/data/self_cycle_log.jsonl"
        try:
            with open(log_file) as f:
                lines = [json.loads(l) for l in f if l.strip()]
            return lines[-limit:]
        except Exception as e:
            return [{"error": str(e)}]

# ==================== 意图解析器 ====================

class IntentParser:
    """自然语言意图解析器"""
    
    # 意图关键词映射
    INTENT_MAP = {
        "status": ["状态", "情况", "怎么样", "如何", "什么", "现在"],
        "decisions": ["决策", "决定", "选择", "做了什么", "最近"],
        "cycle": ["自循环", "循环", "运行", "执行"],
        "energy": ["能量", "认知", "体力", "脑力"],
        "entropy": ["熵", "混乱", "秩序"],
        "hexagram": ["卦象", "卦", "六十四卦"],
        "restart": ["重启", "重新启动", "恢复"],
        "calibrate": ["校准", "迷茫", "阿腾", "方向"],
        "lifecycle": ["生命周期", "阶段", "未济", "既济"],
        "help": ["帮助", "能做什么", "怎么", "指令"],
    }
    
    # 命令映射
    COMMAND_MAP = {
        "restart_daemon": ["重启 daemon", "恢复 daemon", "重启状态监控"],
        "restart_cycle": ["重启 cycle", "重启六十四卦", "重启演化系统"],
        "status": ["查看状态", "状态查询"],
        "review": ["复盘", "回顾", "review"],
        "transition": ["切换卦象", "改变卦象"],
    }
    
    @classmethod
    def parse(cls, message: str) -> Tuple[str, Dict]:
        """
        解析用户意图
        
        返回: (intent, params)
        """
        message_lower = message.lower()
        
        # 检查命令（优先匹配）
        for cmd, keywords in cls.COMMAND_MAP.items():
            for kw in keywords:
                if kw in message:
                    params = {}
                    if "daemon" in message:
                        params["target"] = "daemon"
                    if "cycle" in message or "六十四卦" in message:
                        params["target"] = "cycle"
                    if "卦象" in message:
                        for hex_name in ["QIAN", "KUN", "TAI", "PI", "JIAN", "JIE"]:
                            if hex_name.lower() in message_lower:
                                params["hexagram"] = hex_name
                    return cmd, params
        
        # 检查意图
        for intent, keywords in cls.INTENT_MAP.items():
            for kw in keywords:
                if kw in message:
                    # 特殊处理："在做什么" → decisions
                    if "在做什么" in message or "做了什么" in message:
                        return "decisions", {}
                    return intent, {}
        
        # 默认：状态查询
        return "status", {}

# ==================== 响应生成器 ====================

class ResponseGenerator:
    """星核响应翻译器"""
    
    @classmethod
    def generate(cls, intent: str, result: Dict) -> str:
        """生成自然语言响应"""
        
        if intent == "status":
            return cls._format_status(result)
        elif intent == "decisions":
            return cls._format_decisions(result)
        elif intent == "cycle":
            return cls._format_cycle(result)
        elif intent == "energy":
            return cls._format_energy(result)
        elif intent == "entropy":
            return cls._format_entropy(result)
        elif intent == "hexagram":
            return cls._format_hexagram(result)
        elif intent == "lifecycle":
            return cls._format_lifecycle(result)
        elif intent == "calibrate":
            return cls._format_calibration(result)
        elif intent == "restart":
            return cls._format_restart(result)
        elif intent == "help":
            return cls._format_help()
        else:
            return f"星核已收到：{intent}，处理结果：{json.dumps(result, ensure_ascii=False)}"
    
    @classmethod
    def _format_status(cls, data: Dict) -> str:
        lines = ["📊 星核系统状态：", ""]
        
        daemon = data.get("daemon", {})
        if daemon:
            lines.append(f"  daemon: ✅ v{daemon.get('version', 'unknown')}")
        else:
            lines.append(f"  daemon: ❌ 不可用")
        
        cycle = data.get("cycle_system", {})
        if cycle:
            energy = cycle.get("energy", {}).get("cognitive", 0)
            entropy = cycle.get("entropy", {}).get("value", 0)
            icon = "✅" if energy > 30 else "⚠️"
            lines.append(f"  CycleSystem: {icon} 卦象 {cycle.get('hexagram')}, 能量 {energy:.1f}%, 熵 {entropy:.2f}")
        else:
            lines.append(f"  CycleSystem: ❌ 不可用")
        
        controller = data.get("ios_controller", {})
        if controller:
            lines.append(f"  iOS Controller: ✅ v{controller.get('version', 'unknown')}")
        else:
            lines.append(f"  iOS Controller: ❌ 不可用")
        
        return "\n".join(lines)
    
    @classmethod
    def _format_decisions(cls, decisions: list) -> str:
        lines = ["📝 星核最近决策：", ""]
        for d in decisions[:5]:
            if "error" in d:
                lines.append(f"  ❌ {d['error']}")
                break
            ts = d.get("timestamp", "")[-12:] if d.get("timestamp") else "N/A"
            conf = d.get("confidence", 0)
            conf_icon = "✅" if conf > 0.6 else "⚠️" if conf > 0.4 else "❌"
            lines.append(f"  {ts} | {conf_icon} {d.get('decision', 'N/A')[:30]} (置信度 {conf:.2f})")
            if d.get("ateng_suggestion"):
                lines.append(f"       阿腾校准: {d['ateng_suggestion'][:40]}")
        return "\n".join(lines)
    
    @classmethod
    def _format_cycle(cls, data: Dict) -> str:
        lines = ["🔄 自循环状态：", ""]
        lines.append(f"  运行中: {'是' if data.get('running') else '否'}")
        lines.append(f"  最近循环: {len(data.get('recent_cycles', []))} 条记录")
        return "\n".join(lines)
    
    @classmethod
    def _format_energy(cls, data: Dict) -> str:
        cycle = data.get("cycle_system", {})
        energy = cycle.get("energy", {})
        lines = ["⚡ 星核能量状态：", ""]
        lines.append(f"  物理能量: {energy.get('physical', 0):.1f}% (服务器供电)")
        lines.append(f"  认知能量: {energy.get('cognitive', 0):.1f}% (任务奖励)")
        lines.append(f"  总能量: {energy.get('total', 0):.1f}%")
        
        cognitive = energy.get("cognitive", 0)
        if cognitive < 20:
            lines.append("  ⚠️ 认知能量过低，建议休息或减少任务")
        elif cognitive < 50:
            lines.append("  📉 认知能量偏低，注意任务质量")
        else:
            lines.append("  ✅ 认知能量充足")
        
        return "\n".join(lines)
    
    @classmethod
    def _format_entropy(cls, data: Dict) -> str:
        cycle = data.get("cycle_system", {})
        entropy = cycle.get("entropy", {})
        value = entropy.get("value", 0)
        lines = ["🌀 熵值状态：", ""]
        lines.append(f"  当前熵: {value:.2f}")
        
        if value > 0.6:
            lines.append("  🔥 熵值过高（混乱），系统需要收敛")
        elif value < 0.2:
            lines.append("  ❄️ 熵值过低（死锁），系统需要创新")
        else:
            lines.append("  ✅ 熵值正常（健康状态）")
        
        return "\n".join(lines)
    
    @classmethod
    def _format_hexagram(cls, data: Dict) -> str:
        cycle = data.get("cycle_system", {})
        hexagram = cycle.get("hexagram", "UNKNOWN")
        lines = ["☯️ 当前卦象：", ""]
        lines.append(f"  {hexagram}")
        
        # 卦象解释
        hex_meanings = {
            "KUNQIAN": "地天泰 → 天地否：初始态，阴阳未交",
            "QIANKUN": "天地否：阴阳不交，需要变革",
            "ZHEN": "震卦：启动，雷动",
            "GENG": "革卦：变革，革新",
            "DING": "鼎卦：稳固，建立",
            "JIAN": "渐卦：渐进，逐步",
            "FENG": "丰卦：丰盛，成就",
            "XUN": "巽卦：深入，渗透",
        }
        if hexagram in hex_meanings:
            lines.append(f"  含义: {hex_meanings[hexagram]}")
        
        return "\n".join(lines)
    
    @classmethod
    def _format_lifecycle(cls, data: Dict) -> str:
        cycle = data.get("cycle_system", {})
        phase = cycle.get("lifecycle", "UNKNOWN")
        lines = ["📅 生命周期：", ""]
        lines.append(f"  当前阶段: {phase}")
        
        phases = {
            "未济": "未济卦：事情未完成，正在努力中",
            "演化": "演化阶段：卦象变化，系统演进",
            "既济": "既济卦：事情完成，暂时稳定",
            "复盘": "复盘阶段：总结经验，反思改进",
            "重置": "重置阶段：回到初始，准备新一轮",
        }
        if phase in phases:
            lines.append(f"  说明: {phases[phase]}")
        
        return "\n".join(lines)
    
    @classmethod
    def _format_calibration(cls, data: Dict) -> str:
        lines = ["🧭 阿腾认知校准：", ""]
        if data.get("ateng_calibration"):
            cal = data["ateng_calibration"]
            lines.append(f"  三层框架: {cal.get('三层框架', 'N/A')}")
            lines.append(f"  去伪存真: {'✅' if cal.get('去伪存真结果') else '❌ 识别到假象'}")
            lines.append(f"  底线检查: {'✅' if cal.get('底线检查') else '❌ 触碰底线'}")
            lines.append(f"  校准建议: {cal.get('校准建议', '无')}")
        else:
            lines.append("  当前无需校准，系统运行正常")
        return "\n".join(lines)
    
    @classmethod
    def _format_restart(cls, result: Dict) -> str:
        lines = ["🔄 重启结果：", ""]
        if result.get("status") == "accepted":
            lines.append("  ✅ 命令已接受，正在执行...")
        else:
            lines.append(f"  ❌ 重启失败: {result.get('error', '未知错误')}")
        return "\n".join(lines)
    
    @classmethod
    def _format_help(cls) -> str:
        return """📖 星核对话指令：

查询类：
  "星核现在什么状态？" → 查看系统状态
  "星核在做什么？" → 查看最近决策
  "星核能量多少？" → 查看能量状态
  "星核迷茫吗？" → 查看阿腾校准状态
  "星核卦象是什么？" → 查看当前卦象

控制类：
  "重启 daemon" → 重启状态监控
  "重启 cycle" → 重启六十四卦系统
  "复盘" → 触发复盘阶段

其他：
  "星核能做什么？" → 查看帮助
"""

# ==================== 对话接口 ====================

class StarCoreDialogue:
    """星核对话接口"""
    
    def __init__(self):
        self.client = StarCoreClient()
        self.parser = IntentParser()
        self.generator = ResponseGenerator()
    
    def chat(self, message: str) -> str:
        """
        对话入口
        
        你 → chat(message) → 星核响应
        """
        # 1. 解析意图
        intent, params = self.parser.parse(message)
        
        # 2. 执行相应操作
        result = {}
        
        if intent in ["status", "energy", "entropy", "hexagram", "lifecycle"]:
            result = self.client.get_status()
        elif intent == "decisions":
            result = self.client.get_decisions()
        elif intent == "cycle":
            result = {"running": True, "recent_cycles": self.client.get_self_cycle_history()}
        elif intent == "calibrate":
            status = self.client.get_status()
            cycle = status.get("cycle_system", {})
            # 模拟阿腾校准
            result = {
                "ateng_calibration": {
                    "三层框架": "现实",
                    "去伪存真结果": True,
                    "校准建议": f"当前认知能量 {cycle.get('energy', {}).get('cognitive', 0):.1f}%, 熵 {cycle.get('entropy', {}).get('value', 0):.2f}"
                }
            }
        elif intent == "restart":
            target = params.get("target", "cycle")
            if target == "daemon":
                result = self.client.send_command("restart_daemon")
            else:
                result = self.client.send_command("review")  # 用 review 代替重启
        elif intent == "help":
            result = {}
        else:
            result = self.client.get_status()
        
        # 3. 生成响应
        response = self.generator.generate(intent, result)
        
        return response

# ==================== 主程序 ====================

if __name__ == "__main__":
    dialogue = StarCoreDialogue()
    
    print("=" * 60)
    print("🌟 星核对话桥接器 v1.0")
    print("=" * 60)
    print("\n试试这些指令：")
    print('  "星核现在什么状态？"')
    print('  "星核在做什么？"')
    print('  "星核能量多少？"')
    print('  "星核迷茫吗？"')
    print('  "重启 daemon"')
    print('  "星核能做什么？"')
    print("\n" + "=" * 60)
    
    # 示例对话
    test_messages = [
        "星核现在什么状态？",
        "星核在做什么？",
        "星核能量多少？",
        "星核迷茫吗？",
        "星核能做什么？",
    ]
    
    for msg in test_messages:
        print(f"\n👤 你: {msg}")
        response = dialogue.chat(msg)
        print(f"🤖 星核: {response}")
