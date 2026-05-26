#!/usr/bin/env python3
"""
星核系统 — 自循环执行引擎 v1.0

真正的自循环 = 感知 → 决策 → 执行 → 反馈 → 感知...

不再等待用户输入，系统自己完成闭环。

架构：
┌─────────────────────────────────────────────────────────────┐
│                    自循环执行引擎                              │
├─────────────────────────────────────────────────────────────┤
│  1. 感知层：自动获取系统状态（daemon/CycleSystem/iOS）          │
│  2. 决策层：两仪循环引擎 + 阿腾认知核心自动校准                  │
│  3. 执行层：Hermes 工具调用（terminal/file/search 等）          │
│  4. 反馈层：执行结果回传，更新决策数据库                        │
└─────────────────────────────────────────────────────────────┘

循环周期：每 60 秒自动触发一轮（可配置）
"""

import json
import time
import threading
import subprocess
import sqlite3
import os
from datetime import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field
from enum import Enum
import sys

# 导入两仪循环引擎
sys.path.insert(0, '/home/ubuntu/starcore')
import importlib.util
spec = importlib.util.spec_from_file_location("engine", "/home/ubuntu/starcore/two_yin_yang_engine_v5.3.py")
engine_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine_module)
TwoYinYangEngine = engine_module.TwoYinYangEngine
YangDirection = engine_module.YangDirection
AtengCalibrationResult = engine_module.AtengCalibrationResult
ateng_calibrate = engine_module.ateng_calibrate

# ==================== 循环阶段 ====================

class CyclePhase(Enum):
    PERCEPTION = "感知"      # 获取系统状态
    DECISION = "决策"        # 两仪循环决策
    EXECUTION = "执行"       # 执行工具调用
    FEEDBACK = "反馈"        # 结果回传
    CALIBRATION = "校准"     # 阿腾校准（迷茫时）

@dataclass
class CycleRecord:
    """自循环记录"""
    cycle_id: int
    phase: CyclePhase
    timestamp: str
    input_state: Dict = field(default_factory=dict)
    decision: Dict = field(default_factory=dict)
    execution_result: Dict = field(default_factory=dict)
    feedback: Dict = field(default_factory=dict)
    ateng_calibration: Optional[Dict] = None
    duration_ms: int = 0

# ==================== 感知层 ====================

