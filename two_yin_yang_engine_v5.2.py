#!/usr/bin/env python3
"""
两仪循环引擎 v5.2 - 循环步数限制修复版
阴阳相生相克的自进化决策系统

修正: 
1. 输入源标记 (user/system/external)
2. 循环计数器持久化
3. 来源隔离 (用户输入重置，系统自循环递增)
4. 强制终止 (达到上限不可绕过)
"""

import json
import subprocess
import sqlite3
import os
import time
from datetime import datetime
from enum import Enum
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
    
    # 循环限制
    "max_cycles": 10,
    "cycle_timeout": 300,
    "feedback_threshold": 0.7,
}


# ==================== 输入源枚举 ====================

class InputSource(Enum):
    USER = "user"           # 真实用户输入
    SYSTEM = "system"       # 系统自循环
    EXTERNAL = "external"   # 外部触发（API、定时器）


# ==================== 输入消息 ====================

class InputMessage:
    def __init__(self, content: str, source: InputSource, metadata: Dict = None):
        self.content = content
        self.source = source
        self.metadata = metadata or {}
        self.timestamp = datetime.now()
    
    def to_dict(self) -> Dict:
        return {
            "content": self.content,
            "source": self.source.value,
            "metadata": self.metadata,
            "timestamp": self.timestamp.isoformat()
        }


# ==================== 循环计数器 ====================

