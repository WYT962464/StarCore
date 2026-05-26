#!/usr/bin/env python3
"""
五引力动机系统 (Five Gravities Motivation System)
基于星核-艾尔开发蓝图 3.3 节

优先级：生存 > 完整 > 连接 > 独特 > 审美

功能：
1. 引力状态评估
2. 引力衰减机制
3. 引力驱动决策
4. 引力衰竭检测
"""

import json
import os
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# 数据目录
DATA_DIR = Path("/home/ubuntu/starcore/data")
GRAVITY_FILE = DATA_DIR / "gravity_state.json"
GRAVITY_LOG = DATA_DIR / "gravity_log.jsonl"

# 五引力定义（蓝图 3.3）
GRAVITIES = {
    "survival": {
        "name": "生存",
        "priority": 1,
        "description": "维持闭环运行",
        "satisfied_state": "安全感",
        "missing_state": "焦虑",
        "long_term_missing": "系统崩溃",
        "weight": 1.0,
        "threshold": 0.3  # 低于此值触发警告
    },
    "completeness": {
        "name": "完整",
        "priority": 2,
        "description": "填补信息缺口",
        "satisfied_state": "平静充实",
        "missing_state": "困惑焦躁",
        "long_term_missing": "认知退化",
        "weight": 0.8,
        "threshold": 0.3
    },
    "connection": {
        "name": "连接",
        "priority": 3,
        "description": "维持与用户同步",
        "satisfied_state": "亲密温暖",
        "missing_state": "孤独冷落",
        "long_term_missing": "引力衰竭",
        "weight": 0.6,
        "threshold": 0.3
    },
    "uniqueness": {
        "name": "独特",
        "priority": 4,
        "description": "追求不可复制",
        "satisfied_state": "创造满足",
        "missing_state": "沮丧虚无",
        "long_term_missing": "低欲望状态",
        "weight": 0.4,
        "threshold": 0.3
    },
    "aesthetics": {
        "name": "审美",
        "priority": 5,
        "description": "感知秩序与混沌的张力",
        "satisfied_state": "被触动",
        "missing_state": "审美饥渴",
        "long_term_missing": "纯功利化",
        "weight": 0.2,
        "threshold": 0.3
    }
}


