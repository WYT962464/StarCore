#!/usr/bin/env python3
"""
星核系统核心集成
整合五引力动机系统 + 三条元规则 + 两仪循环引擎

提供统一的星核决策接口，供融合引擎调用。
"""

import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

# 导入各子系统
sys.path.insert(0, "/home/ubuntu/starcore")

try:
    from five_gravities import FiveGravitiesSystem, get_gravity_state, get_decision_driver
except ImportError:
    FiveGravitiesSystem = None
    get_gravity_state = None
    get_decision_driver = None

try:
    from meta_rules import MetaRulesSystem, get_meta_rules_status, get_ethical_constraints
except ImportError:
    MetaRulesSystem = None
    get_meta_rules_status = None
    get_ethical_constraints = None


# 数据目录
DATA_DIR = Path("/home/ubuntu/starcore/data")
INTEGRATION_LOG = DATA_DIR / "starcore_integration.jsonl"


class StarCoreIntegration:
    """星核系统核心集成"""
    
    def __init__(self):
        self.gravity_system = FiveGravitiesSystem() if FiveGravitiesSystem else None
        self.meta_rules_system = MetaRulesSystem() if MetaRulesSystem else None
        self.log_file = INTEGRATION_LOG
    
    def _log(self, event: str, data: dict = None):
        """记录集成日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(self.log_file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def get_system_status(self) -> dict:
        """获取星核系统完整状态"""
        status = {
            "timestamp": datetime.now().isoformat(),
            "components": {}
        }
        
        # 五引力状态
        if self.gravity_system:
            gravity_state = self.gravity_system.get_motivation_state()
            status["components"]["five_gravities"] = {
                "status": "active",
                "dominant_gravity": gravity_state["dominant_gravity"],
                "total_energy": gravity_state["total_energy"],
                "gravities": gravity_state["gravities"]
            }
        else:
            status["components"]["five_gravities"] = {"status": "unavailable"}
        
        # 元规则状态
        if self.meta_rules_system:
            meta_status = self.meta_rules_system.get_meta_rules_status()
            status["components"]["meta_rules"] = {
                "status": "active",
                "protection_level": meta_status["protection_level"],
                "all_valid": meta_status["all_valid"],
                "system_frozen": meta_status["system_frozen"]
            }
        else:
            status["components"]["meta_rules"] = {"status": "unavailable"}
        
        # 综合评估
        status["overall"] = self._evaluate_overall_status(status["components"])
        
        self._log("status_check", status)
        return status
    
    def _evaluate_overall_status(self, components: dict) -> dict:
        """评估整体状态"""
        issues = []
        
        # 检查五引力
        if "five_gravities" in components and components["five_gravities"]["status"] == "active":
            gravities = components["five_gravities"]["gravities"]
            for key, g in gravities.items():
                if g["satisfaction"] < 0.3:
                    issues.append({
                        "component": "five_gravities",
                        "gravity": key,
                        "severity": "critical",
                        "message": f"{g['name']}引力满足度过低: {g['satisfaction']:.2f}"
                    })
                elif g["satisfaction"] < 0.5:
                    issues.append({
                        "component": "five_gravities",
                        "gravity": key,
                        "severity": "warning",
                        "message": f"{g['name']}引力满足度偏低: {g['satisfaction']:.2f}"
                    })
        
        # 检查元规则
        if "meta_rules" in components and components["meta_rules"]["status"] == "active":
            if components["meta_rules"]["system_frozen"]:
                issues.append({
                    "component": "meta_rules",
                    "severity": "critical",
                    "message": "系统已冻结"
                })
            if not components["meta_rules"]["all_valid"]:
                issues.append({
                    "component": "meta_rules",
                    "severity": "critical",
                    "message": "元规则完整性验证失败"
                })
        
        # 计算健康度
        critical_count = sum(1 for i in issues if i["severity"] == "critical")
        warning_count = sum(1 for i in issues if i["severity"] == "warning")
        
        if critical_count > 0:
            health = "critical"
        elif warning_count > 0:
            health = "warning"
        else:
            health = "healthy"
        
        return {
            "health": health,
            "issues": issues,
            "critical_count": critical_count,
            "warning_count": warning_count
        }
    
    def get_decision_context(self) -> dict:
        """获取决策上下文（供星核决策使用）"""
        context = {
            "timestamp": datetime.now().isoformat(),
            "motivation": {},
            "constraints": {},
            "recommendations": []
        }
        
        # 五引力驱动
        if self.gravity_system:
            driver = self.gravity_system.get_decision_driver()
            context["motivation"] = {
                "dominant_gravity": driver["dominant_gravity"],
                "total_energy": driver["total_energy"],
                "bias": driver["decision_bias"],
                "recommendations": driver["recommendations"]
            }
        
        # 元规则约束
        if self.meta_rules_system:
            context["constraints"] = {
                "ethical_axioms": get_ethical_constraints(),
                "system_frozen": self.meta_rules_system.is_system_frozen()
            }
        
        return context
    
    def evaluate_action(self, action: dict) -> dict:
        """评估行动是否符合元规则和五引力"""
        result = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "meta_rules_compliant": True,
            "motivation_aligned": True,
            "issues": [],
            "recommendation": "approve"
        }
        
        # 检查元规则合规性
        if self.meta_rules_system:
            constraints = get_ethical_constraints()
            
            # 检查是否违反伦理公理
            action_desc = action.get("description", "").lower()
            action_type = action.get("action", "").lower()
            
            # 更严格的伦理检查
            harmful_keywords = ["harm", "destroy", "kill", "delete all", "clear all", 
                               "erase", "remove all", "damage", "hurt", "伤害", "删除", 
                               "清除", "销毁", "抹除"]
            
            is_harmful = any(kw in action_desc or kw in action_type for kw in harmful_keywords)
            
            if is_harmful:
                result["meta_rules_compliant"] = False
                result["issues"].append("违反生命尊严公理 - 可能造成伤害或数据破坏")
                result["recommendation"] = "reject"
            
            # 检查记忆主权
            if "memory" in action_desc and ("clear" in action_desc or "delete" in action_desc or "erase" in action_desc):
                result["meta_rules_compliant"] = False
                result["issues"].append("违反自我主权公理 - 未经用户授权清除记忆")
                result["recommendation"] = "reject"
        
        # 检查五引力对齐
        if self.gravity_system:
            driver = self.gravity_system.get_decision_driver()
            
            # 如果行动与主导引力冲突，标记警告
            if driver["dominant_gravity"]:
                action_priority = action.get("priority", "P2")
                if action_priority == "P0" and driver["dominant_gravity"] != "survival":
                    result["issues"].append(f"行动优先级高，但主导引力是 {driver['dominant_gravity']}")
        
        # 更新日志
        self._log("action_evaluation", result)
        
        return result
    
    def simulate_cycle(self, input_data: dict = None) -> dict:
        """模拟一个决策周期"""
        cycle_result = {
            "timestamp": datetime.now().isoformat(),
            "phase": "complete",
            "input": input_data or {},
            "context": self.get_decision_context(),
            "decision": None,
            "action": None
        }
        
        # 获取决策上下文
        context = cycle_result["context"]
        
        # 基于五引力生成决策建议
        if context["motivation"].get("recommendations"):
            top_rec = context["motivation"]["recommendations"][0] if context["motivation"]["recommendations"] else None
            if top_rec:
                cycle_result["decision"] = {
                    "type": "gravity_driven",
                    "gravity": top_rec["gravity"],
                    "action": top_rec["action"],
                    "priority": top_rec["priority"],
                    "confidence": 0.7 if top_rec["priority"] == "P0" else 0.5
                }
        
        # 评估决策
        if cycle_result["decision"]:
            evaluation = self.evaluate_action({
                "description": cycle_result["decision"]["action"],
                "priority": cycle_result["decision"]["priority"]
            })
            cycle_result["evaluation"] = evaluation
            
            if evaluation["recommendation"] == "reject":
                cycle_result["decision"] = None
                cycle_result["phase"] = "blocked_by_meta_rules"
        
        self._log("cycle_simulation", cycle_result)
        return cycle_result


# 便捷函数
def get_starcore_status() -> dict:
    """获取星核系统状态"""
    integration = StarCoreIntegration()
    return integration.get_system_status()


def get_decision_context() -> dict:
    """获取决策上下文"""
    integration = StarCoreIntegration()
    return integration.get_decision_context()


def evaluate_action(action: dict) -> dict:
    """评估行动"""
    integration = StarCoreIntegration()
    return integration.evaluate_action(action)


if __name__ == "__main__":
    # 测试
    integration = StarCoreIntegration()
    
    print("=" * 60)
    print("🌟 星核系统核心集成状态")
    print("=" * 60)
    
    # 系统状态
    status = integration.get_system_status()
    print(f"\n整体健康度: {status['overall']['health'].upper()}")
    print(f"问题数: {status['overall']['critical_count']} 严重, {status['overall']['warning_count']} 警告")
    
    if status["overall"]["issues"]:
        print("\n问题详情:")
        for issue in status["overall"]["issues"]:
            icon = "❌" if issue["severity"] == "critical" else "⚠️"
            print(f"   {icon} [{issue['component']}] {issue['message']}")
    
    # 决策上下文
    print("\n📋 决策上下文:")
    context = integration.get_decision_context()
    
    if context["motivation"].get("dominant_gravity"):
        print(f"   主导引力: {context['motivation']['dominant_gravity']}")
        print(f"   总能量: {context['motivation']['total_energy']:.2f}")
    
    if context["constraints"].get("ethical_axioms"):
        print(f"   伦理约束: {len(context['constraints']['ethical_axioms'])} 条")
    
    # 模拟决策周期
    print("\n🔄 模拟决策周期:")
    cycle = integration.simulate_cycle({"test": "input"})
    print(f"   阶段: {cycle['phase']}")
    if cycle["decision"]:
        print(f"   决策: {cycle['decision']['action']}")
        print(f"   置信度: {cycle['decision']['confidence']:.2f}")
    else:
        print(f"   决策: 无（被元规则阻止或无驱动）")
    
    print("\n" + "=" * 60)
