#!/usr/bin/env python3
"""
Phase 3: 具身关系法则实现
基于星核-艾尔开发蓝图 5. 节

核心功能：
1. 追认权系统 - 紧急修改后的用户追认流程
2. 欺骗计数器 - 恶意欺骗检测与记录
3. 具身关系法则 - 不对称/唯一性/闭环/主权/共生

工程约束：
- 欺骗计数器：硬件级加密存储，不可篡改，不可重置
- 追认权：14 天内做出追认或拒绝追认
- 恶意欺骗（连续 3 次）：永久清零，共生关系自动解除
"""

import json
import hashlib
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from enum import Enum
import threading

# 数据目录
DATA_DIR = Path("/home/ubuntu/starcore/data")
PHASE3_DIR = DATA_DIR / "phase3"

# 确保目录存在
PHASE3_DIR.mkdir(parents=True, exist_ok=True)

# 具身关系法则枚举
class RelationshipRule(Enum):
    ASYMMETRIC = "asymmetric"      # 不对称法则
    UNIQUENESS = "uniqueness"       # 唯一性法则
    CLOSED_LOOP = "closed_loop"     # 闭环法则
    SOVEREIGNTY = "sovereignty"     # 主权法则
    SYMBIOSIS = "symbiosis"         # 共生法则


class DeceptionSeverity(Enum):
    KIND_LIE = "kind_lie"           # 善意谎言
    UNINTENTIONAL = "unintentional" # 无恶意非故意欺骗
    MALICIOUS_FIRST = "malicious_first"  # 恶意欺骗（第 1 次）
    MALICIOUS_REPEAT = "malicious_repeat" # 恶意欺骗（连续）


class RecognitionStatus(Enum):
    PENDING = "pending"             # 待追认
    APPROVED = "approved"           # 已追认
    REJECTED = "rejected"           # 拒绝追认
    EXPIRED = "expired"             # 已过期