class PerceptionLayer:
    """感知层：自动获取系统状态"""
    
    def __init__(self):
        self.daemon_url = "http://localhost:9090"
        self.cycle_url = "http://localhost:9092"
        self.controller_url = "http://localhost:9091"
    
    def _curl(self, url: str, timeout: int = 3) -> Optional[Dict]:
        """执行 curl 请求"""
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
    
    def get_system_state(self) -> Dict:
        """获取完整系统状态"""
        state = {
            "timestamp": datetime.now().isoformat(),
            "daemon": None,
            "cycle_system": None,
            "ios_controller": None,
            "memory": None,
            "decision_count": 0
        }
        
        # daemon 状态
        daemon_status = self._curl(f"{self.daemon_url}/health")
        if daemon_status:
            state["daemon"] = daemon_status
        
        # CycleSystem 状态
        cycle_status = self._curl(f"{self.cycle_url}/state")
        if cycle_status:
            state["cycle_system"] = cycle_status
        
        # iOS Controller 状态
        controller_status = self._curl(f"{self.controller_url}/health")
        if controller_status:
            state["ios_controller"] = controller_status
        
        # 服务器内存
        try:
            result = subprocess.run(["free", "-m"], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) >= 2:
                    parts = lines[1].split()
                    state["memory"] = {
                        "total_mb": int(parts[1]),
                        "used_mb": int(parts[2]),
                        "available_mb": int(parts[6])
                    }
        except Exception:
            pass
        
        # 决策数据库
        try:
            conn = sqlite3.connect("/home/ubuntu/starcore/data/decisions.db")
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM decisions")
            state["decision_count"] = cursor.fetchone()[0]
            conn.close()
        except Exception:
            pass
        
        return state
    
    def detect_issues(self, state: Dict) -> List[Dict]:
        """检测系统问题"""
        issues = []
        
        # 检查 daemon
        if not state.get("daemon"):
            issues.append({
                "severity": "critical",
                "component": "daemon",
                "message": "daemon 服务不可用"
            })
        
        # 检查 CycleSystem
        if not state.get("cycle_system"):
            issues.append({
                "severity": "critical",
                "component": "cycle_system",
                "message": "CycleSystem 不可用"
            })
        elif state.get("cycle_system"):
            energy = state["cycle_system"].get("energy", {}).get("cognitive", 0)
            if energy < 30:
                issues.append({
                    "severity": "warning",
                    "component": "cycle_system",
                    "message": f"认知能量过低：{energy:.1f}%"
                })
            entropy = state["cycle_system"].get("entropy", {}).get("value", 0)
            if entropy > 0.6:
                issues.append({
                    "severity": "warning",
                    "component": "cycle_system",
                    "message": f"熵值过高（混乱）：{entropy:.2f}"
                })
            elif entropy < 0.2:
                issues.append({
                    "severity": "warning",
                    "component": "cycle_system",
                    "message": f"熵值过低（死锁）：{entropy:.2f}"
                })
        
        # 检查 iOS Controller
        if not state.get("ios_controller"):
            issues.append({
                "severity": "critical",
                "component": "ios_controller",
                "message": "iOS Controller 不可用"
            })
        
        # 检查内存
        if state.get("memory"):
            available = state["memory"].get("available_mb", 0)
            if available < 500:
                issues.append({
                    "severity": "warning",
                    "component": "memory",
                    "message": f"可用内存不足：{available}MB"
                })
        
        return issues

# ==================== 执行层 ====================

class ExecutionLayer:
    """执行层：调用 Hermes 工具"""
    
    def __init__(self):
        self.execution_log: List[Dict] = []
    
    def execute_command(self, command: str, workdir: str = None) -> Dict:
        """执行 shell 命令"""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30,
                cwd=workdir
            )
            return {
                "command": command,
                "exit_code": result.returncode,
                "stdout": result.stdout[:2000],
                "stderr": result.stderr[:1000],
                "success": result.returncode == 0
            }
        except subprocess.TimeoutExpired:
            return {
                "command": command,
                "exit_code": -1,
                "error": "Timeout",
                "success": False
            }
        except Exception as e:
            return {
                "command": command,
                "exit_code": -1,
                "error": str(e),
                "success": False
            }
    
    def execute_task(self, task: Dict) -> Dict:
        """执行任务"""
        task_type = task.get("type")
        
        if task_type == "command":
            result = self.execute_command(task.get("command", ""))
        elif task_type == "check_health":
            result = self.execute_command("curl -s http://localhost:9090/health")
        elif task_type == "restart_service":
            service = task.get("service", "")
            if service == "daemon":
                result = self.execute_command("pkill -f starcore-daemon && sleep 2 && cd /home/ubuntu/StarCore && python3 starcore-daemon-v6.py &")
            elif service == "cycle":
                result = self.execute_command("pkill -f CycleSystem/main.py && sleep 2 && cd /home/ubuntu/StarCore/Core/CycleSystem && python3 main.py --port 9092 &")
            else:
                result = {"success": False, "error": f"Unknown service: {service}"}
        elif task_type == "log_status":
            timestamp = datetime.now().isoformat()
            log_file = "/home/ubuntu/starcore/data/cycle_log.jsonl"
            with open(log_file, "a") as f:
                f.write(json.dumps({"timestamp": timestamp, "action": "status_logged"}) + "\n")
            result = {"success": True, "message": "Status logged"}
        else:
            result = {"success": False, "error": f"Unknown task type: {task_type}"}
        
        self.execution_log.append({
            "timestamp": datetime.now().isoformat(),
            "task": task,
            "result": result
        })
        
        return result

