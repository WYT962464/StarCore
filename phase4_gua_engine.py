#!/usr/bin/env python3
"""
Phase 4: 六十四卦自循环演化系统
基于六十四卦自循环演化系统 V1.4 文档

核心架构：
- 阴阳爻二进制映射（阴=0, 阳=1）
- 六十四卦状态集合
- 六环节闭环（收集→存储→处理→输出→执行→获取）
- 自循环演化引擎
- **三位一体决策框架（女娲·仓颉·达尔文）**
"""

import json
import hashlib
import os
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from enum import Enum
import threading
import random

# 三位一体决策框架
try:
    from three_sages_framework import ThreeSagesFramework, ThreeSagesDecision
    THREE_SAGES_AVAILABLE = True
except ImportError:
    THREE_SAGES_AVAILABLE = False
    print("⚠️ 三位一体决策框架未找到，功能受限")

import hashlib
import os
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from enum import Enum
import threading
import random

# 数据目录
DATA_DIR = Path("/home/ubuntu/starcore/data")
GUA_DIR = DATA_DIR / "gua"

# 确保目录存在
GUA_DIR.mkdir(parents=True, exist_ok=True)

# 阴阳爻枚举
class YinYang(Enum):
    YIN = 0   # 阴爻 ⚋ = 0（静默、存储、休眠、低算力）
    YANG = 1  # 阳爻 ⚊ = 1（活跃、运算、输出、高算力）


# 六十四卦定义（简化版，核心卦象）
GUA_NAMES = {
    # 上经（1-30）
    1: "QIAN",      # 乾 ☰☰☰ (111111) - 天行健
    2: "KUN",       # 坤 ☷☷☷ (000000) - 地势坤
    3: "ZHUN",      # 屯 ☵☳ (010010) - 万物始生
    4: "MENG",      # 蒙 ☶☵ (100010) - 启蒙
    5: "XU",        # 需 ☰☵ (111010) - 等待
    6: "SONG",      # 讼 ☰☶ (111100) - 争议
    7: "SHI",       # 师 ☷☵ (000010) - 众
    8: "BI",        # 比 ☷☰ (000111) - 亲密
    9: "XIAOCHU",   # 小畜 ☰☴ (111011) - 小蓄
    10: "TAN",      # 履 ☱☰ (011111) - 践行
    11: "TAI",      # 泰 ☷☰ (000111) - 通达
    12: "PI",       # 否 ☰☷ (111000) - 闭塞
    13: "TONGREN",  # 同人 ☰☲ (111101) - 同人
    14: "DAYOU",    # 大有 ☲☰ (101111) - 大有
    15: "QIAN",     # 谦 ☷☶ (000100) - 谦虚
    16: "YU",       # 豫 ☷☳ (000010) - 愉悦
    17: "SUI",      # 随 ☱☳ (011010) - 追随
    18: "GU",       # 蛊 ☷☴ (000110) - 整治
    19: "LIN",      # 临 ☷☱ (000011) - 临近
    20: "GUAN",     # 观 ☷☴ (000110) - 观察
    21: "SHIKOU",   # 噬嗑 ☲☳ (101010) - 咬合
    22: "BI",       # 贲 ☶☲ (100101) - 文饰
    23: "BO",       # 剥 ☷☶ (000100) - 剥落
    24: "FU",       # 复 ☷☳ (000010) - 回复
    25: "WUwang",   # 无妄 ☰☳ (111010) - 无妄
    26: "DAYU",     # 大畜 ☶☰ (100111) - 大蓄
    27: "YI",       # 颐 ☶☳ (100010) - 颐养
    28: "DAYUO",    # 大过 ☱☴ (011110) - 大过
    29: "KAN",      # 坎 ☵☵ (010010) - 险
    30: "LI",       # 离 ☲☲ (101101) - 明
    
    # 下经（31-64）
    31: "XIAN",     # 咸 ☷☱ (000011) - 感应
    32: "HENG",     # 恒 ☷☳ (000010) - 恒久
    33: "DUN",      # 遁 ☰☶ (111100) - 退避
    34: "DAYU",     # 大壮 ☰☳ (111010) - 大壮
    35: "JIN",      # 晋 ☷☲ (000101) - 晋升
    36: "MINGYI",   # 明夷 ☷☲ (000101) - 明伤
    37: "JIAREN",   # 家人 ☲☴ (101110) - 家人
    38: "KUAI",     # 睽 ☱☲ (011101) - 乖离
    39: "JIAN",     # 蹇 ☷☶ (000100) - 艰难
    40: "XIE",      # 解 ☷☳ (000010) - 缓解
    41: "SUN",      # 损 ☶☱ (100011) - 减损
    42: "YI",       # 益 ☷☴ (000110) - 增益
    43: "GUAI",     # 夬 ☱☰ (011111) - 决断
    44: "GOU",      # 姤 ☰☴ (111110) - 相遇
    45: "CU",       # 萃 ☷☱ (000011) - 聚集
    46: "SHENG",    # 升 ☷☴ (000110) - 上升
    47: "KUN",      # 困 ☱☶ (011100) - 困顿
    48: "JING",     # 井 ☷☴ (000110) - 井养
    49: "GE",       # 革 ☱☲ (011101) - 变革
    50: "DING",     # 鼎 ☱☴ (011110) - 鼎新
    51: "ZHEN",     # 震 ☳☳ (010010) - 震动
    52: "GEN",      # 艮 ☶☶ (100100) - 静止
    53: "JIAN",     # 渐 ☶☴ (100110) - 渐进
    54: "GUIMEI",   # 归妹 ☱☳ (011010) - 归妹
    55: "FENG",     # 丰 ☲☳ (101010) - 丰盛
    56: "LV",       # 旅 ☶☲ (100101) - 旅行
    57: "XUN",      # 巽 ☷☴ (000110) - 顺从
    58: "DU",       # 兑 ☱☱ (011011) - 喜悦
    59: "HUAN",     # 涣 ☷☴ (000110) - 涣散
    60: "JIE",      # 节 ☱☵ (011010) - 节制
    61: "ZHONGFU",  # 中孚 ☱☴ (011110) - 诚信
    62: "XIAOGU",   # 小过 ☷☶ (000100) - 小过
    63: "JISHI",    # 既济 ☲☵ (101010) - 已完成
    64: "WEIJ",     # 未济 ☵☲ (010101) - 未完成
}


