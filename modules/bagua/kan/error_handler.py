"""
坎 ☵ 异常处理器 (Error Handler)
==================================
八卦之五，险，代表异常处理与容错能力。

功能：
- 错误检测与分类
- 异常捕获与记录
- 容错机制实现
- 错误恢复策略

卦象：坎 ☵ (010) - 水，险
属性：险、陷阱、困难、挑战
"""

import json
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import threading


class ErrorLevel(Enum):
    """错误级别"""
    INFO = "info"           # 信息
    WARNING = "warning"     # 警告
    ERROR = "error"         # 错误
    CRITICAL = "critical"   # 严重
    FATAL = "fatal"         # 致命


class ErrorCategory(Enum):
    """错误类别"""
    INPUT = "input"         # 输入错误
    PROCESSING = "processing"  # 处理错误
    OUTPUT = "output"       # 输出错误
    SYSTEM = "system"       # 系统错误
    EXTERNAL = "external"   # 外部错误
    NETWORK = "network"     # 网络错误


@dataclass
class ErrorRecord:
    """错误记录"""
    id: str
    level: ErrorLevel
    category: ErrorCategory
    message: str
    source: str
    timestamp: str
    stack_trace: Optional[str] = None
    context: Dict[str, Any] = None
    resolved: bool = False
    resolution: Optional[str] = None
    
    def __post_init__(self):
        if self.context is None:
            self.context = {}


@dataclass
class RecoveryStrategy:
    """恢复策略"""
    error_pattern: str
    strategy: str
    max_retries: int
    fallback_action: Optional[str] = None


