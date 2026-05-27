"""
六环节闭环执行器 (Six-Cycle Closed-Loop Executor)
===================================================
串联无极→太极→两仪→四象→八卦→万物的完整执行系统。

六环节定义：
1. 无极层：潜能存储与万物归一
2. 太极层：演化阶段管理
3. 两仪层：阴阳状态切换
4. 四象层：状态流转
5. 八卦层：功能模块执行
6. 万物层：输出与反馈

闭环机制：
- 万物输出 → 沉淀无极 → 潜能提升 → 演化加速 → 螺旋上升
"""

import json
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum

# 导入各层模块
try:
    from modules.bagua.wuji.core import WujiCore, WujiState
    from modules.bagua.taiji.engine import TaijiEngine, TaijiPhase
    from modules.bagua.liangyi.switcher import LiangyiSwitcher, Liangyi
    from modules.bagua.sixiang.state_manager import FourSymbolManager, FourSymbol
    from modules.bagua.qian.decision_engine import DecisionEngine
    from modules.bagua.kun.storage_system import StorageSystem
    from modules.bagua.zhen.event_trigger import EventTrigger, EventType
    from modules.bagua.xun.data_collector import DataCollector, DataSource
    from modules.bagua.kan.error_handler import ErrorHandler, ErrorLevel
    from modules.bagua.li.state_renderer import StateRenderer, RenderFormat
    from modules.bagua.gen.hibernate_controller import HibernateController, SystemState
    from modules.bagua.dui.feedback_transmitter import FeedbackTransmitter, FeedbackType
except ImportError:
    # 测试时允许部分导入失败
    pass


class CyclePhase(Enum):
    """执行阶段"""
    WUJI = "wuji"           # 1. 无极
    TAIJI = "taiji"         # 2. 太极
    LIANGYI = "liangyi"     # 3. 两仪
    SIXIANG = "sixiang"     # 4. 四象
    BAGUA = "bagua"         # 5. 八卦
    WANWU = "wanwu"         # 6. 万物


class ExecutionStatus(Enum):
    """执行状态"""
    IDLE = "idle"           # 空闲
    RUNNING = "running"     # 运行中
    PAUSED = "paused"       # 暂停
    COMPLETED = "completed" # 完成
    ERROR = "error"         # 错误


@dataclass
class CycleRecord:
    """执行记录"""
    id: str
    phase: CyclePhase
    status: ExecutionStatus
    start_time: str
    end_time: Optional[str]
    duration_seconds: Optional[float]
    result: Dict[str, Any] = None
    error: Optional[str] = None
    
    def __post_init__(self):
        if self.result is None:
            self.result = {}


