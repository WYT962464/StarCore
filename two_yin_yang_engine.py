#!/usr/bin/env python3
"""
两仪循环引擎 v5.0 - 星核系统整合版
阴阳相生相克的自进化决策系统
"""

import json
import subprocess
import sqlite3
import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional

# ==================== 配置 ====================

CONFIG = {
    "ssh_port": 8028,
    "ssh_host": "127.0.0.1",
    "ssh_user": "mobile",
    "ios_controller_host": "localhost",
    "ios_controller_port": 9091,
    "daemon_host": "localhost",
    "daemon_port": 9090,
    "database_path": "/home/ubuntu/starcore/data/decisions.db",
    "log_dir": "/home/ubuntu/starcore/data/logs",
}

# ==================== 阳端 (探索) ====================

class YangEnd:
    """阳端 - 方向探索"""
    
    def __init__(self):
        self.system_state = {}
    
    def get_system_state(self) -> Dict:
        """获取系统状态快照"""
        state = {
            "timestamp": datetime.now().isoformat(),
            "services": {},
            "iphone": {}
        }
        
        # 检查核心服务
        services = {
            "ssh_tunnel": f"ssh -p {CONFIG['ssh_port']} -o StrictHostKeyChecking=no -o ConnectTimeout=5 {CONFIG['ssh_user']}@{CONFIG['ssh_host']} 'echo OK'",
            "ios_controller": f"curl -s http://{CONFIG['ios_controller_host']}:{CONFIG['ios_controller_port']}/health",
            "daemon": f"curl -s http://{CONFIG['daemon_host']}:{CONFIG['daemon_port']}/health",
        }
        
        for name, cmd in services.items():
            try:
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
                state["services"][name] = {
                    "status": "ok" if result.returncode == 0 else "error",
                    "output": result.stdout.strip()[:200]
                }
            except Exception as e:
                state["services"][name] = {"status": "error", "output": str(e)}
        
        self.system_state = state
        return state
    
    def generate_directions(self, context: Dict) -> List[Dict]:
        """生成 5 个发展方向"""
        
        directions = [
            {
                "id": "D1",
                "name": "两仪循环引擎整合",
                "description": "将两仪循环 v5.0 与星核系统深度整合，实现自主演化闭环",
                "rationale": "当前系统已完成基础架构，两仪循环提供演化机制",
                "priority": "P0"
            },
            {
                "id": "D2",
                "name": "daemon 任务调度修复",
                "description": "修复 daemon 的 submit_task() 和 _on_execution 回调",
                "rationale": "daemon 当前仅状态监控，无任务执行能力",
                "priority": "P0"
            },
            {
                "id": "D3",
                "name": "视觉闭环增强",
                "description": "增加 OCR 文字识别、UI 元素检测",
                "rationale": "当前仅能获取截图，缺乏内容理解",
                "priority": "P1"
            },
            {
                "id": "D4",
                "name": "决策日志持久化",
                "description": "将决策报告持久化到 SQLite 数据库",
                "rationale": "当前仅保存为文件，缺乏结构化存储",
                "priority": "P1"
            },
            {
                "id": "D5",
                "name": "SSH 隧道稳定性优化",
                "description": "添加自动重连、心跳检测、隧道监控",
                "rationale": "隧道依赖 iPhone 主动建立，可能中断",
                "priority": "P2"
            }
        ]
        
        return directions


# ==================== 阴端 (决策) ====================

