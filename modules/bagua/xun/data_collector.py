"""
巽 ☴ 数据采集器 (Data Collector)
==================================
八卦之四，入，代表采集与输入能力。

功能：
- 硬件数据采集（CPU/内存/电池/网络/存储）
- 用户输入采集
- 外部数据源接入
- 数据预处理与格式化

卦象：巽 ☴ (011) - 风，入
属性：入、采集、流动、渗透
"""

import json
import time
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, asdict
from enum import Enum
import threading
import os


class DataSource(Enum):
    """数据源类型"""
    HARDWARE = "hardware"      # 硬件数据
    SYSTEM = "system"          # 系统数据
    USER = "user"              # 用户输入
    EXTERNAL = "external"      # 外部API
    GUA = "gua"                # 卦象数据
    MEMORY = "memory"          # 记忆数据


@dataclass
class DataPoint:
    """数据点"""
    id: str
    source: DataSource
    category: str
    value: Any
    unit: str
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class DataCollector:
    """巽数据采集器"""
    
    def __init__(self, name: str = "XUN"):
        self.name = name
        self.binary = "011"  # 巽卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/xun_collector")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.data_log_path = self.base_path / "data_log.jsonl"
        self.hardware_log_path = self.base_path / "hardware_log.jsonl"
        
        # 数据缓存
        self.data_cache: Dict[str, DataPoint] = {}
        self.cache_lock = threading.Lock()
        
        # 采集器注册
        self.collectors: Dict[DataSource, Callable] = {}
        self._register_default_collectors()
        
        # 统计
        self.collection_count = 0
        self.cache_size = 0
    
    def _register_default_collectors(self) -> None:
        """注册默认采集器"""
        self.collectors[DataSource.HARDWARE] = self._collect_hardware
        self.collectors[DataSource.SYSTEM] = self._collect_system
        self.collectors[DataSource.GUA] = self._collect_gua
    
    def collect(self, source: DataSource, category: str = "default", 
                custom_data: Optional[Dict[str, Any]] = None) -> DataPoint:
        """
        采集数据
        
        Args:
            source: 数据源类型
            category: 数据类别
            custom_data: 自定义数据（如果提供，直接使用）
            
        Returns:
            数据点
        """
        # 获取数据
        if custom_data:
            data = custom_data
        elif source in self.collectors:
            data = self.collectors[source]()
        else:
            data = {"error": f"未知数据源: {source.value}"}
        
        # 生成数据点
        data_id = f"{source.value}_{category}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        point = DataPoint(
            id=data_id,
            source=source,
            category=category,
            value=data,
            unit="",
            timestamp=datetime.now().isoformat()
        )
        
        # 缓存数据
        with self.cache_lock:
            self.data_cache[data_id] = point
            self.cache_size = len(self.data_cache)
        
        self.collection_count += 1
        
        # 记录日志
        self._log_data(point)
        
        return point
    
    def collect_all(self) -> Dict[DataSource, DataPoint]:
        """
        采集所有数据源
        
        Returns:
            各数据源的数据点字典
        """
        results = {}
        
        for source in DataSource:
            if source in self.collectors:
                results[source] = self.collect(source)
        
        return results
    
    def get_cached_data(self, source: Optional[DataSource] = None, 
                       limit: int = 100) -> List[DataPoint]:
        """获取缓存数据"""
        with self.cache_lock:
            points = list(self.data_cache.values())
        
        if source:
            points = [p for p in points if p.source == source]
        
        # 按时间排序，返回最新的
        points.sort(key=lambda p: p.timestamp, reverse=True)
        return points[:limit]
    
    def get_hardware_status(self) -> Dict[str, Any]:
        """获取硬件状态（便捷方法）"""
        point = self.collect(DataSource.HARDWARE, "status")
        return point.value
    
    def _collect_hardware(self) -> Dict[str, Any]:
        """采集硬件数据"""
        hardware_data = {}
        
        try:
            # CPU使用率
            cpu_result = subprocess.run(
                ["top", "-bn1"],
                capture_output=True, text=True, timeout=5
            )
            for line in cpu_result.stdout.split("\n"):
                if "Cpu(s)" in line or "%Cpu" in line:
                    # 解析CPU使用率
                    parts = line.split()
                    for i, part in enumerate(parts):
                        if "id" in part.lower():
                            idle = float(parts[i-1].replace("%", ""))
                            hardware_data["cpu_load"] = round(1 - idle/100, 2)
                            break
        except Exception as e:
            hardware_data["cpu_error"] = str(e)
        
        try:
            # 内存使用
            mem_result = subprocess.run(
                ["free", "-m"],
                capture_output=True, text=True, timeout=5
            )
            for line in mem_result.stdout.split("\n"):
                if "Mem:" in line:
                    parts = line.split()
                    total = int(parts[1])
                    used = int(parts[2])
                    hardware_data["memory_total_mb"] = total
                    hardware_data["memory_used_mb"] = used
                    hardware_data["memory_usage"] = round(used/total, 2) if total > 0 else 0
                    break
        except Exception as e:
            hardware_data["memory_error"] = str(e)
        
        try:
            # 磁盘使用
            disk_result = subprocess.run(
                ["df", "-h", "/"],
                capture_output=True, text=True, timeout=5
            )
            for line in disk_result.stdout.split("\n"):
                if "/" == line.split()[-1] if line.split() else False:
                    parts = line.split()
                    if len(parts) >= 5:
                        hardware_data["disk_total"] = parts[1]
                        hardware_data["disk_used"] = parts[2]
                        hardware_data["disk_available"] = parts[3]
                        hardware_data["disk_usage_percent"] = parts[4]
                    break
        except Exception as e:
            hardware_data["disk_error"] = str(e)
        
        # 添加采集时间
        hardware_data["timestamp"] = datetime.now().isoformat()
        hardware_data["collector"] = self.name
        
        return hardware_data
    
    def _collect_system(self) -> Dict[str, Any]:
        """采集系统数据"""
        system_data = {
            "hostname": os.uname().nodename,
            "os": os.uname().sysname,
            "kernel": os.uname().release,
            "python_version": f"{__import__('sys').version_info.major}.{__import__('sys').version_info.minor}",
            "timestamp": datetime.now().isoformat(),
            "collector": self.name
        }
        
        # 运行进程数
        try:
            result = subprocess.run(
                ["ps", "aux"],
                capture_output=True, text=True, timeout=5
            )
            system_data["process_count"] = len(result.stdout.split("\n")) - 1
        except Exception as e:
            system_data["process_error"] = str(e)
        
        return system_data
    
    def _collect_gua(self) -> Dict[str, Any]:
        """采集卦象数据"""
        # 读取当前卦象文件
        gua_path = Path("/home/ubuntu/starcore/data/gua/current_gua.json")
        
        if gua_path.exists():
            with open(gua_path, "r") as f:
                gua_data = json.load(f)
        else:
            gua_data = {
                "current_gua": {"number": 3, "name": "ZHUN", "binary": "000011"},
                "cycle_count": 0,
                "timestamp": datetime.now().isoformat()
            }
        
        gua_data["collector"] = self.name
        gua_data["timestamp"] = datetime.now().isoformat()
        
        return gua_data
    
    def _log_data(self, point: DataPoint) -> None:
        """记录数据日志"""
        log_path = self.data_log_path
        
        if point.source == DataSource.HARDWARE:
            log_path = self.hardware_log_path
        
        with open(log_path, "a") as f:
            f.write(json.dumps(asdict(point), default=str, ensure_ascii=False) + "\n")
    
    def get_status(self) -> Dict[str, Any]:
        """获取采集器状态"""
        return {
            "name": self.name,
            "binary": self.binary,
            "collection_count": self.collection_count,
            "cache_size": self.cache_size,
            "active_collectors": list(self.collectors.keys()),
            "recent_data": [
                {"id": p.id, "source": p.source.value, "timestamp": p.timestamp}
                for p in self.get_cached_data(limit=5)
            ]
        }


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("🌬️ 巽数据采集器 测试")
    print("=" * 60)
    
    collector = DataCollector()
    
    # 测试1：采集硬件数据
    print("\n📝 测试1：采集硬件数据")
    hw_point = collector.collect(DataSource.HARDWARE, "status")
    print(f"   数据ID: {hw_point.id}")
    print(f"   CPU负载: {hw_point.value.get('cpu_load', 'N/A')}")
    print(f"   内存使用: {hw_point.value.get('memory_usage', 'N/A')}")
    
    # 测试2：采集系统数据
    print("\n📝 测试2：采集系统数据")
    sys_point = collector.collect(DataSource.SYSTEM, "info")
    print(f"   数据ID: {sys_point.id}")
    print(f"   主机名: {sys_point.value.get('hostname', 'N/A')}")
    print(f"   Python版本: {sys_point.value.get('python_version', 'N/A')}")
    
    # 测试3：采集卦象数据
    print("\n📝 测试3：采集卦象数据")
    gua_point = collector.collect(DataSource.GUA, "current")
    print(f"   数据ID: {gua_point.id}")
    print(f"   当前卦象: {gua_point.value.get('current_gua', {}).get('name', 'N/A')}")
    
    # 测试4：采集所有数据
    print("\n📝 测试4：采集所有数据源")
    all_data = collector.collect_all()
    for source, point in all_data.items():
        print(f"   {source.value}: {point.id}")
    
    # 获取状态
    print("\n📊 采集器状态:")
    status = collector.get_status()
    print(f"   采集次数: {status['collection_count']}")
    print(f"   缓存大小: {status['cache_size']}")
    
    print("\n✅ 巽数据采集器测试完成")