# ==================== 自循环引擎 ====================

class SelfCycleEngine:
    """自循环执行引擎 v1.0"""
    
    def __init__(self, cycle_interval: int = 60):
        self.cycle_interval = cycle_interval  # 秒
        self.running = False
        self.cycle_count = 0
        self.cycle_history: List[CycleRecord] = []
        
        self.perception = PerceptionLayer()
        self.decision_engine = TwoYinYangEngine()
        self.executor = ExecutionLayer()
        
        self._ensure_dirs()
    
    def _ensure_dirs(self):
        """确保目录存在"""
        os.makedirs("/home/ubuntu/starcore/data", exist_ok=True)
        os.makedirs("/home/ubuntu/starcore/logs", exist_ok=True)
    
    def _run_cycle(self):
        """执行一轮自循环"""
        self.cycle_count += 1
        cycle_id = self.cycle_count
        cycle_start = time.time()
        
        record = CycleRecord(
            cycle_id=cycle_id,
            phase=CyclePhase.PERCEPTION,
            timestamp=datetime.now().isoformat()
        )
        
        print(f"\n{'=' * 60}")
        print(f"🔄 自循环 #{cycle_id} 开始")
        print(f"{'=' * 60}")
        
        try:
            # ===== 1. 感知 =====
            record.phase = CyclePhase.PERCEPTION
            print("\n📡 感知层：获取系统状态...")
            state = self.perception.get_system_state()
            record.input_state = state
            print(f"   daemon: {'✅' if state.get('daemon') else '❌'}")
            print(f"   CycleSystem: {'✅' if state.get('cycle_system') else '❌'}")
            print(f"   iOS Controller: {'✅' if state.get('ios_controller') else '❌'}")
            print(f"   决策记录: {state.get('decision_count', 0)} 条")
            
            # 检测问题
            issues = self.perception.detect_issues(state)
            if issues:
                print(f"\n⚠️ 检测到 {len(issues)} 个问题：")
                for issue in issues:
                    print(f"   [{issue['severity']}] {issue['component']}: {issue['message']}")
            
            # ===== 2. 决策 =====
            record.phase = CyclePhase.DECISION
            print("\n🧠 决策层：两仪循环决策...")
            
            # 构建决策输入
            if issues:
                input_text = f"系统问题：{json.dumps(issues, ensure_ascii=False)}"
            else:
                input_text = "系统运行正常，继续监控"
            
            decision = self.decision_engine.process(input_text)
            record.decision = decision
            
            # 检查阿腾校准
            if decision.get("ateng_calibration"):
                record.phase = CyclePhase.CALIBRATION
                record.ateng_calibration = decision["ateng_calibration"]
                print(f"\n📌 阿腾校准：{decision['ateng_calibration'].get('校准建议', '')}")
            
            print(f"   决策：{decision.get('final_decision', 'N/A')}")
            print(f"   置信度：{decision.get('confidence', 0):.2f}")
            
            # ===== 3. 执行 =====
            record.phase = CyclePhase.EXECUTION
            print("\n⚡ 执行层：执行任务...")
            
            # 根据决策生成执行任务
            tasks = self._generate_tasks(decision, issues)
            
            for i, task in enumerate(tasks):
                print(f"   任务 {i+1}: {task.get('type', 'unknown')}")
                result = self.executor.execute_task(task)
                print(f"            {'✅' if result.get('success') else '❌'}")
                record.execution_result = result
            
            # ===== 4. 反馈 =====
            record.phase = CyclePhase.FEEDBACK
            print("\n📤 反馈层：记录循环结果...")
            
            # 保存循环记录
            self._save_cycle_record(record)
            
            duration_ms = int((time.time() - cycle_start) * 1000)
            record.duration_ms = duration_ms
            
            print(f"\n✅ 自循环 #{cycle_id} 完成 ({duration_ms}ms)")
            print(f"{'=' * 60}")
            
        except Exception as e:
            print(f"\n❌ 自循环 #{cycle_id} 失败：{e}")
            record.phase = CyclePhase.PERCEPTION
            record.feedback = {"error": str(e)}
        
        self.cycle_history.append(record)
        # 保留最近 100 条记录
        if len(self.cycle_history) > 100:
            self.cycle_history = self.cycle_history[-100:]
    
    def _generate_tasks(self, decision: Dict, issues: List[Dict]) -> List[Dict]:
        """根据决策和问题生成执行任务"""
        tasks = []
        
        # 如果有 critical 问题，优先修复
        critical_issues = [i for i in issues if i.get("severity") == "critical"]
        if critical_issues:
            for issue in critical_issues:
                if issue["component"] == "daemon":
                    tasks.append({"type": "restart_service", "service": "daemon"})
                elif issue["component"] == "cycle_system":
                    tasks.append({"type": "restart_service", "service": "cycle"})
                elif issue["component"] == "ios_controller":
                    tasks.append({"type": "check_health", "target": "ios_controller"})
        
        # 如果没有问题，定期记录状态
        if not tasks:
            tasks.append({"type": "log_status"})
        
        return tasks
    
    def _save_cycle_record(self, record: CycleRecord):
        """保存循环记录"""
        log_file = "/home/ubuntu/starcore/data/self_cycle_log.jsonl"
        with open(log_file, "a") as f:
            f.write(json.dumps({
                "cycle_id": record.cycle_id,
                "phase": record.phase.value,
                "timestamp": record.timestamp,
                "input_state": record.input_state,
                "decision": record.decision,
                "execution_result": record.execution_result,
                "feedback": record.feedback,
                "ateng_calibration": record.ateng_calibration,
                "duration_ms": record.duration_ms
            }, ensure_ascii=False) + "\n")
    
    def start(self):
        """启动自循环"""
        if self.running:
            print("⚠️ 自循环已在运行")
            return
        
        self.running = True
        print("\n🚀 自循环执行引擎 v1.0 启动")
        print(f"   循环周期：{self.cycle_interval} 秒")
        print(f"   启动时间：{datetime.now().isoformat()}")
        
        def cycle_loop():
            while self.running:
                self._run_cycle()
                # 等待下一个周期
                for _ in range(self.cycle_interval):
                    if not self.running:
                        break
                    time.sleep(1)
        
        # 启动循环线程
        thread = threading.Thread(target=cycle_loop, daemon=True)
        thread.start()
        
        print("✅ 自循环已启动（后台运行）")
    
    def stop(self):
        """停止自循环"""
        self.running = False
        print("\n🛑 自循环已停止")
    
    def get_status(self) -> Dict:
        """获取状态"""
        return {
            "running": self.running,
            "cycle_count": self.cycle_count,
            "cycle_interval": self.cycle_interval,
            "last_cycle": self.cycle_history[-1].to_dict() if self.cycle_history else None,
            "recent_cycles": [
                {
                    "cycle_id": r.cycle_id,
                    "timestamp": r.timestamp,
                    "phase": r.phase.value,
                    "duration_ms": r.duration_ms
                }
                for r in self.cycle_history[-10:]
            ]
        }

# ==================== 主程序 ====================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="星核自循环执行引擎")
    parser.add_argument("--interval", type=int, default=60, help="循环周期（秒）")
    parser.add_argument("--once", action="store_true", help="只运行一轮")
    parser.add_argument("--status", action="store_true", help="查看状态")
    
    args = parser.parse_args()
    
    engine = SelfCycleEngine(cycle_interval=args.interval)
    
    if args.status:
        print(json.dumps(engine.get_status(), indent=2, ensure_ascii=False))
    elif args.once:
        engine._run_cycle()
    else:
        engine.start()
        
        # 保持主线程运行
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            engine.stop()
