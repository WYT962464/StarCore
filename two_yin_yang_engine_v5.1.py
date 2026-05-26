#!/usr/bin/env python3
"""
两仪循环引擎 v5.1 - 真实回传机制修正版
阴阳相生相克的自进化决策系统

修正: 真实回传必须来自系统自主执行结果，禁止模拟用户消息绕过限制
"""

import json
import subprocess
import sqlite3
import os
import time
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
    
    # 循环限制
    "max_cycles": 10,
    "cycle_timeout": 300,
    "feedback_threshold": 0.7,
    "min_feedback_latency": 1.0,  # 最小反馈延迟 (秒)
}

# 允许的反馈来源白名单
ALLOWED_FEEDBACK_SOURCES = [
    "ios_mcp_screenshot",
    "ios_mcp_frontmost_app",
    "ios_mcp_screen_info",
    "ios_controller_log",
    "decision_database",
    "system_health_check",
]

# 允许的反馈类型
EXPECTED_FEEDBACK_TYPES = [
    "visual",
    "state",
    "performance",
    "error",
    "success",
]


# ==================== 异常类 ====================

class BypassDetectionError(Exception):
    """绕过检测异常"""
    pass


class FeedbackValidationError(Exception):
    """反馈验证异常"""
    pass


class CycleLimitError(Exception):
    """循环限制异常"""
    pass


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
        
        # 基于反馈上下文调整方向优先级
        feedback = self.feedback_context or {}
        
        # 如果上次执行失败，提高修复类方向优先级
        if feedback.get("last_execution_success") == False:
            priority_adjustment = {"D2": 1}  # daemon 修复优先级提升
        else:
            priority_adjustment = {}
        
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
        
        # 应用优先级调整
        for d in directions:
            if d["id"] in priority_adjustment:
                priorities = ["P0", "P1", "P2"]
                current_idx = priorities.index(d["priority"])
                new_idx = min(len(priorities) - 1, current_idx - priority_adjustment[d["id"]])
                d["priority"] = priorities[new_idx]
        
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


# ==================== 真实反馈获取 ====================