class GuaState:
    """卦态 - 六十四卦状态表示"""
    
    def __init__(self, gua_number: int = 1, yao_bits: List[int] = None):
        """
        初始化卦态
        gua_number: 卦序号 (1-64)
        yao_bits: 6 位二进制列表 [上爻, 五爻, 四爻, 三爻, 二爻, 初爻]
        """
        self.number = gua_number
        self.name = GUA_NAMES.get(gua_number, f"UNKNOWN_{gua_number}")
        
        if yao_bits:
            self.yao_bits = yao_bits[:6]
        else:
            # 根据卦序号计算二进制
            self.yao_bits = self._number_to_bits(gua_number)
        
        self.timestamp = datetime.now().isoformat()
    
    @staticmethod
    def _number_to_bits(number: int) -> List[int]:
        """将卦序号转换为 6 位二进制"""
        # 使用简单的映射：number-1 的二进制
        value = number - 1
        bits = []
        for i in range(5, -1, -1):
            bits.append((value >> i) & 1)
        return bits
    
    @property
    def binary(self) -> str:
        """二进制表示"""
        return ''.join(str(b) for b in self.yao_bits)
    
    @property
    def yin_count(self) -> int:
        """阴爻数量"""
        return self.yao_bits.count(0)
    
    @property
    def yang_count(self) -> int:
        """阳爻数量"""
        return self.yao_bits.count(1)
    
    @property
    def yin_yang_ratio(self) -> float:
        """阴阳比例"""
        total = self.yin_count + self.yang_count
        return self.yang_count / total if total > 0 else 0.5
    
    def change_yao(self, position: int, new_value: int) -> 'GuaState':
        """
        爻变 - 改变指定位置的爻
        position: 1-6 (1=初爻, 6=上爻)
        """
        if position < 1 or position > 6:
            raise ValueError("位置必须在 1-6 之间")
        
        # 位置映射：position 1 = 索引 5 (初爻在最下)
        index = 6 - position
        new_bits = self.yao_bits.copy()
        new_bits[index] = new_value
        
        # 计算新卦序号
        new_number = self._bits_to_number(new_bits)
        return GuaState(gua_number=new_number, yao_bits=new_bits)
    
    @staticmethod
    def _bits_to_number(bits: List[int]) -> int:
        """二进制转卦序号"""
        value = 0
        for i, b in enumerate(bits):
            value = (value << 1) | b
        return value + 1
    
    def to_dict(self) -> dict:
        """转换为字典"""
        return {
            "number": self.number,
            "name": self.name,
            "binary": self.binary,
            "yin_count": self.yin_count,
            "yang_count": self.yang_count,
            "yin_yang_ratio": self.yin_yang_ratio,
            "timestamp": self.timestamp
        }
    
    def __str__(self) -> str:
        return f"{self.name}({self.number}) {self.binary}"


