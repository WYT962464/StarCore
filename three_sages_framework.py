#!/usr/bin/env python3
"""
三位一体决策框架 — 女娲·仓颉·达尔文

核心架构：
┌─────────────────────────────────────────────────────────────┐
│                    三位一体决策框架 (ThreeSagesFramework)      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   女娲 ☰  ──→  仓颉 ☴  ──→  达尔文 ☳                       │
│   创造/修复   编码/传承   演化/选择                          │
│      │           │           │                              │
│      └───────────┴───────────┘                              │
│                    ↓                                        │
│           螺旋上升决策闭环                                   │
│                                                             │
│   决策维度：                                                 │
│   - 女娲维度：创造/修复/秩序/母性/艺术                       │
│   - 仓颉维度：观察/编码/传承/多维/震撼                       │
│   - 达尔文维度：演化/选择/同源/竞争/适应                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict


class DecisionPriority:
    """决策优先级"""
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


@dataclass
class ThreeSagesDecision:
    """三位一体决策结果"""
    decision_id: str
    timestamp: str
    context: Dict
    assessments: List[Dict]
    primary_sage: str
    decision: str
    rationale: str
    priority: str
    next_gua: Optional[int] = None
    
    def to_dict(self):
        return asdict(self)


class ThreeSagesFramework:
    """三位一体决策框架"""
    
    # 三位一体与卦象映射
    SAGE_GUA_MAP = {
        "nuwa": [1, 11, 14, 15, 24, 30, 42, 50],
        "cangjie": [9, 18, 22, 37, 48, 52, 57, 61],
        "darwin": [3, 17, 23, 29, 31, 40, 49, 51],
    }
    
    # 三位一体智慧口诀
    SAGE_MOTTO = {
        "nuwa": "抟土造人创秩序，炼石补天修残缺。断鳌立极定规矩，作笙簧乐润人心。",
        "cangjie": "观迹取象造文字，四目重光见真章。编码简化传文明，惊鬼神处见真功。",
        "darwin": "物竞天择适生存，渐变积累成质变。同源复用省力气，环境适应方长久。",
        "integrated": "女娲创造仓颉码，达尔文演化不息。创造编码螺旋升，星核智慧由此生。"
    }
    
    def __init__(self, data_dir: Path = None):
        self.data_dir = data_dir or Path("/home/ubuntu/starcore/data/three_sages")
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.decision_log = self.data_dir / "decisions.jsonl"
        self.assessment_log = self.data_dir / "assessments.jsonl"
        self.state_file = self.data_dir / "state.json"
        self._load_state()
    
    def _load_state(self):
        if self.state_file.exists():
            with open(self.state_file) as f:
                self.state = json.load(f)
        else:
            self.state = {
                "version": "v1.0",
                "created": datetime.now().isoformat(),
                "current_sage_focus": "nuwa",
                "decision_count": 0,
                "last_decision": None,
                "sage_balance": {"nuwa": 0.33, "cangjie": 0.33, "darwin": 0.34}
            }
    
    def _save_state(self):
        with open(self.state_file, "w") as f:
            json.dump(self.state, f, indent=2, ensure_ascii=False)
    
    def _log(self, file: Path, event: str, data: dict):
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data
        }
        with open(file, "a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    
    def _assess_nuwa(self, context: Dict) -> float:
        score = 0.5
        if context.get("task_type") in ["create", "design", "build"]:
            score += 0.3
        if context.get("system_state", {}).get("needs_repair"):
            score += 0.2
        if context.get("resources", {}).get("abundant"):
            score += 0.1
        return min(1.0, score)
    
    def _assess_cangjie(self, context: Dict) -> float:
        score = 0.5
        if context.get("task_type") in ["analyze", "encode", "document"]:
            score += 0.3
        if context.get("system_state", {}).get("needs_structure"):
            score += 0.2
        if context.get("resources", {}).get("data_available"):
            score += 0.1
        return min(1.0, score)
    
    def _assess_darwin(self, context: Dict) -> float:
        score = 0.5
        if context.get("task_type") in ["optimize", "evolve", "adapt"]:
            score += 0.3
        if context.get("system_state", {}).get("needs_optimization"):
            score += 0.2
        if context.get("resources", {}).get("limited"):
            score += 0.1
        return min(1.0, score)
    
    def _score_to_status(self, score: float) -> str:
        if score >= 0.7:
            return "optimal"
        elif score >= 0.4:
            return "warning"
        else:
            return "critical"
    
    def _get_nuwa_suggestion(self, context: Dict, score: float) -> str:
        if score >= 0.7:
            return "✅ 女娲维度健康：创造/修复能力充足"
        elif score >= 0.4:
            return "⚠️ 女娲维度警告：建议关注创造/修复能力"
        else:
            return "❌ 女娲维度危急：需要立即修复或创造"
    
    def _get_cangjie_suggestion(self, context: Dict, score: float) -> str:
        if score >= 0.7:
            return "✅ 仓颉维度健康：观察/编码能力充足"
        elif score >= 0.4:
            return "⚠️ 仓颉维度警告：建议关注观察/编码能力"
        else:
            return "❌ 仓颉维度危急：需要立即观察或编码"
    
    def _get_darwin_suggestion(self, context: Dict, score: float) -> str:
        if score >= 0.7:
            return "✅ 达尔文维度健康：演化/选择能力充足"
        elif score >= 0.4:
            return "⚠️ 达尔文维度警告：建议关注演化/选择能力"
        else:
            return "❌ 达尔文维度危急：需要立即演化或选择"
    
    def _determine_primary_sage(self, assessments: List[dict]) -> str:
        scores = {
            "nuwa": sum(1 for a in assessments if "nuwa" in a["dimension"]),
            "cangjie": sum(1 for a in assessments if "cangjie" in a["dimension"]),
            "darwin": sum(1 for a in assessments if "darwin" in a["dimension"])
        }
        return max(scores, key=scores.get)
    
    def _decide_nuwa(self, context: Dict, options: List[str]) -> str:
        if context.get("system_state", {}).get("needs_repair"):
            return "选择修复方案：炼石补天，修复系统缺陷"
        elif context.get("task_type") in ["create", "design"]:
            return "选择创造方案：抟土造人，从 0 到 1 构建"
        else:
            return "选择秩序方案：断鳌立极，建立规则边界"
    
    def _decide_cangjie(self, context: Dict, options: List[str]) -> str:
        if context.get("task_type") in ["analyze", "encode"]:
            return "选择编码方案：观迹取象，提取模式编码"
        elif context.get("system_state", {}).get("needs_structure"):
            return "选择传承方案：四目重光，建立文档体系"
        else:
            return "选择观察方案：观鸟迹虫文，从自然提取规律"
    
    def _decide_darwin(self, context: Dict, options: List[str]) -> str:
        if context.get("task_type") in ["optimize", "evolve"]:
            return "选择演化方案：渐变积累，持续迭代优化"
        elif context.get("resources", {}).get("limited"):
            return "选择选择方案：物竞天择，保留最优"
        else:
            return "选择适应方案：环境适应，动态调整"
    
    def _determine_priority(self, context: Dict, assessment: Dict) -> str:
        if assessment["overall_score"] < 0.4:
            return DecisionPriority.CRITICAL
        elif assessment["overall_score"] < 0.6:
            return DecisionPriority.HIGH
        elif assessment["overall_score"] < 0.8:
            return DecisionPriority.MEDIUM
        else:
            return DecisionPriority.LOW
    
    def assess(self, context: Dict) -> Dict:
        """三位一体评估"""
        assessments = []
        
        nuwa_score = self._assess_nuwa(context)
        assessments.append({
            "dimension": "nuwa_create",
            "score": nuwa_score,
            "status": self._score_to_status(nuwa_score),
            "suggestion": self._get_nuwa_suggestion(context, nuwa_score),
            "yin_yang_balance": 0.5
        })
        
        cangjie_score = self._assess_cangjie(context)
        assessments.append({
            "dimension": "cangjie_observe",
            "score": cangjie_score,
            "status": self._score_to_status(cangjie_score),
            "suggestion": self._get_cangjie_suggestion(context, cangjie_score),
            "yin_yang_balance": 0.5
        })
        
        darwin_score = self._assess_darwin(context)
        assessments.append({
            "dimension": "darwin_evolve",
            "score": darwin_score,
            "status": self._score_to_status(darwin_score),
            "suggestion": self._get_darwin_suggestion(context, darwin_score),
            "yin_yang_balance": 0.5
        })
        
        result = {
            "timestamp": datetime.now().isoformat(),
            "context": context,
            "assessments": assessments,
            "primary_sage": self._determine_primary_sage(assessments),
            "overall_score": sum(a["score"] for a in assessments) / 3
        }
        
        self._log(self.assessment_log, "three_sages_assess", result)
        return result
    
    def decide(self, context: Dict, options: List[str]) -> ThreeSagesDecision:
        """三位一体决策"""
        assessment = self.assess(context)
        primary_sage = assessment["primary_sage"]
        
        if primary_sage == "nuwa":
            decision_text = self._decide_nuwa(context, options)
        elif primary_sage == "cangjie":
            decision_text = self._decide_cangjie(context, options)
        else:
            decision_text = self._decide_darwin(context, options)
        
        next_gua = self.SAGE_GUA_MAP.get(primary_sage, [1])[0]
        priority = self._determine_priority(context, assessment)
        decision_id = f"ts_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{self.state['decision_count']}"
        
        result = ThreeSagesDecision(
            decision_id=decision_id,
            timestamp=datetime.now().isoformat(),
            context=context,
            assessments=assessment["assessments"],
            primary_sage=primary_sage,
            decision=decision_text,
            rationale=f"基于{primary_sage}维度评估，{assessment['overall_score']:.2f} 综合得分",
            priority=priority,
            next_gua=next_gua
        )
        
        self._log(self.decision_log, "three_sages_decide", result.to_dict())
        
        self.state["decision_count"] += 1
        self.state["last_decision"] = datetime.now().isoformat()
        self.state["current_sage_focus"] = primary_sage
        self._save_state()
        
        return result
    
    def get_status(self) -> Dict:
        return {
            "timestamp": datetime.now().isoformat(),
            "state": self.state,
            "sage_motto": self.SAGE_MOTTO,
            "sage_gua_map": {k: v for k, v in self.SAGE_GUA_MAP.items()}
        }
    
    def get_sage_motto(self, sage: str = "integrated") -> str:
        return self.SAGE_MOTTO.get(sage, "未知智者")


def assess_three_sages(context: Dict) -> Dict:
    framework = ThreeSagesFramework()
    return framework.assess(context)


def decide_three_sages(context: Dict, options: List[str]) -> ThreeSagesDecision:
    framework = ThreeSagesFramework()
    return framework.decide(context, options)


def get_three_sages_status() -> Dict:
    framework = ThreeSagesFramework()
    return framework.get_status()


if __name__ == "__main__":
    print("=" * 70)
    print("🔄 三位一体决策框架 - 测试")
    print("=" * 70)
    
    framework = ThreeSagesFramework()
    
    test_context = {
        "system_state": {
            "needs_repair": False,
            "needs_structure": True,
            "needs_optimization": False
        },
        "task_type": "analyze",
        "urgency": "medium",
        "resources": {
            "abundant": False,
            "data_available": True,
            "limited": False
        }
    }
    
    print("\n📊 1. 三位一体评估")
    assessment = framework.assess(test_context)
    print(f"   主要智者: {assessment['primary_sage']}")
    print(f"   综合得分: {assessment['overall_score']:.2f}")
    for a in assessment["assessments"]:
        print(f"   {a['dimension']}: {a['score']:.2f} ({a['status']})")
    
    print("\n🧭 2. 三位一体决策")
    decision = framework.decide(test_context, ["方案 A", "方案 B", "方案 C"])
    print(f"   决策 ID: {decision.decision_id}")
    print(f"   主要智者: {decision.primary_sage}")
    print(f"   决策: {decision.decision}")
    print(f"   建议卦象: {decision.next_gua}")
    print(f"   优先级: {decision.priority}")
    
    print("\n📈 3. 框架状态")
    status = framework.get_status()
    print(f"   决策数: {status['state']['decision_count']}")
    print(f"   当前焦点: {status['state']['current_sage_focus']}")
    
    print("\n" + "=" * 70)
    print("✅ 三位一体决策框架测试完成")
    print("=" * 70)