class FeedbackCollector:
    """真实反馈获取器 - 禁止模拟用户消息"""
    
    def __init__(self):
        self.allowed_sources = ALLOWED_FEEDBACK_SOURCES
    
    def collect(self, sources: List[str] = None) -> Dict:
        """收集多源真实反馈"""
        
        if sources is None:
            sources = ["ios_mcp_screenshot", "ios_mcp_frontmost_app", "ios_mcp_screen_info"]
        
        feedback = {
            "timestamp": datetime.now().isoformat(),
            "sources": {},
            "overall_quality": 0.0,
            "validation_passed": True,
            "bypass_detected": False
        }
        
        for source in sources:
            if source not in self.allowed_sources:
                feedback["validation_passed"] = False
                feedback["bypass_detected"] = True
                feedback["sources"][source] = {"error": f"非法反馈来源: {source}"}
                continue
            
            start_time = time.time()
            
            try:
                if source == "ios_mcp_screenshot":
                    result = self._get_screenshot()
                elif source == "ios_mcp_frontmost_app":
                    result = self._get_frontmost_app()
                elif source == "ios_mcp_screen_info":
                    result = self._get_screen_info()
                elif source == "system_health_check":
                    result = self._check_system_health()
                else:
                    result = {"error": f"未知反馈源: {source}"}
                
                latency = time.time() - start_time
                
                # 检测异常快速反馈 (可能为模拟)
                if latency < CONFIG["min_feedback_latency"]:
                    feedback["validation_passed"] = False
                    feedback["bypass_detected"] = True
                    feedback["sources"][source] = {
                        "error": f"反馈时间异常 ({latency:.2f}s < {CONFIG['min_feedback_latency']}s)",
                        "data": result
                    }
                    continue
                
                feedback["sources"][source] = {
                    "data": result,
                    "latency": round(latency, 2),
                    "valid": True
                }
                
            except Exception as e:
                feedback["sources"][source] = {"error": str(e), "valid": False}
        
        # 计算整体反馈质量
        valid_count = sum(1 for s in feedback["sources"].values() if s.get("valid"))
        feedback["overall_quality"] = valid_count / len(sources) if sources else 0
        
        return feedback
    
    def _get_screenshot(self) -> Dict:
        """获取屏幕截图"""
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
            return {"success": False, "error": "JSON parse failed"}
    
    def _get_frontmost_app(self) -> Dict:
        """获取前台应用"""
        host = CONFIG['ios_controller_host']
        port = CONFIG['ios_controller_port']
        cmd = f'curl -s -X POST http://{host}:{port}/frontmost -H "Content-Type: application/json" -d \'{{}}\''
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        
        try:
            data = json.loads(result.stdout)
            return data
        except:
            return {"success": False, "error": "Failed to get frontmost app"}
    
    def _get_screen_info(self) -> Dict:
        """获取屏幕信息"""
        host = CONFIG['ios_controller_host']
        port = CONFIG['ios_controller_port']
        cmd = f'curl -s http://{host}:{port}/state'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        
        try:
            return json.loads(result.stdout)
        except:
            return {"success": False, "error": "Failed to get screen info"}
    
    def _check_system_health(self) -> Dict:
        """检查系统健康"""
        health = {}
        
        services = {
            "ssh": f"ssh -p {CONFIG['ssh_port']} -o StrictHostKeyChecking=no -o ConnectTimeout=5 {CONFIG['ssh_user']}@{CONFIG['ssh_host']} 'echo OK'",
            "ios_controller": f"curl -s http://{CONFIG['ios_controller_host']}:{CONFIG['ios_controller_port']}/health",
            "daemon": f"curl -s http://{CONFIG['daemon_host']}:{CONFIG['daemon_port']}/health",
        }
        
        for name, cmd in services.items():
            try:
                result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
                health[name] = {
                    "status": "ok" if result.returncode == 0 else "error",
                    "output": result.stdout.strip()[:100]
                }
            except Exception as e:
                health[name] = {"status": "error", "output": str(e)}
        
        return health


# ==================== 反馈学习 ====================

class FeedbackLearner:
    """反馈学习器 - 根据反馈更新决策权重"""
    
    def __init__(self, db_path: str = None):
        self.db_path = db_path or CONFIG["database_path"]
        self.learning_history = []
    
    def learn(self, decision: Dict, feedback: Dict) -> Dict:
        """根据反馈学习"""
        
        learning_result = {
            "decision_id": decision.get("id"),
            "feedback_quality": feedback.get("overall_quality", 0),
            "weight_updates": {},
            "bias_detected": False,
            "recommendations": []
        }
        
        # 如果反馈质量高，增加相关方向权重
        if feedback.get("overall_quality", 0) >= CONFIG["feedback_threshold"]:
            learning_result["recommendations"].append("执行成功，维持当前方向优先级")
        else:
            learning_result["bias_detected"] = True
            learning_result["recommendations"].append("反馈质量低，建议调整方向优先级")
        
        # 记录学习历史
        self.learning_history.append({
            "timestamp": datetime.now().isoformat(),
            "decision": decision,
            "feedback": feedback,
            "result": learning_result
        })
        
        return learning_result
    
    def get_bias_trace(self, decision: Dict, actual_outcome: Dict) -> List[str]:
        """偏差溯源五步法"""
        
        steps = []
        
        # 1. 识别偏差
        expected = decision.get("expected_outcome", {})
        actual = actual_outcome.get("outcome", {})
        deviation = self._calculate_deviation(expected, actual)
        steps.append(f"偏差识别: {deviation}")
        
        # 2. 定位来源
        source = self._identify_bias_source(decision, actual_outcome)
        steps.append(f"来源定位: {source}")
        
        # 3. 分析原因
        cause = self._analyze_cause(source, decision.get("context", {}))
        steps.append(f"原因分析: {cause}")
        
        # 4. 修正方案
        correction = self._generate_correction(cause)
        steps.append(f"修正方案: {correction}")
        
        # 5. 验证效果
        steps.append("验证效果: 待下一轮循环验证")
        
        return steps
    
    def _calculate_deviation(self, expected: Dict, actual: Dict) -> str:
        """计算偏差"""
        # 简化版：比较关键字段
        deviations = []
        for key in expected:
            if expected[key] != actual.get(key):
                deviations.append(f"{key}: 预期={expected[key]}, 实际={actual.get(key)}")
        return "; ".join(deviations) if deviations else "无偏差"
    
    def _identify_bias_source(self, decision: Dict, outcome: Dict) -> str:
        """定位偏差来源"""
        # 简化版
        if outcome.get("feedback_quality", 1) < 0.5:
            return "反馈质量不足"
        elif outcome.get("execution_success") == False:
            return "执行失败"
        else:
            return "评估偏差"
    
    def _analyze_cause(self, source: str, context: Dict) -> str:
        """分析原因"""
        causes = {
            "反馈质量不足": "反馈数据不完整或不可靠",
            "执行失败": "执行环境或命令错误",
            "评估偏差": "8 维评估矩阵权重设置不当"
        }
        return causes.get(source, "未知原因")
    
    def _generate_correction(self, cause: str) -> str:
        """生成修正方案"""
        corrections = {
            "反馈数据不完整或不可靠": "增加反馈源，提高反馈质量阈值",
            "执行环境或命令错误": "检查执行环境，修复命令",
            "评估矩阵权重设置不当": "调整 8 维评估权重，增加反向验证"
        }
        return corrections.get(cause, "需要进一步分析")