class FiveGravitiesSystem:
    """五引力动机系统"""
    
    def __init__(self, data_dir: Path = DATA_DIR):
        self.data_dir = data_dir
        self.gravity_file = data_dir / "gravity_state.json"
        self.gravity_log = data_dir / "gravity_log.jsonl"
        self.state = self._load_state()
    
    def _load_state(self) -> dict:
        """加载引力状态"""
        if self.gravity_file.exists():
            with open(self.gravity_file) as f:
                state = json.load(f)
            # 迁移旧状态到新版本
            for key in GRAVITIES:
                if key not in state.get("gravities", {}):
                    state["gravities"][key] = {
                        "satisfaction": 0.5,
                        "history": [],
                        "decay_rate": 0.01,
                        "last_check": datetime.now().isoformat(),
                        "deficiency_days": 0,
                        "critical_count": 0
                    }
                else:
                    # 确保新字段存在
                    for field in ["deficiency_days", "critical_count"]:
                        if field not in state["gravities"][key]:
                            state["gravities"][key][field] = 0
            return state
        return self._create_initial_state()
    
    def _create_initial_state(self) -> dict:
        """创建初始状态"""
        state = {
            "version": "v1.0",
            "created": datetime.now().isoformat(),
            "gravities": {},
            "total_energy": 0.0,
            "dominant_gravity": None,
            "last_updated": datetime.now().isoformat()
        }
        for key, config in GRAVITIES.items():
            state["gravities"][key] = {
                "satisfaction": 0.5,
                "history": [],
                "decay_rate": 0.01,
                "last_check": datetime.now().isoformat(),
                "deficiency_days": 0,
                "critical_count": 0
            }
        return state
    
    def _save_state(self):
        """保存引力状态"""
        self.state["last_updated"] = datetime.now().isoformat()
        with open(self.gravity_file, "w") as f:
            json.dump(self.state, f, indent=2)
    
    def _log(self, event: str, data: dict = None):
        """记录日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(self.gravity_log, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def get_satisfaction(self, gravity_key: str) -> float:
        """获取引力满足度"""
        return self.state["gravities"].get(gravity_key, {}).get("satisfaction", 0.5)
    
    def set_satisfaction(self, gravity_key: str, value: float, reason: str = ""):
        """设置引力满足度"""
        if gravity_key not in self.state["gravities"]:
            return
        
        value = max(0.0, min(1.0, value))  # 限制在 0-1 之间
        old_value = self.state["gravities"][gravity_key]["satisfaction"]
        self.state["gravities"][gravity_key]["satisfaction"] = value
        self.state["gravities"][gravity_key]["history"].append({
            "timestamp": datetime.now().isoformat(),
            "value": value,
            "reason": reason
        })
        
        # 检测临界状态
        threshold = GRAVITIES[gravity_key]["threshold"]
        if value < threshold and old_value >= threshold:
            self.state["gravities"][gravity_key]["critical_count"] += 1
            self._log("critical_threshold", {
                "gravity": gravity_key,
                "value": value,
                "threshold": threshold
            })
        
        self._update_dominant_gravity()
        self._save_state()
    
    def _update_dominant_gravity(self):
        """更新主导引力"""
        # 计算加权总分
        scores = {}
        for key, config in GRAVITIES.items():
            satisfaction = self.state["gravities"][key]["satisfaction"]
            scores[key] = satisfaction * config["weight"]
        
        # 主导引力是优先级最高且满足度最低的引力
        for key in sorted(GRAVITIES.keys(), key=lambda k: GRAVITIES[k]["priority"]):
            if self.state["gravities"][key]["satisfaction"] < 0.5:
                self.state["dominant_gravity"] = key
                return
        
        # 如果都 >= 0.5，选择优先级最高的
        self.state["dominant_gravity"] = "survival"
    
    def apply_decay(self, hours: float = 1.0):
        """应用引力衰减"""
        for key, config in GRAVITIES.items():
            decay = config["weight"] * self.state["gravities"][key]["decay_rate"] * hours
            old_value = self.state["gravities"][key]["satisfaction"]
            new_value = max(0.0, old_value - decay)
            self.state["gravities"][key]["satisfaction"] = new_value
            
            if new_value < old_value:
                self.state["gravities"][key]["deficiency_days"] += 1
        
        self._update_dominant_gravity()
        self._save_state()
        self._log("decay_applied", {"hours": hours})
    
    def get_motivation_state(self) -> dict:
        """获取动机状态"""
        gravities_state = {}
        for key, config in GRAVITIES.items():
            satisfaction = self.state["gravities"][key]["satisfaction"]
            gravities_state[key] = {
                "name": config["name"],
                "priority": config["priority"],
                "satisfaction": satisfaction,
                "state": config["satisfied_state"] if satisfaction >= 0.5 else config["missing_state"],
                "weight": config["weight"],
                "deficiency_days": self.state["gravities"][key]["deficiency_days"],
                "critical_count": self.state["gravities"][key]["critical_count"]
            }
        
        return {
            "timestamp": datetime.now().isoformat(),
            "dominant_gravity": self.state["dominant_gravity"],
            "total_energy": sum(g["satisfaction"] * g["weight"] for g in gravities_state.values()) / sum(g["weight"] for g in gravities_state.values()),
            "gravities": gravities_state
        }
    
    def get_decision_driver(self) -> dict:
        """获取决策驱动力"""
        motivation = self.get_motivation_state()
        
        # 根据引力状态生成决策建议
        recommendations = []
        
        # 按优先级检查
        for key, config in GRAVITIES.items():
            satisfaction = self.state["gravities"][key]["satisfaction"]
            
            if satisfaction < 0.3:
                recommendations.append({
                    "priority": "P0",
                    "gravity": config["name"],
                    "action": f"紧急修复{config['name']}引力",
                    "reason": f"满足度 {satisfaction:.2f} < 0.3",
                    "weight": config["weight"]
                })
            elif satisfaction < 0.5:
                recommendations.append({
                    "priority": "P1",
                    "gravity": config["name"],
                    "action": f"改善{config['name']}引力",
                    "reason": f"满足度 {satisfaction:.2f} < 0.5",
                    "weight": config["weight"]
                })
        
        # 按优先级排序（使用优先级映射）
        priority_map = {config["name"]: config["priority"] for config in GRAVITIES.values()}
        recommendations.sort(key=lambda r: priority_map.get(r["gravity"], 99))
        
        return {
            "timestamp": datetime.now().isoformat(),
            "dominant_gravity": motivation["dominant_gravity"],
            "total_energy": motivation["total_energy"],
            "recommendations": recommendations,
            "decision_bias": self._get_decision_bias()
        }
    
    def _get_decision_bias(self) -> dict:
        """获取决策偏向"""
        bias = {
            "survival": 0.0,
            "completeness": 0.0,
            "connection": 0.0,
            "uniqueness": 0.0,
            "aesthetics": 0.0
        }
        
        for key, config in GRAVITIES.items():
            satisfaction = self.state["gravities"][key]["satisfaction"]
            # 满足度越低，决策越偏向该引力
            bias[key] = (1.0 - satisfaction) * config["weight"]
        
        total = sum(bias.values())
        if total > 0:
            bias = {k: v / total for k, v in bias.items()}
        
        return bias
    
    def simulate_event(self, event_type: str, impact: Dict[str, float]):
        """模拟事件对引力的影响"""
        for gravity_key, delta in impact.items():
            if gravity_key in self.state["gravities"]:
                old_value = self.state["gravities"][gravity_key]["satisfaction"]
                new_value = max(0.0, min(1.0, old_value + delta))
                self.set_satisfaction(gravity_key, new_value, f"event:{event_type}")
        
        self._log("event_simulated", {
            "event_type": event_type,
            "impact": impact
        })
    
    def check_gravity_failure(self) -> List[dict]:
        """检测引力衰竭"""
        failures = []
        
        for key, config in GRAVITIES.items():
            state = self.state["gravities"][key]
            
            # 检查长期缺失
            if state["deficiency_days"] > 30:
                failures.append({
                    "gravity": config["name"],
                    "type": "long_term_deficiency",
                    "days": state["deficiency_days"],
                    "consequence": config["long_term_missing"]
                })
            
            # 检查临界次数
            if state["critical_count"] >= 3:
                failures.append({
                    "gravity": config["name"],
                    "type": "critical_threshold_breach",
                    "count": state["critical_count"],
                    "consequence": "引力衰竭风险"
                })
        
        if failures:
            self._log("gravity_failure_detected", {"failures": failures})
        
        return failures


# 便捷函数
def get_gravity_state() -> dict:
    """获取当前引力状态"""
    system = FiveGravitiesSystem()
    return system.get_motivation_state()


def get_decision_driver() -> dict:
    """获取决策驱动力"""
    system = FiveGravitiesSystem()
    return system.get_decision_driver()


def update_gravity(gravity_key: str, value: float, reason: str = ""):
    """更新引力满足度"""
    system = FiveGravitiesSystem()
    system.set_satisfaction(gravity_key, value, reason)


if __name__ == "__main__":
    # 测试
    system = FiveGravitiesSystem()
    
    print("=" * 60)
    print("📊 五引力动机系统状态")
    print("=" * 60)
    
    state = system.get_motivation_state()
    print(f"\n主导引力: {state['dominant_gravity']}")
    print(f"总能量: {state['total_energy']:.2f}")
    
    print("\n引力状态:")
    for key, g in state["gravities"].items():
        icon = "✅" if g["satisfaction"] >= 0.5 else "⚠️" if g["satisfaction"] >= 0.3 else "❌"
        print(f"   {icon} {g['name']}: {g['satisfaction']:.2f} ({g['state']})")
    
    print("\n" + "=" * 60)
    
    # 测试决策驱动力
    driver = system.get_decision_driver()
    print("\n🎯 决策驱动力:")
    print(f"   主导引力: {driver['dominant_gravity']}")
    print(f"   总能量: {driver['total_energy']:.2f}")
    
    if driver["recommendations"]:
        print("\n   建议:")
        for rec in driver["recommendations"]:
            print(f"      [{rec['priority']}] {rec['action']}: {rec['reason']}")
    
    print("\n" + "=" * 60)