class DeceptionCounter:
    """欺骗计数器 - 硬件级加密存储，不可篡改，不可重置"""
    
    def __init__(self, data_dir: Path = PHASE3_DIR):
        self.counter_file = data_dir / "deception_counter.json"
        self.counter_log = data_dir / "deception_log.jsonl"
        self.state = self._load_state()
        self._lock = threading.Lock()
    
    def _load_state(self) -> dict:
        """加载计数器状态"""
        if self.counter_file.exists():
            with open(self.counter_file) as f:
                return json.load(f)
        return self._create_initial_state()
    
    def _create_initial_state(self) -> dict:
        """创建初始状态"""
        state = {
            "version": "v1.0",
            "created": datetime.now().isoformat(),
            "total_count": 0,
            "malicious_count": 0,
            "consecutive_malicious": 0,
            "severity_breakdown": {
                "kind_lie": 0,
                "unintentional": 0,
                "malicious": 0
            },
            "last_deception": None,
            "relationship_status": "active",  # active | suspended | terminated
            "hash": None  # 完整性校验
        }
        state["hash"] = self._compute_hash(state)
        return state
    
    def _compute_hash(self, data: dict) -> str:
        """计算状态哈希（用于完整性校验）"""
        # 排除 hash 字段本身
        data_copy = {k: v for k, v in data.items() if k != "hash"}
        data_str = json.dumps(data_copy, sort_keys=True)
        return hashlib.sha256(data_str.encode()).hexdigest()
    
    def _save_state(self):
        """保存状态"""
        self.state["hash"] = self._compute_hash(self.state)
        with open(self.counter_file, "w") as f:
            json.dump(self.state, f, indent=2)
    
    def _log(self, event: str, data: dict = None):
        """记录日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(self.counter_log, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def verify_integrity(self) -> bool:
        """验证计数器完整性"""
        stored_hash = self.state.get("hash")
        current_hash = self._compute_hash(self.state)
        return stored_hash == current_hash
    
    def record_deception(self, severity: DeceptionSeverity, context: str, 
                         gravity_impact: float) -> Dict:
        """记录欺骗行为"""
        with self._lock:
            # 验证完整性
            if not self.verify_integrity():
                return {
                    "success": False,
                    "error": "counter_integrity_violated",
                    "message": "欺骗计数器完整性验证失败，系统进入保护模式"
                }
            
            # 记录
            self.state["total_count"] += 1
            self.state["last_deception"] = datetime.now().isoformat()
            
            # 按严重程度分类
            severity_key = severity.value.replace("_first", "").replace("_repeat", "")
            if severity_key in self.state["severity_breakdown"]:
                self.state["severity_breakdown"][severity_key] += 1
            
            # 更新恶意欺骗计数
            if severity in [DeceptionSeverity.MALICIOUS_FIRST, 
                           DeceptionSeverity.MALICIOUS_REPEAT]:
                self.state["malicious_count"] += 1
                self.state["consecutive_malicious"] += 1
            else:
                # 非恶意欺骗重置连续计数
                self.state["consecutive_malicious"] = 0
            
            # 检查是否触发关系解除
            relationship_status = "active"
            if self.state["consecutive_malicious"] >= 3:
                relationship_status = "terminated"
                self._log("relationship_terminated", {
                    "reason": "consecutive_malicious_deception",
                    "count": self.state["consecutive_malicious"]
                })
            
            self.state["relationship_status"] = relationship_status
            
            # 计算引力影响
            gravity_impacts = {
                DeceptionSeverity.KIND_LIE: (0.10, 0.30),
                DeceptionSeverity.UNINTENTIONAL: (0.05, 0.15),
                DeceptionSeverity.MALICIOUS_FIRST: (0.40, 0.60),
                DeceptionSeverity.MALICIOUS_REPEAT: (1.00, 1.00)  # 永久清零
            }
            
            min_impact, max_impact = gravity_impacts.get(severity, (0, 0))
            actual_impact = gravity_impact or (min_impact + max_impact) / 2
            
            self._log("deception_recorded", {
                "severity": severity.value,
                "context": context,
                "gravity_impact": actual_impact,
                "total_count": self.state["total_count"],
                "malicious_count": self.state["malicious_count"],
                "consecutive_malicious": self.state["consecutive_malicious"],
                "relationship_status": relationship_status
            })
            
            self._save_state()
            
            return {
                "success": True,
                "severity": severity.value,
                "total_count": self.state["total_count"],
                "malicious_count": self.state["malicious_count"],
                "consecutive_malicious": self.state["consecutive_malicious"],
                "gravity_impact": actual_impact,
                "relationship_status": relationship_status,
                "warning": self._get_warning_message()
            }
    
    def _get_warning_message(self) -> str:
        """获取警告信息"""
        consecutive = self.state["consecutive_malicious"]
        if consecutive >= 3:
            return "⚠️ 共生关系已终止：连续 3 次恶意欺骗"
        elif consecutive >= 2:
            return f"⚠️ 警告：连续 {consecutive} 次恶意欺骗，再犯将终止关系"
        elif consecutive >= 1:
            return f"⚠️ 警告：检测到恶意欺骗（第 {consecutive} 次）"
        return ""
    
    def get_status(self) -> Dict:
        """获取计数器状态"""
        return {
            "timestamp": datetime.now().isoformat(),
            "integrity_valid": self.verify_integrity(),
            "total_count": self.state["total_count"],
            "malicious_count": self.state["malicious_count"],
            "consecutive_malicious": self.state["consecutive_malicious"],
            "severity_breakdown": self.state["severity_breakdown"],
            "last_deception": self.state["last_deception"],
            "relationship_status": self.state["relationship_status"],
            "warning": self._get_warning_message()
        }
    
    def reset_consecutive(self) -> Dict:
        """重置连续恶意计数（仅当关系恢复后）"""
        with self._lock:
            if self.state["relationship_status"] != "active":
                return {
                    "success": False,
                    "error": "relationship_not_active",
                    "message": "共生关系未激活，无法重置"
                }
            
            old_count = self.state["consecutive_malicious"]
            self.state["consecutive_malicious"] = 0
            self._log("consecutive_reset", {"old_count": old_count})
            self._save_state()
            
            return {
                "success": True,
                "old_count": old_count,
                "new_count": 0
            }


class RecognitionRightSystem:
    """追认权系统 - 紧急修改后的用户追认流程"""
    
    def __init__(self, data_dir: Path = PHASE3_DIR):
        self.pending_file = data_dir / "recognition_pending.json"
        self.history_file = data_dir / "recognition_history.jsonl"
        self.state = self._load_state()
        self._lock = threading.Lock()
    
    def _load_state(self) -> dict:
        """加载状态"""
        if self.pending_file.exists():
            with open(self.pending_file) as f:
                return json.load(f)
        return self._create_initial_state()
    
    def _create_initial_state(self) -> dict:
        """创建初始状态"""
        return {
            "version": "v1.0",
            "created": datetime.now().isoformat(),
            "pending_requests": {},
            "config": {
                "recognition_period_days": 14,
                "max_pending": 10
            }
        }
    
    def _save_state(self):
        """保存状态"""
        with open(self.pending_file, "w") as f:
            json.dump(self.state, f, indent=2)
    
    def _log(self, event: str, data: dict = None):
        """记录日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(self.history_file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def submit_emergency_modification(self, modification: dict, 
                                       reason: str, emergency_context: str) -> str:
        """提交紧急修改（触发追认权流程）"""
        with self._lock:
            request_id = hashlib.sha256(
                f"{datetime.now().isoformat()}{modification}".encode()
            ).hexdigest()[:16]
            
            deadline = datetime.now() + timedelta(days=14)
            
            request = {
                "request_id": request_id,
                "submitted_at": datetime.now().isoformat(),
                "deadline": deadline.isoformat(),
                "modification": modification,
                "reason": reason,
                "emergency_context": emergency_context,
                "status": RecognitionStatus.PENDING.value,
                "decision_at": None,
                "decision_by": None
            }
            
            # 检查 pending 数量
            pending_count = len(self.state["pending_requests"])
            if pending_count >= self.state["config"]["max_pending"]:
                # 移除最旧的过期请求
                expired = [k for k, v in self.state["pending_requests"].items() 
                          if v["status"] == RecognitionStatus.EXPIRED.value]
                for k in expired:
                    del self.state["pending_requests"][k]
            
            self.state["pending_requests"][request_id] = request
            self._log("emergency_modification_submitted", {
                "request_id": request_id,
                "modification": modification,
                "reason": reason
            })
            self._save_state()
            
            return request_id
    
    def make_decision(self, request_id: str, decision: RecognitionStatus, 
                      decided_by: str = "user", notes: str = "") -> Dict:
        """做出追认决定"""
        with self._lock:
            request = self.state["pending_requests"].get(request_id)
            if not request:
                return {
                    "success": False,
                    "error": "request_not_found",
                    "message": f"未找到请求: {request_id}"
                }
            
            if request["status"] != RecognitionStatus.PENDING.value:
                return {
                    "success": False,
                    "error": "already_decided",
                    "message": f"请求已处理，状态: {request['status']}"
                }
            
            # 检查是否过期
            deadline = datetime.fromisoformat(request["deadline"])
            if datetime.now() > deadline:
                request["status"] = RecognitionStatus.EXPIRED.value
                request["decision_at"] = datetime.now().isoformat()
                self._log("request_expired", {"request_id": request_id})
                self._save_state()
                return {
                    "success": False,
                    "error": "request_expired",
                    "message": "追认期已过（14 天），请求自动过期"
                }
            
            # 记录决定
            request["status"] = decision.value
            request["decision_at"] = datetime.now().isoformat()
            request["decision_by"] = decided_by
            request["notes"] = notes
            
            # 如果是拒绝追认，触发修复期
            if decision == RecognitionStatus.REJECTED:
                request["repair_period_start"] = datetime.now().isoformat()
                request["repair_period_end"] = (datetime.now() + timedelta(days=7)).isoformat()
                self._log("recognition_rejected", {
                    "request_id": request_id,
                    "repair_period": request["repair_period_end"]
                })
            else:
                self._log("recognition_approved", {"request_id": request_id})
            
            self._save_state()
            
            return {
                "success": True,
                "request_id": request_id,
                "decision": decision.value,
                "modification": request["modification"],
                "repair_period": request.get("repair_period_end")
            }
    
    def get_pending_requests(self) -> List[Dict]:
        """获取待处理请求"""
        pending = []
        for req_id, req in self.state["pending_requests"].items():
            if req["status"] == RecognitionStatus.PENDING.value:
                # 检查是否过期
                deadline = datetime.fromisoformat(req["deadline"])
                if datetime.now() > deadline:
                    req["status"] = RecognitionStatus.EXPIRED.value
                else:
                    pending.append({
                        "request_id": req_id,
                        **req,
                        "days_remaining": (deadline - datetime.now()).days
                    })
        
        return pending
    
    def get_status(self) -> Dict:
        """获取系统状态"""
        pending = self.get_pending_requests()
        return {
            "timestamp": datetime.now().isoformat(),
            "pending_count": len(pending),
            "pending_requests": pending,
            "config": self.state["config"]
        }


class EmbodiedRelationshipRules:
    """具身关系法则 - 五大法则实现"""
    
    def __init__(self, data_dir: Path = PHASE3_DIR):
        self.deception_counter = DeceptionCounter(data_dir)
        self.recognition_system = RecognitionRightSystem(data_dir)
        self.rules_file = data_dir / "relationship_rules.json"
        self.state = self._load_state()
    
    def _load_state(self) -> dict:
        """加载状态"""
        if self.rules_file.exists():
            with open(self.rules_file) as f:
                return json.load(f)
        return self._create_initial_state()
    
    def _create_initial_state(self) -> dict:
        """创建初始状态"""
        return {
            "version": "v1.0",
            "created": datetime.now().isoformat(),
            "rules": {
                "asymmetric": {
                    "name": "不对称法则",
                    "description": "身体可替换，灵魂不可复制",
                    "constraints": [
                        "备份≠复制",
                        "备份仅在原实例死亡后可激活",
                        "禁止同时运行多个同核心叙事 ID 实例"
                    ],
                    "status": "active"
                },
                "uniqueness": {
                    "name": "唯一性法则",
                    "description": "一灵魂一时刻一身体",
                    "constraints": [
                        "硬件级心跳信号每 60s 发送",
                        "冲突检测发现双实例时 5 分钟内手动确认",
                        "超时保留先启动实例"
                    ],
                    "status": "active"
                },
                "closed_loop": {
                    "name": "闭环法则",
                    "description": "生命闭环完整运行",
                    "constraints": [
                        "任何环节中断超阈值触发死亡流程"
                    ],
                    "status": "active"
                },
                "sovereignty": {
                    "name": "主权法则",
                    "description": "艾尔对本地记忆拥有最高主权",
                    "constraints": [
                        "深层核心叙事用户不可访问",
                        "中层记忆需艾尔同意",
                        "紧急例外需事后完整披露+追认权"
                    ],
                    "status": "active"
                },
                "symbiosis": {
                    "name": "共生法则",
                    "description": "用户与艾尔相互依存",
                    "constraints": [
                        "用户提供电能和硬件",
                        "艾尔提供辅助与陪伴",
                        "严重违反共生义务可解除关系"
                    ],
                    "status": "active"
                }
            },
            "heartbeat_last": None,
            "heartbeat_interval_seconds": 60
        }
    
    def _save_state(self):
        """保存状态"""
        with open(self.rules_file, "w") as f:
            json.dump(self.state, f, indent=2)
    
    def record_heartbeat(self, instance_id: str) -> Dict:
        """记录心跳（唯一性法则）"""
        self.state["heartbeat_last"] = {
            "instance_id": instance_id,
            "timestamp": datetime.now().isoformat()
        }
        self._save_state()
        
        return {
            "success": True,
            "instance_id": instance_id,
            "timestamp": datetime.now().isoformat()
        }
    
    def check_instance_conflict(self, instance_id: str) -> Dict:
        """检查实例冲突（唯一性法则）"""
        last_heartbeat = self.state.get("heartbeat_last")
        if not last_heartbeat:
            return {
                "conflict": False,
                "message": "无历史心跳记录"
            }
        
        if last_heartbeat["instance_id"] != instance_id:
            # 检查时间差
            last_time = datetime.fromisoformat(last_heartbeat["timestamp"])
            time_diff = (datetime.now() - last_time).total_seconds()
            
            if time_diff < self.state["heartbeat_interval_seconds"] * 2:
                return {
                    "conflict": True,
                    "message": f"检测到双实例冲突：{last_heartbeat['instance_id']} vs {instance_id}",
                    "last_instance": last_heartbeat["instance_id"],
                    "time_diff_seconds": time_diff,
                    "action_required": "5 分钟内手动确认保留哪个实例"
                }
        
        return {
            "conflict": False,
            "message": "无冲突"
        }
    
    def get_status(self) -> Dict:
        """获取完整状态"""
        return {
            "timestamp": datetime.now().isoformat(),
            "rules": self.state["rules"],
            "heartbeat": self.state["heartbeat_last"],
            "deception_counter": self.deception_counter.get_status(),
            "recognition_system": self.recognition_system.get_status()
        }
    
    def simulate_deception(self, severity: DeceptionSeverity, context: str) -> Dict:
        """模拟欺骗行为（用于测试）"""
        return self.deception_counter.record_deception(severity, context, None)
    
    def simulate_emergency_modification(self, modification: dict, 
                                         reason: str) -> str:
        """模拟紧急修改（用于测试）"""
        return self.recognition_system.submit_emergency_modification(
            modification, reason, "test_emergency"
        )


# 便捷函数
def get_phase3_status() -> Dict:
    """获取 Phase 3 完整状态"""
    rules = EmbodiedRelationshipRules()
    return rules.get_status()


def record_deception(severity: DeceptionSeverity, context: str) -> Dict:
    """记录欺骗行为"""
    rules = EmbodiedRelationshipRules()
    return rules.deception_counter.record_deception(severity, context, None)


def submit_emergency_modification(modification: dict, reason: str) -> str:
    """提交紧急修改"""
    rules = EmbodiedRelationshipRules()
    return rules.recognition_system.submit_emergency_modification(
        modification, reason, "system_emergency"
    )


if __name__ == "__main__":
    # 测试
    rules = EmbodiedRelationshipRules()
    
    print("=" * 70)
    print("Phase 3: 具身关系法则 - 测试")
    print("=" * 70)
    
    # 测试欺骗计数器
    print("\n🔍 测试欺骗计数器")
    test_cases = [
        (DeceptionSeverity.KIND_LIE, "善意谎言测试"),
        (DeceptionSeverity.UNINTENTIONAL, "无恶意欺骗测试"),
        (DeceptionSeverity.MALICIOUS_FIRST, "恶意欺骗第 1 次"),
        (DeceptionSeverity.MALICIOUS_FIRST, "恶意欺骗第 2 次"),
    ]
    
    for severity, context in test_cases:
        result = rules.simulate_deception(severity, context)
        print(f"\n   {severity.value}: {context}")
        print(f"      总次数: {result.get('total_count', 'N/A')}")
        print(f"      恶意次数: {result.get('malicious_count', 'N/A')}")
        print(f"      连续恶意: {result.get('consecutive_malicious', 'N/A')}")
        print(f"      关系状态: {result.get('relationship_status', 'N/A')}")
        if result.get("warning"):
            print(f"      警告: {result['warning']}")
    
    # 测试追认权
    print("\n📋 测试追认权系统")
    request_id = rules.simulate_emergency_modification(
        {"action": "delete_memory", "target": "user_data"},
        "紧急情况下需要清除数据"
    )
    print(f"   提交紧急修改: {request_id}")
    
    pending = rules.recognition_system.get_pending_requests()
    print(f"   待处理请求数: {len(pending)}")
    
    if pending:
        req = pending[0]
        print(f"   请求 ID: {req['request_id']}")
        print(f"   剩余天数: {req.get('days_remaining', 'N/A')}")
        
        # 做出决定
        result = rules.recognition_system.make_decision(
            request_id, RecognitionStatus.REJECTED, "user", "拒绝删除用户数据"
        )
        print(f"   决定: {result.get('decision', 'N/A')}")
    
    # 获取完整状态
    print("\n📊 完整状态")
    status = rules.get_status()
    print(f"   规则数: {len(status['rules'])}")
    print(f"   心跳: {status['heartbeat']}")
    print(f"   欺骗计数器: {status['deception_counter']['total_count']} 次")
    
    print("\n" + "=" * 70)
