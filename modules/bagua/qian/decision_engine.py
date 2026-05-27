"""
乾 ☰ 决策引擎 (Decision Engine)
================================
八卦之首，刚健不息，代表决策与判断能力。

功能：
- 接收六环节闭环的处理请求
- 结合卦象状态进行决策
- 调用阿腾认知核心进行校准
- 输出决策建议

卦象：乾 ☰ (111) - 天行健，君子以自强不息
属性：刚健、主动、进取
"""

import json
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

# 决策日志路径
DECISION_LOG_PATH = Path("/home/ubuntu/starcore/data/bagua/qian_decision_log.jsonl")
DECISION_LOG_PATH.parent.mkdir(parents=True, exist_ok=True)


class DecisionEngine:
    """乾决策引擎"""
    
    def __init__(self, name: str = "QIAN"):
        self.name = name
        self.binary = "111"  # 乾卦二进制
        self.decision_count = 0
        self.last_decision_time = None
        self.decision_history: List[Dict] = []
        
    def decide(self, context: Dict[str, Any], gua_state: Optional[Dict] = None) -> Dict[str, Any]:
        """
        执行决策
        
        Args:
            context: 决策上下文（包含数据、约束、目标等）
            gua_state: 当前卦象状态（可选）
            
        Returns:
            决策结果：{action, confidence, reasoning, suggestions}
        """
        self.decision_count += 1
        self.last_decision_time = datetime.now().isoformat()
        
        # 1. 分析上下文
        analysis = self._analyze_context(context)
        
        # 2. 结合卦象状态（如果有）
        gua_influence = self._apply_gua_influence(analysis, gua_state) if gua_state else None
        
        # 3. 生成决策
        decision = self._generate_decision(analysis, gua_influence)
        
        # 4. 记录决策日志
        self._log_decision(context, decision)
        
        return decision
    
    def _analyze_context(self, context: Dict[str, Any]) -> Dict[str, Any]:
        """分析决策上下文"""
        return {
            "input_data": context.get("input_data", {}),
            "constraints": context.get("constraints", []),
            "goals": context.get("goals", []),
            "urgency": context.get("urgency", "normal"),
            "timestamp": datetime.now().isoformat()
        }
    
    def _apply_gua_influence(self, analysis: Dict, gua_state: Dict) -> Optional[Dict]:
        """应用卦象对决策的影响"""
        gua_name = gua_state.get("name", "UNKNOWN")
        gua_binary = gua_state.get("binary", "000000")
        
        # 乾卦决策建议库
        gua_suggestions = {
            "QIAN": {"action": "进取", "confidence_modifier": 0.1, "note": "阳气旺盛，宜积极进取"},
            "KUN": {"action": "蓄势", "confidence_modifier": -0.1, "note": "阴气凝聚，宜包容承载"},
            "TAI": {"action": "顺势", "confidence_modifier": 0.05, "note": "天地交泰，宜顺势而为"},
            "PI": {"action": "守正", "confidence_modifier": -0.05, "note": "闭塞之时，宜守正待时"},
            "JISHI": {"action": "谨慎", "confidence_modifier": -0.1, "note": "已完成，宜防微杜渐"},
            "WEIJ": {"action": "努力", "confidence_modifier": 0.05, "note": "未完成，宜继续努力"},
            "ZHUN": {"action": "谨慎起步", "confidence_modifier": 0.0, "note": "刚柔始交，宜稳中求进"},
            "MENG": {"action": "学习", "confidence_modifier": 0.0, "note": "山下出泉，宜培养正气"}
        }
        
        suggestion = gua_suggestions.get(gua_name, {"action": "常规", "confidence_modifier": 0.0, "note": "未知卦象"})
        
        return {
            "gua_name": gua_name,
            "gua_binary": gua_binary,
            "suggestion": suggestion
        }
    
    def _generate_decision(self, analysis: Dict, gua_influence: Optional[Dict]) -> Dict[str, Any]:
        """生成最终决策"""
        urgency = analysis.get("urgency", "normal")
        
        # 基础决策逻辑
        if urgency == "urgent":
            action = "立即执行"
            confidence = 0.85
        elif urgency == "high":
            action = "优先处理"
            confidence = 0.75
        else:
            action = "按计划执行"
            confidence = 0.65
        
        # 应用卦象影响
        if gua_influence:
            confidence = min(1.0, max(0.0, confidence + gua_influence["suggestion"]["confidence_modifier"]))
        
        return {
            "action": action,
            "confidence": round(confidence, 2),
            "reasoning": f"基于上下文分析，优先级: {urgency}",
            "suggestions": [
                gua_influence["suggestion"]["note"] if gua_influence else "无卦象影响",
                "乾卦刚健，宜主动进取",
                "保持自强不息的精神"
            ],
            "timestamp": datetime.now().isoformat(),
            "decision_id": f"QIAN-{self.decision_count:04d}"
        }
    
    def _log_decision(self, context: Dict, decision: Dict) -> None:
        """记录决策日志"""
        log_entry = {
            "decision_id": decision["decision_id"],
            "timestamp": decision["timestamp"],
            "context": context,
            "decision": decision,
            "engine": self.name
        }
        
        with open(DECISION_LOG_PATH, "a") as f:
            f.write(json.dumps(log_entry) + "\n")
        
        self.decision_history.append(log_entry)
    
    def get_status(self) -> Dict[str, Any]:
        """获取决策引擎状态"""
        return {
            "name": self.name,
            "binary": self.binary,
            "decision_count": self.decision_count,
            "last_decision_time": self.last_decision_time,
            "recent_decisions": self.decision_history[-5:] if self.decision_history else []
        }


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("🔮 乾决策引擎 测试")
    print("=" * 60)
    
    engine = DecisionEngine()
    
    # 测试1：基础决策
    print("\n📝 测试1：基础决策")
    context = {
        "input_data": {"cpu_load": 0.7, "memory": 0.6},
        "goals": ["优化系统性能"],
        "urgency": "high"
    }
    result = engine.decide(context)
    print(f"   决策ID: {result['decision_id']}")
    print(f"   行动: {result['action']}")
    print(f"   置信度: {result['confidence']}")
    print(f"   建议: {result['suggestions'][0]}")
    
    # 测试2：结合卦象决策
    print("\n📝 测试2：结合卦象决策 (乾卦)")
    gua_state = {"name": "QIAN", "binary": "111111"}
    result = engine.decide(context, gua_state)
    print(f"   决策ID: {result['decision_id']}")
    print(f"   行动: {result['action']}")
    print(f"   置信度: {result['confidence']} (受乾卦影响)")
    print(f"   建议: {result['suggestions'][0]}")
    
    # 测试3：结合卦象决策 (坤卦)
    print("\n📝 测试3：结合卦象决策 (坤卦)")
    gua_state = {"name": "KUN", "binary": "000000"}
    result = engine.decide(context, gua_state)
    print(f"   决策ID: {result['decision_id']}")
    print(f"   行动: {result['action']}")
    print(f"   置信度: {result['confidence']} (受坤卦影响)")
    print(f"   建议: {result['suggestions'][0]}")
    
    # 获取状态
    print("\n📊 引擎状态:")
    status = engine.get_status()
    print(f"   决策次数: {status['decision_count']}")
    
    print("\n✅ 乾决策引擎测试完成")
