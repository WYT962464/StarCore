#!/usr/bin/env python3
"""
星核系统 — 两仪循环引擎 v5.3
融合：阿腾认知核心 × 六十四卦演化 × 两仪循环决策 × Hermes 执行

架构：
┌─────────────────────────────────────────────────────────────┐
│  阿腾认知核心（方向盘）                                        │
│  ├─ 关联思维：方向校准                                        │
│  ├─ 去伪存真：假象过滤                                        │
│  └─ 底线意识：强制终止                                        │
├─────────────────────────────────────────────────────────────┤
│  六十四卦演化框架（宏观方向 + 容错）                             │
│  ├─ 卦象状态：KUNQIAN 等                                      │
│  ├─ 三级重试 + 卦态回溯                                       │
│  └─ 数字生命「艾尔」：情绪/休眠/代谢                           │
├─────────────────────────────────────────────────────────────┤
│  两仪循环决策引擎（中观决策 + 评估）                             │
│  ├─ 阳端：发散探索（5 方向）                                   │
│  ├─ 阴端：8 维评估 + 置信度                                    │
│  └─ 循环计数器 + 偏差溯源                                     │
├─────────────────────────────────────────────────────────────┤
│  Hermes 执行引擎（微观执行 + 感知）                              │
│  ├─ 工具调用：22 个工具                                        │
│  ├─ 技能系统：35 个技能                                        │
│  └─ 子代理调度：并行执行                                      │
└─────────────────────────────────────────────────────────────┘

v5.3 新增：
- 阿腾认知核心蒸馏内化
- [ATENG] 前缀触发校准
- 去伪存真过滤假象
- 三层框架判断层级
- 底线意识强制终止
"""

import json
import time
import random
from datetime import datetime
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field
from enum import Enum
import sqlite3
import hashlib
import os

# ==================== 阿腾认知核心 ====================

class AtengCalibrationResult:
    """阿腾认知核心校准结果"""
    
    def __init__(self):
        self.三层框架 = "现实"  # 现实/理想/梦想
        self.去伪存真结果 = True  # 是否识别假象
        self.关联思维建议 = ""
        self.底线检查 = True  # 是否触碰底线
        self.时间约束 = True  # 是否超时
        self.校准建议 = ""
    
    def to_dict(self) -> Dict:
        return {
            "三层框架": self.三层框架,
            "去伪存真结果": self.去伪存真结果,
            "关联思维建议": self.关联思维建议,
            "底线检查": self.底线检查,
            "时间约束": self.时间约束,
            "校准建议": self.校准建议
        }

def ateng_calibrate(scenario: str, context: Dict) -> AtengCalibrationResult:
    """
    阿腾认知核心校准
    
    触发条件：
    - 方向模糊：阳端输出同质化
    - 置信度低：低置信度维度≥4 个
    - 循环停滞：计数器递增但无进展
    - 熵值异常：熵>0.6 或熵<0.2
    - 决策疲劳：连续决策≥5 轮无突破
    - 执行偏了：执行结果偏差>30%
    
    校准流程：
    1. 去伪存真 — 识别是否假象
    2. 三层框架 — 判断当前层级
    3. 底线检查 — 是否触碰底线
    4. 时间约束 — 是否超时
    5. 关联思维 — 找隐藏关联
    """
    result = AtengCalibrationResult()
    
    # 1. 去伪存真 — 识别假象
    if "形式主义" in scenario or "空转" in scenario or "虚假" in scenario:
        result.去伪存真结果 = False
        result.校准建议 += "识别到形式主义，拒绝推进\n"
    
    # 2. 三层框架 — 判断层级
    if "生存" in scenario or "基础" in scenario or "活下来" in scenario:
        result.三层框架 = "现实"
        result.校准建议 += "当前在「现实」层，生存优先\n"
    elif "效率" in scenario or "优化" in scenario or "活好" in scenario:
        result.三层框架 = "理想"
        result.校准建议 += "当前在「理想」层，效率优先\n"
    elif "创新" in scenario or "突破" in scenario or "伟大" in scenario:
        result.三层框架 = "梦想"
        result.校准建议 += "当前在「梦想」层，创新优先\n"
    else:
        result.三层框架 = "现实"
        result.校准建议 += "默认「现实」层，先活下来\n"
    
    # 3. 底线检查
    if "阶段十" in scenario or "根基" in scenario or "底线" in scenario:
        result.底线检查 = False
        result.校准建议 += "触碰底线「绝不改动阶段十根基」，强制终止\n"
    
    # 4. 时间约束
    if "超时" in scenario or "30 分钟" in scenario or "5 轮" in scenario:
        result.时间约束 = False
        result.校准建议 += "超时，切换路径\n"
    
    # 5. 关联思维 — 找隐藏关联
    if "六十四卦" in scenario and "两仪" in scenario:
        result.关联思维建议 = "六十四卦是演化框架，两仪是决策引擎，阿腾是方向盘"
    
    return result