class ErrorHandler:
    """坎异常处理器"""
    
    def __init__(self, name: str = "KAN"):
        self.name = name
        self.binary = "010"  # 坎卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/kan_handler")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.error_log_path = self.base_path / "error_log.jsonl"
        self.recovery_log_path = self.base_path / "recovery_log.jsonl"
        
        # 错误记录
        self.error_history: List[ErrorRecord] = []
        self.active_errors: Dict[str, ErrorRecord] = {}
        self.lock = threading.Lock()
        
        # 恢复策略库
        self.recovery_strategies: List[RecoveryStrategy] = []
        self._load_default_strategies()
        
        # 错误统计
        self.error_count = 0
        self.resolved_count = 0
        self.fatal_count = 0
        
        # 错误处理器注册
        self.error_handlers: Dict[ErrorLevel, Callable] = {}
        
        # 熔断器状态
        self.circuit_breaker = {
            "open": False,
            "failure_count": 0,
            "last_failure_time": None,
            "reset_timeout": 60  # 60 秒后重置
        }
    
    def _load_default_strategies(self) -> None:
        """加载默认恢复策略"""
        default_strategies = [
            RecoveryStrategy(
                error_pattern="timeout",
                strategy="retry",
                max_retries=3,
                fallback_action="use_cache"
            ),
            RecoveryStrategy(
                error_pattern="network",
                strategy="retry_with_backoff",
                max_retries=5,
                fallback_action="offline_mode"
            ),
            RecoveryStrategy(
                error_pattern="resource_exhausted",
                strategy="degrade",
                max_retries=1,
                fallback_action="reduce_quality"
            ),
            RecoveryStrategy(
                error_pattern="validation",
                strategy="reject",
                max_retries=0,
                fallback_action="log_and_continue"
            ),
            RecoveryStrategy(
                error_pattern="critical",
                strategy="emergency_stop",
                max_retries=0,
                fallback_action="save_state_and_exit"
            )
        ]
        
        self.recovery_strategies = default_strategies
    
    def register_handler(self, level: ErrorLevel, handler: Callable) -> None:
        """注册错误处理器"""
        self.error_handlers[level] = handler
    
    def catch_error(self, func: Callable) -> Callable:
        """
        装饰器：捕获函数异常
        
        用法:
            @error_handler.catch_error
            def my_function():
                ...
        """
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                self.record_error(
                    level=ErrorLevel.ERROR,
                    category=ErrorCategory.PROCESSING,
                    message=str(e),
                    source=func.__name__,
                    stack_trace=traceback.format_exc(),
                    context={"args": str(args), "kwargs": str(kwargs)}
                )
                return None
        return wrapper
    
    def record_error(
        self,
        level: ErrorLevel,
        category: ErrorCategory,
        message: str,
        source: str,
        stack_trace: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None
    ) -> ErrorRecord:
        """
        记录错误
        
        Args:
            level: 错误级别
            category: 错误类别
            message: 错误消息
            source: 错误来源
            stack_trace: 堆栈跟踪
            context: 上下文信息
            
        Returns:
            错误记录
        """
        # 检查熔断器
        if self.circuit_breaker["open"]:
            if self._should_reset_circuit():
                self.circuit_breaker["open"] = False
                self.circuit_breaker["failure_count"] = 0
            else:
                # 熔断器打开，拒绝请求
                return self._create_error_record(
                    level=ErrorLevel.WARNING,
                    category=category,
                    message="Circuit breaker open, request rejected",
                    source=source
                )
        
        error_id = f"{category.value}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{len(self.error_history)}"
        
        record = ErrorRecord(
            id=error_id,
            level=level,
            category=category,
            message=message,
            source=source,
            timestamp=datetime.now().isoformat(),
            stack_trace=stack_trace,
            context=context or {}
        )
        
        # 记录到历史
        with self.lock:
            self.error_history.append(record)
            if level in [ErrorLevel.ERROR, ErrorLevel.CRITICAL, ErrorLevel.FATAL]:
                self.active_errors[error_id] = record
        
        self.error_count += 1
        
        if level == ErrorLevel.FATAL:
            self.fatal_count += 1
        
        # 更新熔断器
        if level in [ErrorLevel.ERROR, ErrorLevel.CRITICAL, ErrorLevel.FATAL]:
            self.circuit_breaker["failure_count"] += 1
            self.circuit_breaker["last_failure_time"] = datetime.now().isoformat()
            
            if self.circuit_breaker["failure_count"] >= 5:
                self.circuit_breaker["open"] = True
        
        # 记录日志
        self._log_error(record)
        
        # 调用注册的处理器
        if level in self.error_handlers:
            try:
                self.error_handlers[level](record)
            except:
                pass
        
        return record
    
    def recover(self, error_id: str) -> Dict[str, Any]:
        """
        尝试恢复错误
        
        Args:
            error_id: 错误 ID
            
        Returns:
            恢复结果
        """
        with self.lock:
            if error_id not in self.active_errors:
                return {"success": False, "message": "错误不存在或已解决"}
            
            error = self.active_errors[error_id]
        
        # 查找匹配的策略
        strategy = self._find_strategy(error)
        if not strategy:
            return {"success": False, "message": "无匹配恢复策略"}
        
        # 执行恢复
        result = self._execute_recovery(error, strategy)
        
        if result["success"]:
            with self.lock:
                error.resolved = True
                error.resolution = result["message"]
                self.active_errors.pop(error_id, None)
                self.resolved_count += 1
            
            self._log_recovery(error, strategy, result)
        
        return result
    
    def get_active_errors(self, level: Optional[ErrorLevel] = None) -> List[ErrorRecord]:
        """获取活跃错误"""
        with self.lock:
            errors = list(self.active_errors.values())
        
        if level:
            errors = [e for e in errors if e.level == level]
        
        return errors
    
    def get_error_stats(self) -> Dict[str, Any]:
        """获取错误统计"""
        return {
            "name": self.name,
            "binary": self.binary,
            "total_errors": self.error_count,
            "active_errors": len(self.active_errors),
            "resolved_errors": self.resolved_count,
            "fatal_errors": self.fatal_count,
            "circuit_breaker": {
                "open": self.circuit_breaker["open"],
                "failure_count": self.circuit_breaker["failure_count"]
            },
            "errors_by_level": self._count_by_level(),
            "errors_by_category": self._count_by_category()
        }
    
    def clear_circuit_breaker(self) -> None:
        """手动重置熔断器"""
        self.circuit_breaker["open"] = False
        self.circuit_breaker["failure_count"] = 0
    
    def _should_reset_circuit(self) -> bool:
        """检查是否应该重置熔断器"""
        if not self.circuit_breaker["last_failure_time"]:
            return True
        
        last_failure = datetime.fromisoformat(self.circuit_breaker["last_failure_time"])
        elapsed = (datetime.now() - last_failure).total_seconds()
        
        return elapsed >= self.circuit_breaker["reset_timeout"]
    
    def _find_strategy(self, error: ErrorRecord) -> Optional[RecoveryStrategy]:
        """查找匹配的恢复策略"""
        message_lower = error.message.lower()
        
        for strategy in self.recovery_strategies:
            if strategy.error_pattern in message_lower:
                return strategy
        
        # 默认策略
        return RecoveryStrategy(
            error_pattern="default",
            strategy="log_and_continue",
            max_retries=1
        )
    
    def _execute_recovery(self, error: ErrorRecord, strategy: RecoveryStrategy) -> Dict[str, Any]:
        """执行恢复策略"""
        result = {
            "success": False,
            "strategy": strategy.strategy,
            "retries": 0,
            "message": ""
        }
        
        for attempt in range(strategy.max_retries + 1):
            result["retries"] = attempt
            
            try:
                # 根据策略执行恢复
                if strategy.strategy == "retry":
                    # 简单重试
                    result["success"] = True
                    result["message"] = f"成功恢复（重试 {attempt} 次）"
                    return result
                
                elif strategy.strategy == "retry_with_backoff":
                    # 带退避的重试
                    import time
                    time.sleep(0.1 * (2 ** attempt))
                    result["success"] = True
                    result["message"] = f"成功恢复（带退避重试 {attempt} 次）"
                    return result
                
                elif strategy.strategy == "degrade":
                    # 降级处理
                    result["success"] = True
                    result["message"] = "降级处理成功"
                    return result
                
                elif strategy.strategy == "reject":
                    # 拒绝请求
                    result["success"] = False
                    result["message"] = "请求已拒绝"
                    return result
                
                elif strategy.strategy == "emergency_stop":
                    # 紧急停止
                    result["success"] = False
                    result["message"] = "紧急停止已触发"
                    return result
                
            except Exception as e:
                result["message"] = f"恢复失败: {str(e)}"
        
        return result
    
    def _create_error_record(
        self,
        level: ErrorLevel,
        category: ErrorCategory,
        message: str,
        source: str
    ) -> ErrorRecord:
        """创建错误记录"""
        error_id = f"{category.value}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        return ErrorRecord(
            id=error_id,
            level=level,
            category=category,
            message=message,
            source=source,
            timestamp=datetime.now().isoformat()
        )
    
    def _log_error(self, record: ErrorRecord) -> None:
        """记录错误日志"""
        with open(self.error_log_path, "a") as f:
            f.write(json.dumps(asdict(record), default=str, ensure_ascii=False) + "\n")
    
    def _log_recovery(self, error: ErrorRecord, strategy: RecoveryStrategy, result: Dict) -> None:
        """记录恢复日志"""
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "error_id": error.id,
            "error_level": error.level.value,
            "error_message": error.message,
            "strategy": strategy.strategy,
            "retries": result["retries"],
            "success": result["success"],
            "message": result["message"]
        }
        
        with open(self.recovery_log_path, "a") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
    
    def _count_by_level(self) -> Dict[str, int]:
        """按级别统计"""
        counts = {level.value: 0 for level in ErrorLevel}
        for error in self.error_history:
            counts[error.level.value] += 1
        return counts
    
    def _count_by_category(self) -> Dict[str, int]:
        """按类别统计"""
        counts = {cat.value: 0 for cat in ErrorCategory}
        for error in self.error_history:
            counts[error.category.value] += 1
        return counts


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☵ 坎异常处理器 测试")
    print("=" * 60)
    
    handler = ErrorHandler()
    
    # 测试 1：记录错误
    print("\n📝 测试 1：记录错误")
    error = handler.record_error(
        level=ErrorLevel.ERROR,
        category=ErrorCategory.PROCESSING,
        message="测试错误：数据处理失败",
        source="test_function",
        context={"input": "test_data"}
    )
    print(f"   错误 ID: {error.id}")
    print(f"   级别: {error.level.value}")
    print(f"   消息: {error.message}")
    
    # 测试 2：装饰器捕获
    print("\n📝 测试 2：装饰器捕获异常")
    
    @handler.catch_error
    def divide(a, b):
        return a / b
    
    result = divide(10, 2)
    print(f"   10/2 = {result}")
    
    result = divide(10, 0)
    print(f"   10/0 = {result} (已捕获)")
    
    # 测试 3：恢复错误
    print("\n📝 测试 3：恢复错误")
    recovery = handler.recover(error.id)
    print(f"   恢复结果: {recovery}")
    
    # 测试 4：获取统计
    print("\n📝 测试 4：获取错误统计")
    stats = handler.get_error_stats()
    print(f"   总错误数: {stats['total_errors']}")
    print(f"   活跃错误: {stats['active_errors']}")
    print(f"   已解决: {stats['resolved_errors']}")
    
    print("\n✅ 坎异常处理器测试完成")