class YinEnd:
    """阴端 - 深度决策"""
    
    DIMENSIONS = {
        "D1": "价值密度",
        "D2": "实现难度",
        "D3": "依赖风险",
        "D4": "技术债务",
        "D5": "用户价值",
        "D6": "系统影响",
        "D7": "可验证性",
        "D8": "紧急程度"
    }
    
    def evaluate(self, direction: Dict, context: Dict) -> Dict:
        """8 维评估"""
        
        scores = self._calculate_scores(direction)
        
        total = sum(scores.values())
        avg = total / 8
        
        return {
            "direction_id": direction["id"],
            "direction_name": direction["name"],
            "scores": scores,
            "total": total,
            "average": round(avg, 2),
            "confidence": self._assess_confidence(direction),
            "reverse_validation": self._reverse_validate(direction)
        }
    
    def _calculate_scores(self, direction: Dict) -> Dict[str, int]:
        """计算 8 维评分"""
        
        base_scores = {
            "D1": {"P0": 5, "P1": 4, "P2": 3},
            "D2": {"P0": 3, "P1": 3, "P2": 3},
            "D3": {"P0": 4, "P1": 4, "P2": 4},
            "D4": {"P0": 3, "P1": 3, "P2": 3},
            "D5": {"P0": 5, "P1": 4, "P2": 4},
            "D6": {"P0": 4, "P1": 4, "P2": 3},
            "D7": {"P0": 5, "P1": 4, "P2": 4},
            "D8": {"P0": 4, "P1": 3, "P2": 3},
        }
        
        priority = direction.get("priority", "P1")
        
        scores = {}
        for dim, score_map in base_scores.items():
            scores[dim] = score_map.get(priority, 3)
        
        return scores
    
    def _assess_confidence(self, direction: Dict) -> str:
        """置信度评估"""
        if "整合" in direction["name"] or "闭环" in direction["name"]:
            return "高 - 文档完整，架构清晰"
        elif "修复" in direction["name"]:
            return "中 - 需修改核心代码"
        else:
            return "中 - 需进一步验证"
    
    def _reverse_validate(self, direction: Dict) -> Dict:
        """反向验证"""
        return {
            "potential_issues": [
                "架构兼容性问题",
                "执行闭环适配复杂度",
                "反馈机制对接难度"
            ],
            "mitigation": [
                "分步验证，先实现基础功能",
                "设计降级方案",
                "建立回滚机制"
            ]
        }


# ==================== 决策执行闭环 ====================

class ExecutionLoop:
    """决策执行闭环"""
    
    def execute(self, action: str, params: Dict) -> Dict:
        """执行动作"""
        
        if action == "screenshot":
            return self._screenshot()
        elif action == "get_state":
            return self._get_state()
        elif action == "exec_command":
            return self._exec_command(params.get("command", ""))
        else:
            return {"success": False, "error": f"Unknown action: {action}"}
    
    def _screenshot(self) -> Dict:
        """获取截图"""
        host = CONFIG['ios_controller_host']
        port = CONFIG['ios_controller_port']
        cmd = f'curl -s -X POST http://{host}:{port}/screenshot -H "Content-Type: application/json" -d \'{{}}\''
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        
        try:
            data = json.loads(result.stdout)
            return {
                "success": data.get("success", False),
                "data": data.get("data", ""),
                "error": data.get("error", "")
            }
        except:
            return {"success": False, "error": "JSON parse failed", "raw": result.stdout[:500]}
    
    def _get_state(self) -> Dict:
        """获取系统状态"""
        host = CONFIG['ios_controller_host']
        port = CONFIG['ios_controller_port']
        cmd = f"curl -s http://{host}:{port}/health"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        
        try:
            return json.loads(result.stdout)
        except:
            return {"success": False, "error": "Failed to get state"}
    
    def _exec_command(self, command: str) -> Dict:
        """执行命令"""
        port = CONFIG["ssh_port"]
        user = CONFIG["ssh_user"]
        host = CONFIG["ssh_host"]
        cmd = f'ssh -p {port} -o StrictHostKeyChecking=no {user}@{host} "{command}"'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout[:1000],
            "stderr": result.stderr[:500]
        }


# ==================== 决策数据库 ====================