class SixCyclePhase(Enum):
    """六环节"""
    COLLECT = "collect"      # 收集（取象）
    STORE = "store"          # 存储（藏卦）
    PROCESS = "process"      # 处理（演卦）
    OUTPUT = "output"        # 输出（释卦）
    EXECUTE = "execute"      # 执行（行卦）
    FEEDBACK = "feedback"    # 获取（反馈）


class GuaEngine:
    """六十四卦核心推演引擎"""
    
    def __init__(self, data_dir: Path = GUA_DIR):
        self.data_dir = data_dir
        self.gua_file = data_dir / "current_gua.json"
        self.history_file = data_dir / "gua_history.jsonl"
        self.cycle_log = data_dir / "six_cycle_log.jsonl"
        self.state = self._load_state()
        self._lock = threading.Lock()
        self._current_phase = SixCyclePhase.COLLECT
    
    def _load_state(self) -> dict:
        """加载状态"""
        if self.gua_file.exists():
            with open(self.gua_file) as f:
                return json.load(f)
        return self._create_initial_state()
    
    def _create_initial_state(self) -> dict:
        """创建初始状态"""
        return {
            "version": "v1.0",
            "created": datetime.now().isoformat(),
            "current_gua": GuaState(1).to_dict(),
            "evolution_level": 1,  # 0→1→2→4→8→64
            "cycle_count": 0,
            "last_cycle": None
        }
    
    def _save_state(self):
        """保存状态"""
        with open(self.gua_file, "w") as f:
            json.dump(self.state, f, indent=2)
    
    def _log(self, file: Path, event: str, data: dict = None):
        """记录日志"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "event": event,
            "data": data or {}
        }
        with open(file, "a") as f:
            f.write(json.dumps(entry) + "\n")
    
    def get_current_gua(self) -> GuaState:
        """获取当前卦态"""
        return GuaState(
            gua_number=self.state["current_gua"]["number"],
            yao_bits=[int(b) for b in self.state["current_gua"]["binary"]]
        )
    
    def cycle(self, input_data: dict = None) -> Dict:
        """
        执行六环节闭环
        input_data: 外部输入数据
        """
        with self._lock:
            cycle_result = {
                "cycle_id": self.state["cycle_count"] + 1,
                "start_time": datetime.now().isoformat(),
                "phases": {},
                "input": input_data or {},
                "output": None
            }
            
            # 1. 收集（取象）
            self._current_phase = SixCyclePhase.COLLECT
            collected = self._collect(input_data)
            cycle_result["phases"]["collect"] = collected
            
            # 2. 存储（藏卦）
            self._current_phase = SixCyclePhase.STORE
            stored = self._store(collected)
            cycle_result["phases"]["store"] = stored
            
            # 3. 处理（演卦）- 核心推演（三位一体）
            self._current_phase = SixCyclePhase.PROCESS
            processed = self._process_with_three_sages(collected)
            cycle_result["phases"]["process"] = processed

            
            # 4. 输出（释卦）
            self._current_phase = SixCyclePhase.OUTPUT
            output = self._output(processed)
            cycle_result["phases"]["output"] = output
            
            # 5. 执行（行卦）
            self._current_phase = SixCyclePhase.EXECUTE
            executed = self._execute(output)
            cycle_result["phases"]["execute"] = executed
            
            # 6. 获取（反馈）
            self._current_phase = SixCyclePhase.FEEDBACK
            feedback = self._feedback(executed)
            cycle_result["phases"]["feedback"] = feedback
            
            # 更新卦态
            new_gua = self._evolve(feedback)
            self.state["current_gua"] = new_gua.to_dict()
            self.state["cycle_count"] += 1
            self.state["last_cycle"] = datetime.now().isoformat()
            
            cycle_result["end_time"] = datetime.now().isoformat()
            cycle_result["new_gua"] = new_gua.to_dict()
            
            # 保存日志
            self._log(self.history_file, "cycle_complete", cycle_result)
            self._save_state()
            
            return cycle_result
    
    def _collect(self, input_data: dict) -> dict:
        """收集环节 - 数据采集"""
        # 模拟硬件数据采集
        hardware_data = {
            "cpu_load": random.uniform(0.1, 0.9),
            "memory_usage": random.uniform(0.2, 0.8),
            "battery_level": random.uniform(0.3, 1.0),
            "timestamp": datetime.now().isoformat()
        }
        
        # 生成初卦
        initial_gua = self._data_to_gua(hardware_data, input_data)
        
        result = {
            "hardware_data": hardware_data,
            "input_data": input_data,
            "initial_gua": initial_gua.to_dict(),
            "status": "collected"
        }
        
        self._log(self.cycle_log, "collect", result)
        return result
    
    def _store(self, collected: dict) -> dict:
        """存储环节 - 数据入库"""
        # 模拟存储操作
        storage_result = {
            "stored": True,
            "location": str(self.data_dir),
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "store", storage_result)
        return storage_result
    
    def _process(self, collected: dict) -> dict:
        """处理环节 - 核心推演"""
        # 基于当前卦态和输入数据进行推演
        current_gua = self.get_current_gua()
        initial_gua = GuaState(
            gua_number=collected["initial_gua"]["number"],
            yao_bits=[int(b) for b in collected["initial_gua"]["binary"]]
        )
        
        # 爻变推演
        new_gua = self._divination(current_gua, initial_gua, collected["hardware_data"])
        
        result = {
            "current_gua": current_gua.to_dict(),
            "initial_gua": collected["initial_gua"],
            "new_gua": new_gua.to_dict(),
            "yao_changes": self._calculate_yao_changes(current_gua, new_gua),
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "process", result)
        return result
    

    def _process_with_three_sages(self, collected: dict) -> dict:
        """处理环节 - 三位一体核心推演"""
        current_gua = self.get_current_gua()
        initial_gua = GuaState(
            gua_number=collected["initial_gua"]["number"],
            yao_bits=[int(b) for b in collected["initial_gua"]["binary"]]
        )
        
        # 三位一体评估
        context = {
            "system_state": {
                "current_gua": current_gua.name,
                "cpu_load": collected["hardware_data"].get("cpu_load", 0.5),
                "memory_usage": collected["hardware_data"].get("memory_usage", 0.5),
            },
            "task_type": "evolution",
            "urgency": "medium",
            "resources": {
                "abundant": collected["hardware_data"].get("battery_level", 0.5) > 0.7,
                "data_available": True,
                "limited": False
            }
        }
        
        three_sages_result = None
        if THREE_SAGES_AVAILABLE:
            from three_sages_framework import ThreeSagesFramework
            framework = ThreeSagesFramework()
            three_sages_result = framework.assess(context)
        
        # 爻变推演
        new_gua = self._divination(current_gua, initial_gua, collected["hardware_data"])
        
        result = {
            "current_gua": current_gua.to_dict(),
            "initial_gua": collected["initial_gua"],
            "new_gua": new_gua.to_dict(),
            "yao_changes": self._calculate_yao_changes(current_gua, new_gua),
            "three_sages": three_sages_result,
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "process", result)
        return result
    def _output(self, processed: dict) -> dict:
        """输出环节 - 结果渲染"""
        new_gua = GuaState(
            gua_number=processed["new_gua"]["number"],
            yao_bits=[int(b) for b in processed["new_gua"]["binary"]]
        )
        
        # 生成自然语言解释
        interpretation = self._interpret_gua(new_gua)
        
        result = {
            "gua_name": new_gua.name,
            "gua_number": new_gua.number,
            "binary": new_gua.binary,
            "interpretation": interpretation,
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "output", result)
        return result
    
    def _execute(self, output: dict) -> dict:
        """执行环节 - 动作执行"""
        # 模拟执行操作
        execution_result = {
            "executed": True,
            "action": f"update_gua_to_{output['gua_name']}",
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "execute", execution_result)
        return execution_result
    
    def _feedback(self, executed: dict) -> dict:
        """获取环节 - 反馈回流"""
        feedback = {
            "success": executed.get("executed", False),
            "timestamp": datetime.now().isoformat()
        }
        
        self._log(self.cycle_log, "feedback", feedback)
        return feedback
    
    def _data_to_gua(self, hardware_data: dict, input_data: dict) -> GuaState:
        """将数据转换为卦态"""
        # 基于硬件数据生成卦象
        # CPU 高负载 → 阳爻多，低负载 → 阴爻多
        cpu = hardware_data.get("cpu_load", 0.5)
        memory = hardware_data.get("memory_usage", 0.5)
        battery = hardware_data.get("battery_level", 0.5)
        
        # 简单映射：高值→阳爻，低值→阴爻
        bits = [
            1 if cpu > 0.5 else 0,      # 上爻
            1 if memory > 0.5 else 0,   # 五爻
            1 if battery > 0.5 else 0,  # 四爻
            1 if cpu > 0.7 else 0,      # 三爻
            1 if memory > 0.7 else 0,   # 二爻
            1 if battery > 0.7 else 0,  # 初爻
        ]
        
        number = GuaState._bits_to_number(bits)
        return GuaState(gua_number=number, yao_bits=bits)
    
    def _divination(self, current: GuaState, initial: GuaState, 
                    hardware: dict) -> GuaState:
        """核心推演 - 卦变计算"""
        # 基于当前状态和输入计算新卦
        # 简化版：随机爻变 + 硬件数据影响
        
        new_bits = initial.yao_bits.copy()
        
        # 根据硬件状态决定爻变
        cpu = hardware.get("cpu_load", 0.5)
        if cpu > 0.8:
            # 高负载 → 更多阳爻
            for i in range(len(new_bits)):
                if random.random() < 0.3:
                    new_bits[i] = 1
        elif cpu < 0.3:
            # 低负载 → 更多阴爻
            for i in range(len(new_bits)):
                if random.random() < 0.3:
                    new_bits[i] = 0
        
        number = GuaState._bits_to_number(new_bits)
        return GuaState(gua_number=number, yao_bits=new_bits)
    
    def _calculate_yao_changes(self, old: GuaState, new: GuaState) -> List[dict]:
        """计算爻变"""
        changes = []
        for i, (old_bit, new_bit) in enumerate(zip(old.yao_bits, new.yao_bits)):
            if old_bit != new_bit:
                changes.append({
                    "position": 6 - i,  # 转换为 1-6
                    "from": "yin" if old_bit == 0 else "yang",
                    "to": "yin" if new_bit == 0 else "yang"
                })
        return changes
    
    def _interpret_gua(self, gua: GuaState) -> str:
        """卦象解释"""
        interpretations = {
            "QIAN": "天行健，君子以自强不息。阳气旺盛，宜积极进取。",
            "KUN": "地势坤，君子以厚德载物。阴气凝聚，宜包容承载。",
            "ZHUN": "万物始生，艰难初现。宜耐心等待，积蓄力量。",
            "MENG": "启蒙之时，宜虚心学习。蒙昧初开，需师长指引。",
            "TAI": "天地交泰，万物通达。阴阳和谐，宜顺势而为。",
            "PI": "天地不交，闭塞不通。宜守正待时，不可妄动。",
            "JISHI": "已完成，阴阳各得其位。宜保持谨慎，防微杜渐。",
            "WEIJ": "未完成，阴阳失位。宜继续努力，终将获得成功。",
        }
        
        return interpretations.get(gua.name, f"{gua.name}卦：阴阳变化，需结合具体情况解读。")
    
    def _evolve(self, feedback: dict) -> GuaState:
        """演化 - 卦态更新"""
        current = self.get_current_gua()
        
        # 根据反馈决定演化方向
        if feedback.get("success", False):
            # 成功 → 向更高层次演化
            new_number = min(64, current.number + 1)
        else:
            # 失败 → 保持或回退
            new_number = max(1, current.number - 1)
        
        return GuaState(gua_number=new_number)
    
    def get_status(self) -> dict:
        """获取引擎状态"""
        current_gua = self.get_current_gua()
        return {
            "timestamp": datetime.now().isoformat(),
            "current_gua": current_gua.to_dict(),
            "evolution_level": self.state["evolution_level"],
            "cycle_count": self.state["cycle_count"],
            "last_cycle": self.state["last_cycle"],
            "phase": self._current_phase.value
        }
    
    def set_gua(self, number: int) -> Dict:
        """手动设置卦态"""
        if number < 1 or number > 64:
            return {"success": False, "error": "卦序号必须在 1-64 之间"}
        
        new_gua = GuaState(gua_number=number)
        self.state["current_gua"] = new_gua.to_dict()
        self._save_state()
        
        return {
            "success": True,
            "gua": new_gua.to_dict()
        }


class SelfCycleEngine:
    """自循环演化引擎 - 无人值守自动循环"""
    
    def __init__(self, gua_engine: GuaEngine = None, interval: int = 60):
        self.gua_engine = gua_engine or GuaEngine()
        self.interval = interval
        self._running = False
        self._thread = None
        self._cycle_count = 0
    
    def start(self):
        """启动自循环"""
        if self._running:
            return {"success": False, "error": "已在运行"}
        
        self._running = True
        self._thread = threading.Thread(target=self._run_cycle, daemon=True)
        self._thread.start()
        
        return {"success": True, "interval": self.interval}
    
    def stop(self):
        """停止自循环"""
        self._running = False
        if self._thread:
            self._thread.join(timeout=5)
        return {"success": True}
    
    def _run_cycle(self):
        """运行循环"""
        while self._running:
            result = self.gua_engine.cycle()
            self._cycle_count += 1
            time.sleep(self.interval)
    
    def run_once(self) -> Dict:
        """运行单轮"""
        return self.gua_engine.cycle()
    
    def get_status(self) -> dict:
        """获取状态"""
        return {
            "running": self._running,
            "interval": self.interval,
            "cycle_count": self._cycle_count,
            "gua_engine": self.gua_engine.get_status()
        }


# 便捷函数
def get_gua_status() -> dict:
    """获取六十四卦系统状态"""
    engine = GuaEngine()
    return engine.get_status()


def run_cycle(input_data: dict = None) -> dict:
    """运行单轮六环节"""
    engine = GuaEngine()
    return engine.cycle(input_data)


if __name__ == "__main__":
    # 测试
    engine = GuaEngine()
    
    print("=" * 70)
    print("Phase 4: 六十四卦自循环演化系统 - 测试")
    print("=" * 70)
    
    # 1. 获取当前卦态
    print("\n🔮 1. 当前卦态")
    status = engine.get_status()
    gua_data = status["current_gua"]
    gua = GuaState(gua_number=gua_data["number"], yao_bits=[int(b) for b in gua_data["binary"]])
    print(f"   卦象: {gua.name}({gua.number})")
    print(f"   二进制: {gua.binary}")
    print(f"   阴阳比: {gua.yin_yang_ratio:.2f} (阳:{gua.yang_count}/阴:{gua.yin_count})")
    
    # 2. 运行单轮
    print("\n🔄 2. 运行六环节闭环")
    result = engine.cycle({"test": "input"})
    print(f"   周期 ID: {result['cycle_id']}")
    print(f"   新卦象: {result['new_gua']['name']}({result['new_gua']['number']})")
    
    if result["phases"]["process"].get("yao_changes"):
        print(f"   爻变:")
        for change in result["phases"]["process"]["yao_changes"]:
            print(f"      位置 {change['position']}: {change['from']} → {change['to']}")
    
    print(f"   解释: {result['phases']['output']['interpretation'][:100]}...")
    
    # 3. 测试爻变
    print("\n🔀 3. 测试爻变")
    test_gua = GuaState(1)  # 乾卦
    print(f"   初始: {test_gua}")
    
    changed = test_gua.change_yao(1, 0)  # 初爻变阴
    print(f"   初爻变阴: {changed} ({changed.name})")
    
    # 4. 自循环测试
    print("\n⏱️ 4. 自循环测试（单轮）")
    cycle_engine = SelfCycleEngine(gua_engine=engine, interval=5)
    result = cycle_engine.run_once()
    print(f"   完成: {result['cycle_id']}")
    
    print("\n" + "=" * 70)
    print("✅ Phase 4 测试完成")
    print("=" * 70)