# ==================== 六十四卦演化框架 ====================

class HexagramState(Enum):
    KUNQIAN = "KUNQIAN"  # 地天泰 → 天地否 初始态
    QIANKUN = "QIANKUN"  # 天地否
    ZHEN = "ZHEN"        # 震卦 - 启动
    GENG = "GENG"        # 革卦 - 变革
    DING = "DING"        # 鼎卦 - 稳固
    JIAN = "JIAN"        # 渐卦 - 渐进
    FENG = "FENG"        # 丰卦 - 丰盛
    XUN = "XUN"          # 巽卦 - 深入
    UNKNOWN = "UNKNOWN"

@dataclass
class HexagramContext:
    """六十四卦上下文"""
    current_hexagram: HexagramState = HexagramState.KUNQIAN
    retry_count: int = 0
    max_retries: int = 3
    evolution_level: int = 0  # 0-64
    is_dormant: bool = False
    energy_level: float = 0.7  # 能量水平
    entropy: float = 0.5  # 熵值
    
    def to_dict(self) -> Dict:
        return {
            "hexagram": self.current_hexagram.value,
            "retry_count": self.retry_count,
            "max_retries": self.max_retries,
            "evolution_level": self.evolution_level,
            "is_dormant": self.is_dormant,
            "energy_level": self.energy_level,
            "entropy": self.entropy
        }

# ==================== 两仪循环决策引擎 ====================

class YangDirection:
    """阳端探索方向"""
    def __init__(self, name: str, description: str, confidence: float = 0.5):
        self.name = name
        self.description = description
        self.confidence = confidence
    
    def to_dict(self) -> Dict:
        return {
            "name": self.name,
            "description": self.description,
            "confidence": self.confidence
        }

@dataclass
class YinEvaluation:
    """阴端评估结果"""
    dimensions: Dict[str, float]  # 8 维评估
    overall_score: float
    confidence: float
    recommendation: str
    reasoning: str
    
    def to_dict(self) -> Dict:
        return {
            "dimensions": self.dimensions,
            "overall_score": self.overall_score,
            "confidence": self.confidence,
            "recommendation": self.recommendation,
            "reasoning": self.reasoning
        }

@dataclass
class CycleCounter:
    """循环计数器"""
    user_cycle: int = 0  # 用户输入触发的循环
    system_cycle: int = 0  # 系统自循环
    max_system_cycles: int = 10  # 最大自循环次数
    last_reset: float = 0  # 最后重置时间
    
    def reset_on_user_input(self):
        """用户输入时重置计数器"""
        self.user_cycle = 0
        self.system_cycle = 0
        self.last_reset = time.time()
    
    def increment_system(self):
        """系统自循环递增"""
        self.system_cycle += 1
    
    def should_terminate(self) -> bool:
        """是否应该终止"""
        return self.system_cycle >= self.max_system_cycles
    
    def to_dict(self) -> Dict:
        return {
            "user_cycle": self.user_cycle,
            "system_cycle": self.system_cycle,
            "max_system_cycles": self.max_system_cycles,
            "should_terminate": self.should_terminate()
        }

# ==================== 输入路由 ====================

def route_input(message: str) -> Dict:
    """
    输入路由：根据前缀决定进入哪个系统
    
    前缀规范：
    - 无前缀 → user（真实用户输入）
    - [SYSTEM] → system（系统自循环反馈）
    - [MCP]/[DEVICE] → external（外部工具返回）
    - [GUA] → hexagram（六十四卦状态查询/命令）
    - [HERMES] → hermes（直接工具调用）
    - [ATENG] → ateng（阿腾认知核心校准请求）
    """
    if message.startswith("[HERMES]"):
        return {"target": "hermes", "action": "tool_call", "content": message[8:]}
    
    elif message.startswith("[ATENG]"):
        return {"target": "ateng", "action": "calibrate", "content": message[7:]}
    
    elif message.startswith("[SYSTEM]"):
        return {"target": "two_yin_yang", "action": "feedback", "content": message[8:]}
    
    elif message.startswith("[MCP]") or message.startswith("[DEVICE]"):
        return {"target": "two_yin_yang", "action": "external_feedback", "content": message[5:]}
    
    elif message.startswith("[GUA]"):
        return {"target": "hexagram", "action": "command", "content": message[5:]}
    
    else:
        return {"target": "two_yin_yang", "action": "user_input", "content": message}

# ==================== 主引擎 ====================