@dataclass
class FullCycleResult:
    """完整循环结果"""
    cycle_number: int
    start_time: str
    end_time: str
    total_duration: float
    phases: List[CycleRecord]
    wuji_potential_before: float
    wuji_potential_after: float
    potential_gain: float
    success: bool
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class SixCycleExecutor:
    """六环节闭环执行器"""
    
    def __init__(self, name: str = "SIXCYCLE"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/sixcycle_executor")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        self.execution_log_path = self.base_path / "execution_log.jsonl"
        self.cycle_result_path = self.base_path / "cycle_results.jsonl"
        
        # 各层模块
        self.wuji: Optional[WujiCore] = None
        self.taiji: Optional[TaijiEngine] = None
        self.liangyi: Optional[LiangyiSwitcher] = None
        self.sixiang: Optional[FourSymbolManager] = None
        self.bagua_modules: Dict[str, Any] = {}
        
        # 执行状态
        self.current_status = ExecutionStatus.IDLE
        self.current_phase = CyclePhase.WUJI
        self.status_lock = threading.Lock()
        
        # 执行历史
        self.execution_history: List[CycleRecord] = []
        self.cycle_results: List[FullCycleResult] = []
        
        # 回调
        self.phase_callbacks: List[Callable] = []
        self.cycle_callbacks: List[Callable] = []
        
        # 统计
        self.total_cycles = 0
        self.successful_cycles = 0
        self.total_execution_time = 0.0
        
        # 自动执行
        self._auto_enabled = False
        self._auto_thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
    
    def initialize(self) -> Dict[str, Any]:
        """
        初始化所有模块
        
        Returns:
            初始化结果
        """
        results = {"success": True, "modules": {}}
        
        try:
            # 无极层
            self.wuji = WujiCore()
            results["modules"]["wuji"] = "initialized"
        except Exception as e:
            results["success"] = False
            results["modules"]["wuji"] = f"error: {e}"
        
        try:
            # 太极层
            self.taiji = TaijiEngine()
            self.taiji.set_liangyi_switcher(self.liangyi)
            self.taiji.set_sixiang_manager(self.sixiang)
            results["modules"]["taiji"] = "initialized"
        except Exception as e:
            results["success"] = False
            results["modules"]["taiji"] = f"error: {e}"
        
        try:
            # 两仪层
            self.liangyi = LiangyiSwitcher()
            results["modules"]["liangyi"] = "initialized"
        except Exception as e:
            results["success"] = False
            results["modules"]["liangyi"] = f"error: {e}"
        
        try:
            # 四象层
            self.sixiang = FourSymbolManager()
            results["modules"]["sixiang"] = "initialized"
        except Exception as e:
            results["success"] = False
            results["modules"]["sixiang"] = f"error: {e}"
        
        # 八卦层
        try:
            self.bagua_modules["qian"] = DecisionEngine()
            results["modules"]["qian"] = "initialized"
        except Exception as e:
            results["modules"]["qian"] = f"error: {e}"
        
        try:
            self.bagua_modules["kun"] = StorageSystem()
            results["modules"]["kun"] = "initialized"
        except Exception as e:
            results["modules"]["kun"] = f"error: {e}"
        
        try:
            self.bagua_modules["zhen"] = EventTrigger()
            results["modules"]["zhen"] = "initialized"
        except Exception as e:
            results["modules"]["zhen"] = f"error: {e}"
        
        try:
            self.bagua_modules["xun"] = DataCollector()
            results["modules"]["xun"] = "initialized"
        except Exception as e:
            results["modules"]["xun"] = f"error: {e}"
        
        try:
            self.bagua_modules["kan"] = ErrorHandler()
            results["modules"]["kan"] = "initialized"
        except Exception as e:
            results["modules"]["kan"] = f"error: {e}"
        
        try:
            self.bagua_modules["li"] = StateRenderer()
            results["modules"]["li"] = "initialized"
        except Exception as e:
            results["modules"]["li"] = f"error: {e}"
        
        try:
            self.bagua_modules["gen"] = HibernateController()
            results["modules"]["gen"] = "initialized"
        except Exception as e:
            results["modules"]["gen"] = f"error: {e}"
        
        try:
            self.bagua_modules["dui"] = FeedbackTransmitter()
            results["modules"]["dui"] = "initialized"
        except Exception as e:
            results["modules"]["dui"] = f"error: {e}"
        
        # 联动设置
        if self.taiji and self.liangyi and self.sixiang:
            self.taiji.set_liangyi_switcher(self.liangyi)
            self.taiji.set_sixiang_manager(self.sixiang)
        
        return results
    
    def register_phase_callback(self, callback: Callable) -> None:
        """注册阶段回调"""
        self.phase_callbacks.append(callback)
    
    def register_cycle_callback(self, callback: Callable) -> None:
        """注册循环回调"""
        self.cycle_callbacks.append(callback)
    
    def get_status(self) -> Dict[str, Any]:
        """获取执行状态"""
        with self.status_lock:
            return {
                "name": self.name,
                "current_status": self.current_status.value,
                "current_phase": self.current_phase.value,
                "total_cycles": self.total_cycles,
                "successful_cycles": self.successful_cycles,
                "success_rate": round(self.successful_cycles / self.total_cycles * 100, 1) if self.total_cycles > 0 else 0,
                "total_execution_time": round(self.total_execution_time, 2),
                "modules_initialized": {
                    "wuji": self.wuji is not None,
                    "taiji": self.taiji is not None,
                    "liangyi": self.liangyi is not None,
                    "sixiang": self.sixiang is not None,
                    "bagua": len(self.bagua_modules)
                }
            }
    
    def execute_phase(self, phase: CyclePhase, context: Optional[Dict[str, Any]] = None) -> CycleRecord:
        """
        执行单个阶段
        
        Args:
            phase: 执行阶段
            context: 上下文
            
        Returns:
            执行记录
        """
        record_id = f"exec_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.execution_history)}"
        start_time = datetime.now().isoformat()
        
        record = CycleRecord(
            id=record_id,
            phase=phase,
            status=ExecutionStatus.RUNNING,
            start_time=start_time,
            end_time=None,
            duration_seconds=None,
            result={},
            error=None
        )
        
        try:
            with self.status_lock:
                self.current_phase = phase
            
            # 执行各阶段
            if phase == CyclePhase.WUJI:
                record.result = self._execute_wuji(context)
            elif phase == CyclePhase.TAIJI:
                record.result = self._execute_taiji(context)
            elif phase == CyclePhase.LIANGYI:
                record.result = self._execute_liangyi(context)
            elif phase == CyclePhase.SIXIANG:
                record.result = self._execute_sixiang(context)
            elif phase == CyclePhase.BAGUA:
                record.result = self._execute_bagua(context)
            elif phase == CyclePhase.WANWU:
                record.result = self._execute_wanwu(context)
            
            record.status = ExecutionStatus.COMPLETED
            
        except Exception as e:
            record.status = ExecutionStatus.ERROR
            record.error = str(e)
        
        # 计算时长
        end_time = datetime.now().isoformat()
        start = datetime.fromisoformat(start_time)
        end = datetime.fromisoformat(end_time)
        record.end_time = end_time
        record.duration_seconds = (end - start).total_seconds()
        
        # 记录
        self.execution_history.append(record)
        self._log_execution(record)
        
        # 触发回调
        self._notify_phase_complete(phase, record)
        
        return record
    
    def execute_full_cycle(self, context: Optional[Dict[str, Any]] = None) -> FullCycleResult:
        """
        执行完整循环
        
        Args:
            context: 上下文
            
        Returns:
            循环结果
        """
        cycle_number = self.total_cycles + 1
        start_time = datetime.now().isoformat()
        
        # 记录无极潜能
        wuji_potential_before = 0.0
        if self.wuji:
            wuji_potential_before = self.wuji.get_potential().total_potential
        
        phases = []
        success = True
        
        # 执行 6 个阶段
        for phase in CyclePhase:
            record = self.execute_phase(phase, context)
            phases.append(record)
            if record.status == ExecutionStatus.ERROR:
                success = False
        
        end_time = datetime.now().isoformat()
        
        # 计算总时长
        start = datetime.fromisoformat(start_time)
        end = datetime.fromisoformat(end_time)
        total_duration = (end - start).total_seconds()
        
        # 记录无极潜能变化
        wuji_potential_after = 0.0
        potential_gain = 0.0
        if self.wuji:
            wuji_potential_after = self.wuji.get_potential().total_potential
            potential_gain = wuji_potential_after - wuji_potential_before
        
        # 完成循环
        self.total_cycles += 1
        if success:
            self.successful_cycles += 1
        self.total_execution_time += total_duration
        
        # 触发无极螺旋升级
        if self.wuji and success:
            self.wuji.complete_cycle(cycle_number)
        
        # 创建结果
        result = FullCycleResult(
            cycle_number=cycle_number,
            start_time=start_time,
            end_time=end_time,
            total_duration=total_duration,
            phases=phases,
            wuji_potential_before=round(wuji_potential_before, 4),
            wuji_potential_after=round(wuji_potential_after, 4),
            potential_gain=round(potential_gain, 4),
            success=success,
            metadata=context or {}
        )
        
        self.cycle_results.append(result)
        self._log_cycle_result(result)
        
        # 触发回调
        self._notify_cycle_complete(result)
        
        return result
    
    def start_auto_cycle(self, interval: Optional[int] = None) -> None:
        """
        启动自动循环
        
        Args:
            interval: 循环间隔（秒），None 则使用无极层计算的速度
        """
        if self._auto_enabled:
            return
        
        self._auto_enabled = True
        
        def auto_loop():
            while not self._stop_event.is_set():
                self.execute_full_cycle({"auto": True})
                
                # 计算下次间隔
                if interval:
                    wait = interval
                elif self.wuji:
                    wait = self.wuji.calculate_evolution_interval(base_interval=10)
                else:
                    wait = 10
                
                self._stop_event.wait(wait)
        
        self._auto_thread = threading.Thread(target=auto_loop, daemon=True)
        self._auto_thread.start()
    
    def stop_auto_cycle(self) -> None:
        """停止自动循环"""
        self._auto_enabled = False
        self._stop_event.set()
        if self._auto_thread:
            self._auto_thread.join(timeout=5)
    
    def get_cycle_history(self, limit: int = 10) -> List[FullCycleResult]:
        """获取循环历史"""
        with self.status_lock:
            return self.cycle_results[-limit:]
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.status_lock:
            return {
                "name": self.name,
                "total_cycles": self.total_cycles,
                "successful_cycles": self.successful_cycles,
                "success_rate": round(self.successful_cycles / self.total_cycles * 100, 1) if self.total_cycles > 0 else 0,
                "total_execution_time": round(self.total_execution_time, 2),
                "average_cycle_time": round(self.total_execution_time / self.total_cycles, 2) if self.total_cycles > 0 else 0,
                "current_status": self.current_status.value,
                "wuji_potential": self.wuji.get_potential_stats() if self.wuji else None
            }
    
    def _execute_wuji(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行无极阶段"""
        if not self.wuji:
            return {"error": "Wuji core not initialized"}
        
        # 收集潜能
        potential = self.wuji.get_potential()
        
        return {
            "state": self.wuji.get_state().value,
            "base_potential": potential.base_potential,
            "total_potential": potential.total_potential,
            "cycle_count": potential.cycle_count,
            "evolution_speed": potential.evolution_speed
        }
    
    def _execute_taiji(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行太极阶段"""
        if not self.taiji:
            return {"error": "Taiji engine not initialized"}
        
        self.taiji.evolve("六环节执行")
        
        return {
            "phase": self.taiji.get_current_phase().value,
            "cycle": self.taiji.get_current_cycle().value,
            "cycle_count": self.taiji.current_state.cycle_count if self.taiji.current_state else 0
        }
    
    def _execute_liangyi(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行两仪阶段"""
        if not self.liangyi:
            return {"error": "Liangyi switcher not initialized"}
        
        self.liangyi.switch("六环节执行")
        
        return {
            "liangyi": self.liangyi.get_current_liangyi().value,
            "transitions": self.liangyi.transition_count
        }
    
    def _execute_sixiang(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行四象阶段"""
        if not self.sixiang:
            return {"error": "Sixiang manager not initialized"}
        
        self.sixiang.auto_transition("六环节执行")
        
        return {
            "symbol": self.sixiang.current_state.symbol.value if self.sixiang.current_state else None,
            "transitions": self.sixiang.transition_count
        }
    
    def _execute_bagua(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行八卦阶段"""
        results = {}
        
        # 执行各八卦模块
        if "qian" in self.bagua_modules:
            decision = self.bagua_modules["qian"].decide(context or {})
            results["qian"] = {"decision_id": decision.get("id", "N/A")}
        
        if "kun" in self.bagua_modules:
            entry_id = self.bagua_modules["kun"].store("cycle", {"phase": "bagua"})
            results["kun"] = {"entry_id": entry_id}
        
        if "zhen" in self.bagua_modules:
            event = self.bagua_modules["zhen"].detect_event(EventType.SYSTEM, "executor", {"phase": "bagua"})
            results["zhen"] = {"event_id": event.id}
        
        if "xun" in self.bagua_modules:
            data = self.bagua_modules["xun"].collect(DataSource.SYSTEM, "cycle", {})
            results["xun"] = {"data_id": data.id}
        
        if "kan" in self.bagua_modules:
            results["kan"] = {"status": "ready"}
        
        if "li" in self.bagua_modules:
            output = self.bagua_modules["li"].render({"phase": "bagua"}, RenderFormat.TEXT)
            results["li"] = {"render_length": len(output.content)}
        
        if "gen" in self.bagua_modules:
            results["gen"] = {"state": self.bagua_modules["gen"].get_state().value}
        
        if "dui" in self.bagua_modules:
            record = self.bagua_modules["dui"].submit_feedback("八卦执行完成", FeedbackType.POSITIVE)
            results["dui"] = {"feedback_id": record.id}
        
        return results
    
    def _execute_wanwu(self, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行万物阶段（万物归一）"""
        if not self.wuji:
            return {"error": "Wuji core not initialized"}
        
        # 将执行结果沉淀进无极
        result_record = self.wuji.add_potential(
            amount=0.05,  # 每次循环贡献 5% 潜能
            source="sixcycle_executor",
            content={"type": "cycle_output", "cycle": self.total_cycles + 1}
        )
        
        return {
            "wuji_record_id": result_record.id,
            "potential_added": result_record.potential_added,
            "message": "万物归一完成"
        }
    
    def _notify_phase_complete(self, phase: CyclePhase, record: CycleRecord) -> None:
        """通知阶段完成"""
        for callback in self.phase_callbacks:
            try:
                callback(phase, record)
            except:
                pass
    
    def _notify_cycle_complete(self, result: FullCycleResult) -> None:
        """通知循环完成"""
        for callback in self.cycle_callbacks:
            try:
                callback(result)
            except:
                pass
    
    def _log_execution(self, record: CycleRecord) -> None:
        """记录执行日志"""
        with open(self.execution_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")
    
    def _log_cycle_result(self, result: FullCycleResult) -> None:
        """记录循环结果"""
        with open(self.cycle_result_path, "a") as f:
            f.write(json.dumps(asdict(result), default=str, ensure_ascii=False) + "\n")


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☯ 六环节闭环执行器 测试")
    print("=" * 60)
    
    executor = SixCycleExecutor()
    
    # 测试 1：初始化
    print("\n📝 测试 1：初始化所有模块")
    init_results = executor.initialize()
    for module, status in init_results["modules"].items():
        print(f"   {module}: {status}")
    
    # 测试 2：执行单个阶段
    print("\n📝 测试 2：执行单个阶段")
    record = executor.execute_phase(CyclePhase.WUJI)
    print(f"   阶段：{record.phase.value}")
    print(f"   状态：{record.status.value}")
    print(f"   时长：{record.duration_seconds:.2f} 秒")
    
    # 测试 3：执行完整循环
    print("\n📝 测试 3：执行完整循环")
    result = executor.execute_full_cycle({"test": "full_cycle"})
    print(f"   循环 {result.cycle_number}:")
    print(f"   总时长：{result.total_duration:.2f} 秒")
    print(f"   成功：{result.success}")
    print(f"   潜能变化：{result.wuji_potential_before} → {result.wuji_potential_after}")
    
    # 测试 4：执行多次循环
    print("\n📝 测试 4：执行多次循环")
    for i in range(3):
        result = executor.execute_full_cycle()
        print(f"   循环 {result.cycle_number}: 时长 {result.total_duration:.2f}s, 潜能 +{result.potential_gain}")
    
    # 测试 5：获取统计
    print("\n📝 测试 5：获取统计")
    stats = executor.get_stats()
    print(f"   总循环：{stats['total_cycles']}")
    print(f"   成功率：{stats['success_rate']}%")
    print(f"   平均时长：{stats['average_cycle_time']} 秒")
    
    print("\n✅ 六环节闭环执行器测试完成")