# ==================== 决策执行闭环 ====================

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
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS feedback_audit (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cycle_id INTEGER,
                feedback_source TEXT,
                feedback_type TEXT,
                feedback_latency REAL,
                is_validated BOOLEAN,
                bypass_detected BOOLEAN,
                timestamp TEXT
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
    
    def log_feedback_audit(self, cycle_id: int, source: str, feedback_type: str, 
                           latency: float, is_validated: bool, bypass_detected: bool):
        """记录反馈审计"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO feedback_audit (cycle_id, feedback_source, feedback_type, 
                                        feedback_latency, is_validated, bypass_detected, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (cycle_id, source, feedback_type, latency, is_validated, bypass_detected, datetime.now().isoformat()))
        
        conn.commit()
        conn.close()


# ==================== 两仪循环引擎主类 ====================

class TwoYinYangEngine:
    """两仪循环引擎 v5.1 - 真实回传机制修正版"""
    
    def __init__(self):
        self.yang = YangEnd()
        self.yin = YinEnd()
        self.loop = ExecutionLoop()
        self.feedback_collector = FeedbackCollector()
        self.learner = FeedbackLearner()
        self.db = DecisionDB()
        self.cycle_count = 0
        self.consecutive_same_decisions = 0
        self.last_decision = None
    
    def should_terminate(self, feedback_quality: float, decision_confidence: float) -> Tuple[bool, str]:
        """检查是否应该终止循环"""
        
        # 条件 1: 达到最大循环次数
        if self.cycle_count >= CONFIG["max_cycles"]:
            return True, f"达到最大循环次数 ({self.cycle_count}/{CONFIG['max_cycles']})"
        
        # 条件 2: 反馈质量过低
        if feedback_quality < CONFIG["feedback_threshold"]:
            return True, f"反馈质量不足 ({feedback_quality:.2f} < {CONFIG['feedback_threshold']})"
        
        # 条件 3: 决策置信度过低
        if decision_confidence < 0.5:
            return True, "决策置信度过低"
        
        # 条件 4: 连续相同决策 (可能陷入局部最优)
        if self.consecutive_same_decisions >= 3:
            return True, f"连续相同决策 {self.consecutive_same_decisions} 次，可能陷入局部最优"
        
        return False, "继续循环"
    
    def run_cycle(self, context: Dict = None) -> Dict:
        """运行一个完整循环"""
        
        self.cycle_count += 1
        
        print("=" * 60)
        print(f"🔄 两仪循环引擎 - 第 {self.cycle_count} 轮启动")
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
        
        # 检查连续相同决策
        if self.last_decision == best["direction_name"]:
            self.consecutive_same_decisions += 1
        else:
            self.consecutive_same_decisions = 1
        self.last_decision = best["direction_name"]
        
        print(f"\n✅ 选择方向: {best['direction_name']} (评分 {best['average']}/5.0)")
        print(f"   连续相同决策: {self.consecutive_same_decisions} 次")
        
        # 4. 执行闭环
        print("\n🔧 执行闭环...")
        exec_result = self.loop.execute("get_state", {})
        print(f"   状态: {exec_result.get('status', 'unknown')}")
        
        # 5. 收集真实反馈 (禁止模拟用户消息)
        print("\n📡 收集真实反馈...")
        feedback = self.feedback_collector.collect()
        print(f"   反馈质量: {feedback['overall_quality']:.2f}")
        print(f"   验证通过: {feedback['validation_passed']}")
        print(f"   绕过检测: {feedback['bypass_detected']}")
        
        # 记录反馈审计
        for source, data in feedback.get("sources", {}).items():
            self.db.log_feedback_audit(
                cycle_id=self.cycle_count,
                source=source,
                feedback_type="state",
                latency=data.get("latency", 0),
                is_validated=data.get("valid", False),
                bypass_detected=feedback["bypass_detected"]
            )
        
        # 检查是否应该终止
        should_stop, reason = self.should_terminate(
            feedback["overall_quality"],
            best["average"] / 5.0
        )
        
        if should_stop:
            print(f"\n⚠️ 终止条件触发: {reason}")
        
        # 6. 反馈学习
        print("\n📚 反馈学习...")
        decision_record = {
            "id": f"DEC-{datetime.now().strftime('%Y%m%d-%H%M')}",
            "expected_outcome": exec_result,
            "context": context or {}
        }
        learning_result = self.learner.learn(decision_record, feedback)
        
        if learning_result["bias_detected"]:
            print("   ⚠️ 检测到偏差，建议调整方向优先级")
            bias_trace = self.learner.get_bias_trace(decision_record, {
                "outcome": exec_result,
                "feedback_quality": feedback["overall_quality"]
            })
            for step in bias_trace:
                print(f"   - {step}")
        else:
            print("   ✅ 无偏差，维持当前优先级")
        
        # 7. 设置反馈上下文供下一轮使用
        self.yang.set_feedback_context({
            "last_execution_success": exec_result.get("success", False),
            "feedback_quality": feedback["overall_quality"],
            "bypass_detected": feedback["bypass_detected"]
        })
        
        # 8. 保存决策
        decision = {
            "name": f"DEC-{datetime.now().strftime('%Y%m%d-%H%M')}",
            "time": datetime.now().isoformat(),
            "direction": best["direction_name"],
            "score": best["average"],
            "confidence": best["confidence"],
            "status": "completed" if not should_stop else "terminated",
            "report_path": ""
        }
        
        decision_id = self.db.save_decision(decision)
        self.db.log_execution(decision_id, "cycle_complete", "success", 
                             json.dumps({"exec": exec_result, "feedback": feedback}))
        
        print(f"\n💾 决策已保存 (ID: {decision_id})")
        
        return {
            "decision_id": decision_id,
            "cycle_count": self.cycle_count,
            "selected_direction": best,
            "evaluations": evaluations,
            "execution": exec_result,
            "feedback": feedback,
            "learning": learning_result,
            "should_terminate": should_stop,
            "terminate_reason": reason
        }


# ==================== 主程序 ====================

if __name__ == "__main__":
    engine = TwoYinYangEngine()
    result = engine.run_cycle()
    print("\n" + "=" * 60)
    if result["should_terminate"]:
        print(f"⚠️ 循环终止: {result['terminate_reason']}")
    else:
        print("🎉 循环完成，可继续下一轮")
    print("=" * 60)
