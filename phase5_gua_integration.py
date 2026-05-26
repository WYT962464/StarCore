#!/usr/bin/env python3
"""
Phase 5: 六十四卦与融合引擎集成
==============================

将六十四卦引擎集成到融合引擎中，实现：
1. 卦态作为决策输入源
2. 六环节闭环作为执行框架
3. 卦变触发条件与系统状态绑定
4. 与两仪循环引擎协同工作

架构：
┌─────────────────────────────────────────────────────────────┐
│                    融合引擎 (FusionEngine)                     │
├─────────────────────────────────────────────────────────────┤
│  六十四卦集成层 (GuaIntegration)                               │
│  ├─ 卦态感知：实时卦象 + 系统状态映射                          │
│  ├─ 六环节执行：收集→存储→处理→输出→执行→反馈                  │
│  ├─ 卦变触发：系统状态变化 → 爻变 → 卦象更新                   │
│  └─ 决策增强：卦象解释 → 决策建议                              │
├─────────────────────────────────────────────────────────────┤
│  两仪循环引擎 (TwoYinYangEngine v5.3)                          │
│  ├─ 阳端探索 + 阴端评估                                        │
│  └─ 阿腾认知核心校准                                           │
├─────────────────────────────────────────────────────────────┤
│  统一记忆层 + 统一路由层 + 统一通知层                           │
└─────────────────────────────────────────────────────────────┘
"""

import json
import threading
import time
from datetime import datetime
from typing import Dict, List, Optional, Any, Tuple
from pathlib import Path
from dataclasses import dataclass, field
from enum import Enum

# 导入 Phase 4 六十四卦引擎
try:
    from phase4_gua_engine import (
        GuaState, GuaEngine, SelfCycleEngine, 
        SixCyclePhase, GUA_NAMES
    )
except ImportError:
    # 如果模块不存在，使用简化版本
    GuaState = None
    GuaEngine = None
    SelfCycleEngine = None
    SixCyclePhase = None
    GUA_NAMES = {}


class GuaTriggerSource(Enum):
    """卦变触发源"""
    MANUAL = "manual"           # 手动触发
    HARDWARE = "hardware"       # 硬件状态变化
    SYSTEM_CYCLE = "system_cycle"  # 系统自循环
    DECISION_RESULT = "decision_result"  # 决策结果
    ERROR = "error"             # 错误/异常
    TIME = "time"               # 定时触发


@dataclass
class GuaSystemState:
    """卦态系统状态"""
    current_gua: Dict
    previous_gua: Optional[Dict] = None
    yao_changes: List[Dict] = field(default_factory=list)
    trigger_source: GuaTriggerSource = GuaTriggerSource.SYSTEM_CYCLE
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    energy_level: float = 0.5
    entropy: float = 0.5
    cycle_count: int = 0
    
    def to_dict(self) -> Dict:
        return {
            "current_gua": self.current_gua,
            "previous_gua": self.previous_gua,
            "yao_changes": self.yao_changes,
            "trigger_source": self.trigger_source.value,
            "timestamp": self.timestamp,
            "energy_level": self.energy_level,
            "entropy": self.entropy,
            "cycle_count": self.cycle_count
        }


@dataclass
class SixCycleResult:
    """六环节执行结果"""
    cycle_id: int
    phases: Dict[str, Any]
    input_data: Dict
    output_data: Dict
    new_gua: Dict
    duration_ms: float
    timestamp: str
    
    def to_dict(self) -> Dict:
        return {
            "cycle_id": self.cycle_id,
            "phases": self.phases,
            "input_data": self.input_data,
            "output_data": self.output_data,
            "new_gua": self.new_gua,
            "duration_ms": self.duration_ms,
            "timestamp": self.timestamp
        }