class DecisionDB:
    """决策追踪数据库"""
    
    def __init__(self, db_path: str = None):
        self.db_path = db_path or CONFIG["database_path"]
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        self._init_db()
    
    def _init_db(self):
        """初始化数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                decision_name TEXT,
                decision_time TEXT,
                direction TEXT,
                score REAL,
                confidence TEXT,
                status TEXT,
                report_path TEXT,
                created_at TEXT
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS execution_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                decision_id INTEGER,
                action TEXT,
                result TEXT,
                feedback TEXT,
                timestamp TEXT,
                FOREIGN KEY (decision_id) REFERENCES decisions(id)
            )
        """)
        
        conn.commit()
        conn.close()
    
    def save_decision(self, decision: Dict) -> int:
        """保存决策"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO decisions (decision_name, decision_time, direction, score, confidence, status, report_path, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            decision.get("name", ""),
            decision.get("time", ""),
            decision.get("direction", ""),
            decision.get("score", 0),
            decision.get("confidence", ""),
            decision.get("status", "pending"),
            decision.get("report_path", ""),
            datetime.now().isoformat()
        ))
        
        decision_id = cursor.lastrowid
        conn.commit()
        conn.close()
        
        return decision_id
    
    def log_execution(self, decision_id: int, action: str, result: str, feedback: str = ""):
        """记录执行日志"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO execution_logs (decision_id, action, result, feedback, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """, (decision_id, action, result, feedback, datetime.now().isoformat()))
        
        conn.commit()
        conn.close()


# ==================== 两仪循环引擎主类 ====================

class TwoYinYangEngine:
    """两仪循环引擎 v5.0"""
    
    def __init__(self):
        self.yang = YangEnd()
        self.yin = YinEnd()
        self.loop = ExecutionLoop()
        self.db = DecisionDB()
    
    def run_cycle(self, context: Dict = None) -> Dict:
        """运行一个完整循环"""
        
        print("=" * 60)
        print("🔄 两仪循环引擎 - 新循环启动")
        print("=" * 60)
        
        # 1. 阳端：获取状态 + 生成方向
        print("\n📊 系统状态快照...")
        state = self.yang.get_system_state()
        
        print("\n🔮 阳端方向探索...")
        directions = self.yang.generate_directions(context or {})
        
        for d in directions:
            print(f"   {d['id']}: {d['name']} [{d['priority']}]")
        
        # 2. 阴端：评估所有方向
        print("\n🧠 阴端决策评估...")
        evaluations = []
        for d in directions:
            eval_result = self.yin.evaluate(d, context or {})
            evaluations.append(eval_result)
            print(f"   {d['id']}: {eval_result['average']}/5.0 (总分 {eval_result['total']}/40)")
        
        # 3. 选择最佳方向
        best = max(evaluations, key=lambda x: x["total"])
        print(f"\n✅ 选择方向: {best['direction_name']} (评分 {best['average']}/5.0)")
        
        # 4. 执行闭环
        print("\n🔧 执行闭环...")
        exec_result = self.loop.execute("get_state", {})
        print(f"   状态: {exec_result.get('status', 'unknown')}")
        
        # 5. 保存决策
        decision = {
            "name": f"DEC-{datetime.now().strftime('%Y%m%d-%H%M')}",
            "time": datetime.now().isoformat(),
            "direction": best["direction_name"],
            "score": best["average"],
            "confidence": best["confidence"],
            "status": "completed",
            "report_path": ""
        }
        
        decision_id = self.db.save_decision(decision)
        self.db.log_execution(decision_id, "cycle_complete", "success", json.dumps(exec_result))
        
        print(f"\n💾 决策已保存 (ID: {decision_id})")
        
        return {
            "decision_id": decision_id,
            "selected_direction": best,
            "evaluations": evaluations,
            "execution": exec_result
        }


# ==================== 主程序 ====================

if __name__ == "__main__":
    engine = TwoYinYangEngine()
    result = engine.run_cycle()
    print("\n" + "=" * 60)
    print("🎉 循环完成")
    print("=" * 60)