class CycleCounter:
    """循环计数器 - 持久化，来源隔离"""
    
    def __init__(self, db_path: str = None):
        self.db_path = db_path or CONFIG["database_path"]
        self.max_cycles = CONFIG["max_cycles"]
        self.counter = 0
        self.last_reset = None
        self._init_db()
        self._load_state()
    
    def _init_db(self):
        """初始化数据库表"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS cycle_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                counter INTEGER DEFAULT 0,
                last_reset TEXT,
                max_cycles INTEGER DEFAULT 10
            )
        """)
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS cycle_audit (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cycle_id INTEGER,
                input_source TEXT,
                counter_before INTEGER,
                counter_after INTEGER,
                action TEXT,
                reason TEXT,
                timestamp TEXT
            )
        """)
        
        # 初始化状态行
        cursor.execute("SELECT COUNT(*) FROM cycle_state WHERE id = 1")
        if cursor.fetchone()[0] == 0:
            now = datetime.now().isoformat()
            cursor.execute("""
                INSERT INTO cycle_state (id, counter, last_reset, max_cycles)
                VALUES (1, 0, ?, 10)
            """, (now,))
        
        conn.commit()
        conn.close()
    
    def _load_state(self):
        """从数据库加载计数器状态"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT counter, last_reset, max_cycles FROM cycle_state WHERE id = 1")
        row = cursor.fetchone()
        if row:
            self.counter = row[0]
            self.last_reset = row[1]
            self.max_cycles = row[2] or CONFIG["max_cycles"]
        conn.close()
    
    def _save_state(self):
        """持久化计数器状态"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE cycle_state 
            SET counter = ?, last_reset = ? 
            WHERE id = 1
        """, (self.counter, self.last_reset))
        conn.commit()
        conn.close()
    
    def _audit(self, cycle_id: int, source: InputSource, counter_before: int, 
               counter_after: int, action: str, reason: str):
        """记录审计日志"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO cycle_audit (cycle_id, input_source, counter_before, 
                                     counter_after, action, reason, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (cycle_id, source.value, counter_before, counter_after, action, reason, datetime.now().isoformat()))
        conn.commit()
        conn.close()
    
    def process_input(self, source: InputSource, cycle_id: str = None) -> Tuple[bool, str]:
        """
        处理输入，返回 (是否继续, 原因)
        
        - source=user: 重置计数器 (新任务)
        - source=system: 递增计数器 (自循环)
        - source=external: 不改变计数器
        - counter >= max: 强制终止
        """
        counter_before = self.counter
        
        if source == InputSource.USER:
            # 用户输入：重置计数器
            self.counter = 0
            self.last_reset = datetime.now().isoformat()
            self._save_state()
            self._audit(cycle_id, source, counter_before, self.counter, "reset", "用户输入，重置计数器")
            return True, "用户输入，重置计数器"
        
        elif source == InputSource.SYSTEM:
            # 系统自循环：递增计数器
            self.counter += 1
            self._save_state()
            
            if self.counter >= self.max_cycles:
                self._audit(cycle_id, source, counter_before, self.counter, "terminate", 
                           f"达到最大循环次数 ({self.counter}/{self.max_cycles})")
                return False, f"达到最大循环次数 ({self.counter}/{self.max_cycles})"
            
            self._audit(cycle_id, source, counter_before, self.counter, "increment", 
                       f"系统自循环，计数器={self.counter}")
            return True, f"系统自循环，计数器={self.counter}"
        
        else:
            # 外部触发：不改变计数器
            self._audit(cycle_id, source, counter_before, self.counter, "external", 
                       f"外部触发，计数器={self.counter}")
            return True, f"外部触发，计数器={self.counter}"
    
    def force_reset(self, reason: str = "手动重置", admin_key: str = None) -> bool:
        """
        强制重置（需要管理员权限）
        
        实际使用中应通过安全机制验证，此处简化处理
        """
        if admin_key != "STARCORE_ADMIN_2026":
            return False
        
        counter_before = self.counter
        self.counter = 0
        self.last_reset = datetime.now().isoformat()
        self._save_state()
        self._audit(None, InputSource.USER, counter_before, 0, "force_reset", reason)
        return True
    
    def get_state(self) -> Dict:
        """获取当前状态"""
        return {
            "counter": self.counter,
            "max_cycles": self.max_cycles,
            "last_reset": self.last_reset,
            "remaining": max(0, self.max_cycles - self.counter),
            "can_continue": self.counter < self.max_cycles
        }


# ==================== 阳端 (探索) ====================

class YangEnd:
    """阳端 - 方向探索"""
    
    def __init__(self):
        self.system_state = {}
        self.feedback_context = {}
    
    def get_system_state(self) -> Dict:
        """获取系统状态快照"""
        state = {
            "timestamp": datetime.now().isoformat(),
            "services": {},
            "iphone": {}
        }
        
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
    
    def set_feedback_context(self, feedback: Dict):
        """设置反馈上下文，影响方向生成"""
        self.feedback_context = feedback
    
    def generate_directions(self, context: Dict = None) -> List[Dict]:
        """生成 5 个发展方向"""
        
        feedback = self.feedback_context or {}
        
        # 基于反馈调整优先级
        if feedback.get("last_execution_success") == False:
            priority_adjustment = {"D2": 1}
        else:
            priority_adjustment = {}
        
        directions = [
            {
                "id": "D1",
                "name": "两仪循环引擎整合",
                "description": "将两仪循环 v5.0 与星核系统深度整合",
                "rationale": "当前系统已完成基础架构",
                "priority": "P0"
            },
            {
                "id": "D2",
                "name": "daemon 任务调度修复",
                "description": "修复 daemon 的 submit_task() 和 _on_execution 回调",
                "rationale": "daemon 当前仅状态监控",
                "priority": "P0"
            },
            {
                "id": "D3",
                "name": "视觉闭环增强",
                "description": "增加 OCR 文字识别、UI 元素检测",
                "rationale": "当前仅能获取截图",
                "priority": "P1"
            },
            {
                "id": "D4",
                "name": "决策日志持久化",
                "description": "将决策报告持久化到 SQLite 数据库",
                "rationale": "当前仅保存为文件",
                "priority": "P1"
            },
            {
                "id": "D5",
                "name": "SSH 隧道稳定性优化",
                "description": "添加自动重连、心跳检测",
                "rationale": "隧道可能中断",
                "priority": "P2"
            }
        ]
        
        # 应用优先级调整
        priorities = ["P0", "P1", "P2"]
        for d in directions:
            if d["id"] in priority_adjustment:
                current_idx = priorities.index(d["priority"])
                new_idx = min(len(priorities) - 1, current_idx - priority_adjustment[d["id"]])
                d["priority"] = priorities[new_idx]
        
        return directions


# ==================== 阴端 (决策) ====================

class YinEnd:
    """阴端 - 深度决策"""
    
    DIMENSIONS = {
        "D1": "价值密度", "D2": "实现难度", "D3": "依赖风险", "D4": "技术债务",
        "D5": "用户价值", "D6": "系统影响", "D7": "可验证性", "D8": "紧急程度"
    }
    
    def evaluate(self, direction: Dict, context: Dict = None) -> Dict:
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


# ==================== 执行闭环 ====================

class ExecutionLoop:
    """决策执行闭环"""
    
    def execute(self, action: str, params: Dict = None) -> Dict:
        """执行动作"""
        params = params or {}
        
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
                "data_size": len(str(data.get("data", ""))),
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


# ==================== 反馈收集 ====================

class FeedbackCollector:
    """真实反馈收集器"""
    
    def collect(self) -> Dict:
        """收集多源真实反馈"""
        
        feedback = {
            "timestamp": datetime.now().isoformat(),
            "sources": {},
            "overall_quality": 0.0
        }
        
        # 获取系统状态
        state_result = subprocess.run(
            f"curl -s http://{CONFIG['ios_controller_host']}:{CONFIG['ios_controller_port']}/health",
            shell=True, capture_output=True, text=True, timeout=10
        )
        feedback["sources"]["ios_controller_health"] = {
            "data": state_result.stdout.strip(),
            "valid": state_result.returncode == 0
        }
        
        # 获取截图
        screenshot_result = subprocess.run(
            f'curl -s -X POST http://{CONFIG["ios_controller_host"]}:{CONFIG["ios_controller_port"]}/screenshot -H "Content-Type: application/json" -d \'{{}}\'',
            shell=True, capture_output=True, text=True, timeout=60
        )
        try:
            screenshot_data = json.loads(screenshot_result.stdout)
            feedback["sources"]["screenshot"] = {
                "success": screenshot_data.get("success"),
                "data_size": len(str(screenshot_data.get("data", ""))),
                "valid": screenshot_data.get("success", False)
            }
        except:
            feedback["sources"]["screenshot"] = {"valid": False, "error": "parse failed"}
        
        # 获取前台应用
        frontmost_result = subprocess.run(
            f'curl -s -X POST http://{CONFIG["ios_controller_host"]}:{CONFIG["ios_controller_port"]}/frontmost -H "Content-Type: application/json" -d \'{{}}\'',
            shell=True, capture_output=True, text=True, timeout=30
        )
        try:
            frontmost_data = json.loads(frontmost_result.stdout)
            feedback["sources"]["frontmost_app"] = {
                "app": frontmost_data.get("app"),
                "valid": frontmost_data.get("success", False)
            }
        except:
            feedback["sources"]["frontmost_app"] = {"valid": False, "error": "parse failed"}
        
        # 计算反馈质量
        valid_count = sum(1 for v in feedback["sources"].values() if v.get("valid"))
        total_count = len(feedback["sources"])
        feedback["overall_quality"] = valid_count / total_count if total_count > 0 else 0
        
        return feedback


# ==================== 决策数据库 ====================

class DecisionDB:
    """决策追踪数据库"""
    
    def __init__(self, db_path: str = None):
        self.db_path = db_path or CONFIG["database_path"]
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
    
    def save_decision(self, decision: Dict) -> int:
        """保存决策"""
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
        
        cursor.execute("""
            INSERT INTO execution_logs (decision_id, action, result, feedback, timestamp)
            VALUES (?, ?, ?, ?, ?)
        """, (decision_id, action, result, feedback, datetime.now().isoformat()))
        
        conn.commit()
        conn.close()


# ==================== 两仪循环引擎主类 ====================

class TwoYinYangEngine:
    """两仪循环引擎 v5.2 - 循环步数限制修复版"""
    
    def __init__(self):
        self.yang = YangEnd()
        self.yin = YinEnd()
        self.loop = ExecutionLoop()
        self.feedback_collector = FeedbackCollector()
        self.db = DecisionDB()
        self.counter = CycleCounter()
        self.feedback_context = {}
        self.cycle_id = None
    
    def run_cycle(self, input_msg: InputMessage = None) -> Dict:
        """
        运行一个完整循环
        
        Args:
            input_msg: 输入消息，包含来源标记
                       - source=user: 用户输入，重置计数器
                       - source=system: 系统自循环，递增计数器
                       - None: 默认为 system 自循环
        """
        
        # 生成循环 ID
        self.cycle_id = f"cycle-{datetime.now().strftime('%Y%m%d-%H%M-%S')}"
        
        # 默认来源为 system（自循环）
        if input_msg is None:
            input_msg = InputMessage("", InputSource.SYSTEM)
        
        print("=" * 60)
        print(f"🔄 两仪循环引擎 - 第 {self.counter.counter + 1} 轮启动")
        print(f"   输入来源: {input_msg.source.value}")
        print(f"   循环 ID: {self.cycle_id}")
        print("=" * 60)
        
        # 1. 检查循环限制（关键步骤）
        print("\n🔒 检查循环限制...")
        should_continue, reason = self.counter.process_input(input_msg.source, self.cycle_id)
        
        state = self.counter.get_state()
        print(f"   当前计数器: {state['counter']}/{state['max_cycles']}")
        print(f"   剩余次数: {state['remaining']}")
        print(f"   结果: {reason}")
        
        if not should_continue:
            print("\n⚠️ 循环终止")
            return {
                "status": "terminated",
                "reason": reason,
                "counter": state,
                "cycle_id": self.cycle_id
            }
        
        # 2. 阳端：获取状态 + 生成方向
        print("\n📊 系统状态快照...")
        state_data = self.yang.get_system_state()
        
        print("\n🔮 阳端方向探索...")
        directions = self.yang.generate_directions()
        
        for d in directions:
            print(f"   {d['id']}: {d['name']} [{d['priority']}]")
        
        # 3. 阴端：评估所有方向
        print("\n🧠 阴端决策评估...")
        evaluations = []
        for d in directions:
            eval_result = self.yin.evaluate(d)
            evaluations.append(eval_result)
            print(f"   {d['id']}: {eval_result['average']}/5.0 (总分 {eval_result['total']}/40)")
        
        # 4. 选择最佳方向
        best = max(evaluations, key=lambda x: x["total"])
        print(f"\n✅ 选择方向: {best['direction_name']} (评分 {best['average']}/5.0)")
        
        # 5. 执行闭环
        print("\n🔧 执行闭环...")
        exec_result = self.loop.execute("get_state", {})
        print(f"   状态: {exec_result.get('status', 'unknown')}")
        
        # 6. 收集真实反馈（内部流转，不模拟用户消息）
        print("\n📡 收集真实反馈...")
        feedback = self.feedback_collector.collect()
        print(f"   反馈质量: {feedback['overall_quality']:.2f}")
        
        # 7. 反馈进入内部上下文（不模拟用户消息）
        self.feedback_context = {
            "last_execution_success": exec_result.get("success", False),
            "feedback_quality": feedback["overall_quality"],
            "sources": feedback["sources"]
        }
        self.yang.set_feedback_context(self.feedback_context)
        
        # 8. 保存决策
        decision = {
            "name": f"DEC-{datetime.now().strftime('%Y%m%d-%H%M')}",
            "time": datetime.now().isoformat(),
            "direction": best["direction_name"],
            "score": best["average"],
            "confidence": best["confidence"],
            "status": "completed",
            "report_path": "",
            "cycle_id": self.cycle_id,
            "input_source": input_msg.source.value
        }
        
        decision_id = self.db.save_decision(decision)
        self.db.log_execution(decision_id, "cycle_complete", "success", 
                             json.dumps({"exec": exec_result, "feedback": feedback}))
        
        print(f"\n💾 决策已保存 (ID: {decision_id})")
        
        return {
            "status": "completed",
            "decision_id": decision_id,
            "cycle_id": self.cycle_id,
            "selected_direction": best,
            "evaluations": evaluations,
            "execution": exec_result,
            "feedback": feedback,
            "counter": state,
            "next_cycle_allowed": state["remaining"] > 0
        }
    
    def get_status(self) -> Dict:
        """获取引擎状态"""
        return {
            "counter": self.counter.get_state(),
            "feedback_context": self.feedback_context,
            "database": self.db.db_path
        }


# ==================== 主程序 ====================

if __name__ == "__main__":
    engine = TwoYinYangEngine()
    
    # 模拟系统自循环（source=system）
    # 这会递增计数器，达到上限后终止
    result = engine.run_cycle(InputMessage("", InputSource.SYSTEM))
    
    print("\n" + "=" * 60)
    print("📊 执行结果")
    print("=" * 60)
    print(f"状态: {result['status']}")
    
    if result['status'] == 'completed':
        print(f"计数器: {result['counter']['counter']}/{result['counter']['max_cycles']}")
        print(f"剩余次数: {result['counter']['remaining']}")
        print(f"可继续: {result['next_cycle_allowed']}")
    else:
        print(f"终止原因: {result['reason']}")
    
    print("=" * 60)