class GuaIntegration:
    """
    六十四卦集成层
    
    负责将六十四卦引擎集成到融合引擎中，提供：
    1. 卦态感知与状态映射
    2. 六环节闭环执行
    3. 卦变触发机制
    4. 决策增强建议
    """
    
    def __init__(self, data_dir: Path = None):
        self.data_dir = data_dir or Path("/home/ubuntu/starcore/data/gua_integration")
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        # 六十四卦引擎
        self.gua_engine: Optional[GuaEngine] = None
        self.self_cycle: Optional[SelfCycleEngine] = None
        
        # 状态
        self.state = GuaSystemState(
            current_gua={"number": 1, "name": "QIAN", "binary": "000000"}
        )
        
        # 配置
        self.cycle_interval = 60  # 秒
        self.hardware_poll_interval = 30  # 秒
        self.enable_auto_cycle = True
        
        # 回调
        self._on_gua_change_callbacks: List[callable] = []
        self._on_cycle_complete_callbacks: List[callable] = []
        
        # 锁
        self._lock = threading.Lock()
        
        # 日志文件
        self.integration_log = self.data_dir / "integration_log.jsonl"
        self.decision_log = self.data_dir / "decision_log.jsonl"
        
        # 初始化引擎
        self._init_engine()
        
        print("✅ 六十四卦集成层 已初始化")
        print(f"   数据目录: {self.data_dir}")
        print(f"   当前卦象: {self.state.current_gua['name']}({self.state.current_gua['number']})")
    
    def _init_engine(self):
        """初始化六十四卦引擎"""
        if GuaEngine is not None:
            self.gua_engine = GuaEngine(data_dir=self.data_dir)
            self.self_cycle = SelfCycleEngine(
                gua_engine=self.gua_engine,
                interval=self.cycle_interval
            )
            
            # 同步状态
            engine_status = self.gua_engine.get_status()
            self.state.current_gua = engine_status["current_gua"]
            self.state.cycle_count = engine_status["cycle_count"]
    
    def _log(self, file: Path, event: str, data: dict = None):
        """记录日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def register_gua_change_callback(self, callback: callable):
        """注册卦变回调"""
        self._on_gua_change_callbacks.append(callback)
    
    def register_cycle_complete_callback(self, callback: callable):
        """注册六环节完成回调"""
        self._on_cycle_complete_callbacks.append(callback)
    
    def get_status(self) -> Dict:
        """获取集成层状态"""
        return {
            "timestamp": datetime.now().isoformat(),
            "gua_state": self.state.to_dict(),
            "engine_status": self.gua_engine.get_status() if self.gua_engine else None,
            "cycle_status": self.self_cycle.get_status() if self.self_cycle else None,
            "config": {
                "cycle_interval": self.cycle_interval,
                "hardware_poll_interval": self.hardware_poll_interval,
                "enable_auto_cycle": self.enable_auto_cycle
            }
        }
    
    def run_cycle(self, input_data: Dict = None, source: GuaTriggerSource = None) -> SixCycleResult:
        """
        运行六环节闭环
        
        input_data: 输入数据（硬件状态、用户指令等）
        source: 触发源
        """
        if not self.gua_engine:
            return SixCycleResult(
                cycle_id=0,
                phases={},
                input_data=input_data or {},
                output_data={"error": "引擎未初始化"},
                new_gua=self.state.current_gua,
                duration_ms=0,
                timestamp=datetime.now().isoformat()
            )
        
        start_time = time.time()
        previous_gua = self.state.current_gua.copy()
        
        # 运行六环节
        cycle_result = self.gua_engine.cycle(input_data or {})
        
        duration_ms = (time.time() - start_time) * 1000
        
        # 更新状态
        new_gua = cycle_result.get("new_gua", {})
        yao_changes = cycle_result.get("phases", {}).get("process", {}).get("yao_changes", [])
        
        self.state.previous_gua = previous_gua
        self.state.current_gua = new_gua
        self.state.yao_changes = yao_changes
        self.state.trigger_source = source or GuaTriggerSource.SYSTEM_CYCLE
        self.state.cycle_count = cycle_result.get("cycle_id", 0)
        self.state.timestamp = datetime.now().isoformat()
        
        # 记录日志
        self._log(self.integration_log, "cycle_complete", {
            "cycle_id": cycle_result.get("cycle_id"),
            "duration_ms": duration_ms,
            "previous_gua": previous_gua,
            "new_gua": new_gua,
            "yao_changes": yao_changes
        })
        
        # 触发回调
        if yao_changes:
            for callback in self._on_gua_change_callbacks:
                try:
                    callback(self.state)
                except Exception as e:
                    self._log(self.integration_log, "callback_error", {"error": str(e)})
        
        for callback in self._on_cycle_complete_callbacks:
            try:
                callback(cycle_result)
            except Exception as e:
                self._log(self.integration_log, "callback_error", {"error": str(e)})
        
        return SixCycleResult(
            cycle_id=cycle_result.get("cycle_id", 0),
            phases=cycle_result.get("phases", {}),
            input_data=input_data or {},
            output_data=cycle_result.get("phases", {}).get("output", {}),
            new_gua=new_gua,
            duration_ms=duration_ms,
            timestamp=datetime.now().isoformat()
        )
    
    def map_hardware_to_gua(self, hardware_data: Dict) -> GuaState:
        """
        将硬件数据映射为卦态
        
        映射规则：
        - CPU 高负载 → 阳爻多（活跃）
        - 内存高占用 → 阳爻多（计算中）
        - 电池低电量 → 阴爻多（节能模式）
        """
        if GuaState is None or self.gua_engine is None:
            return None
        
        cpu = hardware_data.get("cpu_load", 0.5)
        memory = hardware_data.get("memory_usage", 0.5)
        battery = hardware_data.get("battery_level", 0.5)
        network = hardware_data.get("network_active", False)
        storage = hardware_data.get("storage_usage", 0.5)
        temperature = hardware_data.get("temperature", 0.5)
        
        # 6 爻映射
        bits = [
            1 if cpu > 0.5 else 0,           # 上爻：CPU
            1 if memory > 0.5 else 0,        # 五爻：内存
            1 if battery > 0.5 else 0,       # 四爻：电池
            1 if network else 0,             # 三爻：网络
            1 if storage > 0.5 else 0,       # 二爻：存储
            1 if temperature > 0.5 else 0,   # 初爻：温度
        ]
        
        number = GuaState._bits_to_number(bits)
        return GuaState(gua_number=number, yao_bits=bits)
    
    def get_decision_suggestion(self, context: Dict = None) -> Dict:
        """
        基于当前卦象生成决策建议
        
        返回：{
            "gua_name": "...",
            "interpretation": "...",
            "suggestion": "...",
            "confidence": 0.0-1.0,
            "action_advice": [...]
        }
        """
        if not self.state.current_gua:
            return {"error": "无卦象数据"}
        
        gua_number = self.state.current_gua.get("number", 1)
        gua_name = self.state.current_gua.get("name", "UNKNOWN")
        
        # 卦象解释库（增强版）
        interpretations = {
            1: {
                "name": "QIAN (乾)",
                "interpretation": "天行健，君子以自强不息",
                "suggestion": "阳气旺盛，宜积极进取，主动出击",
                "action_advice": ["启动新任务", "推进决策", "主动沟通"],
                "confidence": 0.8
            },
            2: {
                "name": "KUN (坤)",
                "interpretation": "地势坤，君子以厚德载物",
                "suggestion": "阴气凝聚，宜包容承载，蓄势待发",
                "action_advice": ["收集信息", "等待时机", "整合资源"],
                "confidence": 0.8
            },
            11: {
                "name": "TAI (泰)",
                "interpretation": "天地交泰，万物通达",
                "suggestion": "阴阳和谐，宜顺势而为，把握机遇",
                "action_advice": ["推进项目", "加强协作", "扩大成果"],
                "confidence": 0.9
            },
            12: {
                "name": "PI (否)",
                "interpretation": "天地不交，闭塞不通",
                "suggestion": "闭塞之时，宜守正待时，不可妄动",
                "action_advice": ["暂停推进", "反思调整", "积蓄力量"],
                "confidence": 0.85
            },
            63: {
                "name": "JISHI (既济)",
                "interpretation": "已完成，阴阳各得其位",
                "suggestion": "已完成阶段，宜保持谨慎，防微杜渐",
                "action_advice": ["巩固成果", "总结经验", "准备下一阶段"],
                "confidence": 0.9
            },
            64: {
                "name": "WEIJ (未济)",
                "interpretation": "未完成，阴阳失位",
                "suggestion": "未完成状态，宜继续努力，终将获得成功",
                "action_advice": ["持续投入", "调整策略", "坚持到底"],
                "confidence": 0.85
            }
        }
        
        result = interpretations.get(gua_number, {
            "name": gua_name,
            "interpretation": f"{gua_name}卦：阴阳变化，需结合具体情况解读",
            "suggestion": "根据当前状态调整策略",
            "action_advice": ["分析现状", "制定计划", "逐步推进"],
            "confidence": 0.6
        })
        
        # 添加上下文增强
        if context:
            result["context"] = context
            
            # 根据上下文调整建议
            if context.get("urgent", False):
                result["suggestion"] += "（紧急情况下优先执行关键任务）"
                result["action_advice"].insert(0, "优先处理紧急事项")
            
            if context.get("low_energy", False):
                result["suggestion"] += "（能量较低，建议减少任务量）"
                result["action_advice"].append("适当休息")
        
        return result
    
    def start_auto_cycle(self, interval: int = None):
        """启动自动六环节循环"""
        if interval:
            self.cycle_interval = interval
        
        if self.self_cycle:
            result = self.self_cycle.start()
            self._log(self.integration_log, "auto_cycle_start", {
                "interval": self.cycle_interval,
                "result": result
            })
            return result
        
        return {"success": False, "error": "引擎未初始化"}
    
    def stop_auto_cycle(self):
        """停止自动循环"""
        if self.self_cycle:
            result = self.self_cycle.stop()
            self._log(self.integration_log, "auto_cycle_stop", {"result": result})
            return result
        
        return {"success": False, "error": "引擎未初始化"}
    
    def trigger_gua_change(self, source: GuaTriggerSource, data: Dict = None) -> Dict:
        """
        手动触发卦变
        
        source: 触发源
        data: 相关数据
        """
        result = self.run_cycle(
            input_data=data,
            source=source
        )
        
        self._log(self.decision_log, "gua_change_triggered", {
            "source": source.value,
            "data": data,
            "result": result.to_dict()
        })
        
        return result.to_dict()
    
    def get_historical_gua(self, limit: int = 10) -> List[Dict]:
        """获取历史卦象"""
        history_file = self.data_dir / "gua_history.jsonl"
        
        if not history_file.exists():
            return []
        
        entries = []
        with open(history_file) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                    entries.append(entry)
                except:
                    pass
        
        return entries[-limit:]
    
    def get_yao_change_trend(self, hours: int = 24) -> Dict:
        """
        获取爻变趋势分析
        
        分析过去 N 小时的爻变模式
        """
        history = self.get_historical_gua(limit=hours * 10)  # 假设每 6 分钟一轮
        
        if not history:
            return {"error": "无历史数据"}
        
        # 统计阳爻/阴爻比例变化
        yang_ratios = []
        gua_changes = []
        
        for entry in history:
            if "new_gua" in entry:
                new_gua = entry["new_gua"]
                binary = new_gua.get("binary", "")
                if binary:
                    yang_count = binary.count("1")
                    yang_ratio = yang_count / 6
                    yang_ratios.append(yang_ratio)
                    gua_changes.append({
                        "timestamp": entry.get("timestamp"),
                        "gua": new_gua.get("name"),
                        "yang_ratio": yang_ratio
                    })
        
        if not yang_ratios:
            return {"error": "无法解析历史数据"}
        
        # 计算趋势
        avg_yang = sum(yang_ratios) / len(yang_ratios)
        trend = "stable"
        if len(yang_ratios) >= 3:
            recent_avg = sum(yang_ratios[-3:]) / 3
            if recent_avg > avg_yang + 0.1:
                trend = "increasing"
            elif recent_avg < avg_yang - 0.1:
                trend = "decreasing"
        
        return {
            "period_hours": hours,
            "total_cycles": len(yang_ratios),
            "avg_yang_ratio": avg_yang,
            "trend": trend,
            "recent_changes": gua_changes[-10:]
        }


class FusionGuaBridge:
    """
    融合引擎 - 六十四卦桥接器
    
    将六十四卦集成层与融合引擎连接，提供统一接口
    """
    
    def __init__(self, fusion_engine=None, gua_integration: GuaIntegration = None):
        self.fusion_engine = fusion_engine
        self.gua = gua_integration or GuaIntegration()
        
        # 注册回调
        self.gua.register_cycle_complete_callback(self._on_cycle_complete)
        
        print("✅ 融合-六十四卦桥接器 已初始化")
    
    def _on_cycle_complete(self, cycle_result: Dict):
        """六环节完成回调"""
        # 将结果传递给融合引擎的通知层
        if self.fusion_engine and hasattr(self.fusion_engine, 'notifier'):
            self.fusion_engine.notifier.add_notification(
                event_type="gua_cycle_complete",
                priority="normal",
                title=f"卦象演化：{cycle_result.get('new_gua', {}).get('name', 'N/A')}",
                message=f"周期 {cycle_result.get('cycle_id')}: 爻变 {len(cycle_result.get('phases', {}).get('process', {}).get('yao_changes', []))} 处"
            )
    
    def get_status(self) -> Dict:
        """获取桥接器状态"""
        return {
            "timestamp": datetime.now().isoformat(),
            "gua_integration": self.gua.get_status(),
            "fusion_engine": self.fusion_engine.get_state() if self.fusion_engine else None
        }
    
    def chat_with_gua(self, message: str) -> Dict:
        """
        结合卦象的对话
        
        1. 获取当前卦象
        2. 生成决策建议
        3. 路由到融合引擎
        4. 返回增强响应
        """
        # 1. 获取卦象状态
        gua_status = self.gua.get_status()
        current_gua = gua_status["gua_state"]["current_gua"]
        
        # 2. 生成决策建议
        decision = self.gua.get_decision_suggestion({
            "context": message,
            "urgent": "紧急" in message or "马上" in message,
            "low_energy": False  # 可结合真实能量状态
        })
        
        # 3. 路由到融合引擎
        if self.fusion_engine:
            route_result = self.fusion_engine.router.route(message)
            response = self.fusion_engine._generate_response(route_result)
        else:
            route_result = {"route": {"target": "direct"}, "result": {}}
            response = "融合引擎未连接"
        
        # 4. 构建增强响应
        return {
            "timestamp": datetime.now().isoformat(),
            "current_gua": current_gua,
            "decision_suggestion": decision,
            "route": route_result["route"],
            "response": response,
            "enhanced_response": self._build_enhanced_response(current_gua, decision, response)
        }
    
    def _build_enhanced_response(self, current_gua: Dict, decision: Dict, response: str) -> str:
        """构建增强响应"""
        lines = [
            f"🔮 **当前卦象**: {current_gua.get('name', 'N/A')}({current_gua.get('number', 'N/A')})",
            f"   {decision.get('interpretation', '')}",
            "",
            f"💡 **建议**: {decision.get('suggestion', '')}",
            "",
            f"📋 **响应**: {response}"
        ]
        
        return "\n".join(lines)
    
    def run_cycle_and_decide(self, input_data: Dict = None) -> Dict:
        """
        运行六环节并生成决策
        
        这是核心入口：感知→六环节→卦变→决策建议
        """
        # 1. 运行六环节
        cycle_result = self.gua.run_cycle(input_data, GuaTriggerSource.DECISION_RESULT)
        
        # 2. 获取决策建议
        decision = self.gua.get_decision_suggestion()
        
        # 3. 记录到决策日志
        self.gua._log(self.gua.decision_log, "decision_cycle", {
            "cycle_result": cycle_result.to_dict(),
            "decision": decision
        })
        
        return {
            "timestamp": datetime.now().isoformat(),
            "cycle": cycle_result.to_dict(),
            "decision": decision
        }


# ==================== 便捷函数 ====================

def get_gua_status() -> Dict:
    """获取六十四卦集成状态"""
    integration = GuaIntegration()
    return integration.get_status()


def run_gua_cycle(input_data: Dict = None) -> Dict:
    """运行单轮六环节"""
    integration = GuaIntegration()
    result = integration.run_cycle(input_data)
    return result.to_dict()


def get_decision_suggestion(context: Dict = None) -> Dict:
    """获取决策建议"""
    integration = GuaIntegration()
    return integration.get_decision_suggestion(context)


def start_auto_gua_cycle(interval: int = 60) -> Dict:
    """启动自动卦象循环"""
    integration = GuaIntegration()
    return integration.start_auto_cycle(interval)


def stop_auto_gua_cycle() -> Dict:
    """停止自动卦象循环"""
    integration = GuaIntegration()
    return integration.stop_auto_cycle()


# ==================== 测试 ====================

if __name__ == "__main__":
    print("=" * 70)
    print("Phase 5: 六十四卦与融合引擎集成 - 测试")
    print("=" * 70)
    
    # 1. 初始化集成层
    print("\n🔧 1. 初始化六十四卦集成层")
    integration = GuaIntegration()
    
    # 2. 获取状态
    print("\n📊 2. 当前状态")
    status = integration.get_status()
    print(f"   卦象: {status['gua_state']['current_gua']['name']}({status['gua_state']['current_gua']['number']})")
    print(f"   周期数: {status['gua_state']['cycle_count']}")
    
    # 3. 运行单轮
    print("\n🔄 3. 运行六环节闭环")
    result = integration.run_cycle({
        "test": "integration_test",
        "cpu_load": 0.6,
        "memory_usage": 0.5,
        "battery_level": 0.8
    })
    print(f"   周期 ID: {result.cycle_id}")
    print(f"   新卦象: {result.new_gua.get('name', 'N/A')}({result.new_gua.get('number', 'N/A')})")
    print(f"   爻变: {len(result.phases.get('process', {}).get('yao_changes', []))} 处")
    print(f"   耗时: {result.duration_ms:.2f}ms")
    
    # 4. 获取决策建议
    print("\n💡 4. 决策建议")
    decision = integration.get_decision_suggestion({
        "context": "系统运行正常，需要推进任务",
        "urgent": False,
        "low_energy": False
    })
    print(f"   卦象: {decision.get('name', 'N/A')}")
    print(f"   解释: {decision.get('interpretation', '')[:60]}...")
    print(f"   建议: {decision.get('suggestion', '')[:60]}...")
    print(f"   行动: {decision.get('action_advice', [])}")
    
    # 5. 硬件映射测试
    print("\n🔌 5. 硬件数据映射")
    hardware = {
        "cpu_load": 0.8,
        "memory_usage": 0.7,
        "battery_level": 0.9,
        "network_active": True,
        "storage_usage": 0.6,
        "temperature": 0.5
    }
    mapped_gua = integration.map_hardware_to_gua(hardware)
    if mapped_gua:
        print(f"   硬件 → 卦象: {mapped_gua.name}({mapped_gua.number}) {mapped_gua.binary}")
    
    # 6. 爻变趋势
    print("\n📈 6. 爻变趋势")
    trend = integration.get_yao_change_trend(hours=1)
    print(f"   趋势: {trend.get('trend', 'N/A')}")
    print(f"   平均阳爻比: {trend.get('avg_yang_ratio', 0):.2f}")
    
    # 7. 桥接器测试
    print("\n🔗 7. 融合桥接器")
    bridge = FusionGuaBridge(gua_integration=integration)
    bridge_status = bridge.get_status()
    print(f"   桥接器状态: ✅")
    
    # 8. 决策循环
    print("\n🎯 8. 决策循环")
    decision_cycle = bridge.run_cycle_and_decide({
        "trigger": "manual_test",
        "priority": "high"
    })
    print(f"   周期 ID: {decision_cycle['cycle']['cycle_id']}")
    print(f"   决策置信度: {decision_cycle['decision'].get('confidence', 0):.2f}")
    
    print("\n" + "=" * 70)
    print("✅ Phase 5 测试完成")
    print("=" * 70)