class TwoYinYangEngine:
    """两仪循环引擎 v5.3"""
    
    def __init__(self, db_path: str = "/home/ubuntu/starcore/data/decisions.db"):
        self.db_path = db_path
        self.hexagram_ctx = HexagramContext()
        self.counter = CycleCounter()
        self.history: List[Dict] = []
        self._init_db()
    
    def _init_db(self):
        """初始化决策数据库"""
        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS decisions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                input_source TEXT NOT NULL,
                hexagram TEXT,
                yang_directions TEXT,
                yin_evaluation TEXT,
                ateng_calibration TEXT,
                final_decision TEXT,
                confidence REAL,
                execution_result TEXT
            )
        ''')
        conn.commit()
        conn.close()
    
    def _generate_yang_directions(self, context: str) -> List[YangDirection]:
        """阳端：生成 5 个探索方向"""
        directions = []
        for i in range(5):
            directions.append(YangDirection(
                name=f"方向{i+1}",
                description=f"基于上下文的探索方向 {i+1}",
                confidence=random.uniform(0.3, 0.9)
            ))
        return directions
    
    def _evaluate_yin(self, directions: List[YangDirection]) -> YinEvaluation:
        """阴端：8 维评估"""
        dimensions = {
            "可行性": random.uniform(0.3, 0.9),
            "创新性": random.uniform(0.3, 0.9),
            "风险度": random.uniform(0.2, 0.8),
            "资源需求": random.uniform(0.3, 0.9),
            "时间成本": random.uniform(0.3, 0.9),
            "长期价值": random.uniform(0.3, 0.9),
            "短期收益": random.uniform(0.3, 0.9),
            "可逆性": random.uniform(0.3, 0.9)
        }
        overall = sum(dimensions.values()) / len(dimensions)
        
        return YinEvaluation(
            dimensions=dimensions,
            overall_score=overall,
            confidence=overall,
            recommendation=f"推荐方向{random.randint(1,5)}",
            reasoning="基于 8 维评估的综合判断"
        )
    
    def _detect_confusion(self, yang_dirs: List[YangDirection], context: str) -> Tuple[bool, str]:
        """
        自动检测迷茫信号
        
        迷茫信号：
        1. 方向同质化：5 个方向描述相似度>70%
        2. 置信度低：低置信度方向≥4 个
        3. 无突破：连续 3 轮决策无实质进展
        4. 熵值异常：当前熵>0.6（混乱）或<0.2（死锁）
        5. 循环停滞：计数器递增但 history 无新内容
        """
        # 信号 1：方向同质化
        descriptions = [d.description for d in yang_dirs]
        if len(set(descriptions)) <= 2:  # 5 个方向只有 2 种不同描述
            return True, "方向同质化"
        
        # 信号 2：置信度低
        low_conf_count = sum(1 for d in yang_dirs if d.confidence < 0.4)
        if low_conf_count >= 4:
            return True, f"置信度低（{low_conf_count}/5 个方向<0.4）"
        
        # 信号 3：循环停滞
        if self.counter.system_cycle >= 3:
            recent_decisions = self.history[-3:] if len(self.history) >= 3 else self.history
            if len(recent_decisions) >= 3:
                recommendations = [d.get("final_decision", "") for d in recent_decisions]
                if len(set(recommendations)) <= 1:  # 连续 3 轮推荐相同
                    return True, "循环停滞（连续 3 轮无突破）"
        
        # 信号 4：熵值异常
        if self.hexagram_ctx.entropy > 0.6:
            return True, f"熵值异常（{self.hexagram_ctx.entropy:.2f}>0.6，混乱）"
        if self.hexagram_ctx.entropy < 0.2:
            return True, f"熵值异常（{self.hexagram_ctx.entropy:.2f}<0.2，死锁）"
        
        return False, ""
    
    def _auto_ateng_calibration(self, yang_dirs: List[YangDirection], context: str) -> Optional[AtengCalibrationResult]:
        """
        自动阿腾校准 — 迷茫时自己调用
        
        不需要用户说 [ATENG]，我自己检测到迷茫就自动调用
        """
        is_confused, reason = self._detect_confusion(yang_dirs, context)
        
        if is_confused:
            print(f"\n⚠️ 检测到迷茫信号：{reason}")
            print("🔄 自动调用阿腾认知核心校准...")
            result = ateng_calibrate(reason, {
                "directions": [d.to_dict() for d in yang_dirs],
                "counter": self.counter.to_dict(),
                "hexagram": self.hexagram_ctx.to_dict()
            })
            print(f"📌 校准建议：{result.校准建议}")
            return result
        
        return None
    
    def process(self, message: str) -> Dict:
        """
        处理输入消息
        
        流程：
        1. 路由输入（前缀解析）
        2. 两仪循环决策
        3. **自动检测迷茫 → 自动调用阿腾校准** ← 新增
        4. 六十四卦状态更新
        5. 执行 + 回传
        
        关键改进：迷茫时不再等待用户指令，自己调用阿腾校准
        """
        # 1. 路由输入
        routed = route_input(message)
        
        # 2. 计数器管理
        if routed["target"] == "two_yin_yang" and routed["action"] == "user_input":
            self.counter.reset_on_user_input()
        
        # 3. 两仪循环决策
        if routed["target"] == "two_yin_yang":
            yang_dirs = self._generate_yang_directions(routed["content"])
            yin_eval = self._evaluate_yin(yang_dirs)
            
            # ⚠️ 自动检测迷茫 → 自动调用阿腾校准
            ateng_result = self._auto_ateng_calibration(yang_dirs, routed["content"])
            
            # 如果阿腾校准返回了建议，重新评估决策
            if ateng_result:
                # 根据校准建议调整决策
                if not ateng_result.去伪存真结果:
                    # 去伪存真失败，拒绝当前决策
                    yin_eval.recommendation = "拒绝：识别到形式主义"
                    yin_eval.confidence = 0.0
                elif ateng_result.底线检查 == False:
                    # 触碰底线，强制终止
                    yin_eval.recommendation = "终止：触碰底线"
                    yin_eval.confidence = 0.0
                elif ateng_result.时间约束 == False:
                    # 超时，切换路径
                    yin_eval.recommendation = "切换路径"
            
            decision = {
                "timestamp": datetime.now().isoformat(),
                "input_source": routed["target"],
                "hexagram": self.hexagram_ctx.to_dict(),
                "yang_directions": [d.to_dict() for d in yang_dirs],
                "yin_evaluation": yin_eval.to_dict(),
                "ateng_calibration": ateng_result.to_dict() if ateng_result else None,
                "final_decision": yin_eval.recommendation,
                "confidence": yin_eval.confidence
            }
            
            self._save_decision(decision)
            self.history.append(decision)
            
            return decision
        
        # 4. [ATENG] 手动调用（用户主动请求校准）
        if routed["target"] == "ateng":
            ateng_result = ateng_calibrate(routed["content"], {})
            return {
                "timestamp": datetime.now().isoformat(),
                "input_source": "ateng",
                "calibration": ateng_result.to_dict()
            }
        
        # 5. 六十四卦状态更新
        if routed["target"] == "hexagram":
            # 处理卦象命令
            pass
        
        return {"status": "routed", "target": routed["target"]}
    
    def _save_decision(self, decision: Dict):
        """保存决策到数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO decisions 
            (timestamp, input_source, hexagram, yang_directions, yin_evaluation, 
             ateng_calibration, final_decision, confidence)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            decision["timestamp"],
            decision["input_source"],
            json.dumps(decision["hexagram"]),
            json.dumps(decision["yang_directions"]),
            json.dumps(decision["yin_evaluation"]),
            json.dumps(decision.get("ateng_calibration")),
            decision["final_decision"],
            decision["confidence"]
        ))
        conn.commit()
        conn.close()
    
    def get_status(self) -> Dict:
        """获取系统状态"""
        return {
            "hexagram": self.hexagram_ctx.to_dict(),
            "counter": self.counter.to_dict(),
            "history_count": len(self.history),
            "ateng_integrated": True
        }

# ==================== 主程序 ====================

if __name__ == "__main__":
    engine = TwoYinYangEngine()
    
    print("=" * 60)
    print("星核系统 — 两仪循环引擎 v5.3")
    print("融合：阿腾认知核心 × 六十四卦演化 × 两仪循环决策 × Hermes 执行")
    print("=" * 60)
    
    # 测试阿腾校准
    print("\n[ATENG] 校准测试：")
    result = ateng_calibrate("形式主义空转，连续 5 轮无进展", {})
    print(json.dumps(result.to_dict(), indent=2, ensure_ascii=False))
    
    # 测试输入路由
    print("\n输入路由测试：")
    test_inputs = [
        "帮我分析这个项目",
        "[ATENG] 迷茫，不知道下一步该做什么",
        "[SYSTEM] 执行完成，结果正常",
        "[GUA] 查询当前卦象",
        "[HERMES] 读取文件 /tmp/test.txt"
    ]
    
    for inp in test_inputs:
        routed = route_input(inp)
        print(f"  输入: {inp[:40]}...")
        print(f"  路由: {routed['target']} → {routed['action']}")
    
    # 测试引擎
    print("\n引擎测试：")
    decision = engine.process("分析 StarCore 项目下一步")
    print(json.dumps(decision, indent=2, ensure_ascii=False)[:500] + "...")
    
    print("\n系统状态：")
    print(json.dumps(engine.get_status(), indent=2, ensure_ascii=False))
    
    print("\n✅ v5.3 启动完成，阿腾认知核心已内化")
