"""
坤 ☷ 存储系统 (Storage System)
================================
八卦之二，柔顺承载，代表存储与记忆能力。

功能：
- 统一记忆层管理
- 卦象数据存储
- 决策历史记录
- 系统状态快照

卦象：坤 ☷ (000) - 地势坤，君子以厚德载物
属性：柔顺、承载、包容
"""

import json
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass, asdict
import threading


@dataclass
class MemoryEntry:
    """记忆条目"""
    id: str
    category: str
    content: Any
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class StorageSystem:
    """坤存储系统"""
    
    def __init__(self, name: str = "KUN"):
        self.name = name
        self.binary = "000"  # 坤卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/kun_storage")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        # 内存存储（快速访问）
        self.memory_store: Dict[str, MemoryEntry] = {}
        self.memory_lock = threading.Lock()
        
        # 统计
        self.storage_count = 0
        self.retrieval_count = 0
        
        # 分类存储
        self.categories = {
            "decisions": self.base_path / "decisions.jsonl",
            "guae": self.base_path / "guae.jsonl",
            "states": self.base_path / "states.jsonl",
            "experience": self.base_path / "experience.jsonl",
            "config": self.base_path / "config.json"
        }
        
        # 初始化存储文件
        for path in self.categories.values():
            if not path.exists():
                path.touch()
    
    def store(self, category: str, content: Any, metadata: Dict[str, Any] = None) -> str:
        """
        存储数据
        
        Args:
            category: 分类 (decisions/guae/states/experience/config)
            content: 存储内容
            metadata: 元数据
            
        Returns:
            存储ID
        """
        entry_id = self._generate_id(category, content)
        timestamp = datetime.now().isoformat()
        
        entry = MemoryEntry(
            id=entry_id,
            category=category,
            content=content,
            timestamp=timestamp,
            metadata=metadata or {}
        )
        
        # 写入内存
        with self.memory_lock:
            self.memory_store[entry_id] = entry
        
        # 写入磁盘
        self._write_to_disk(category, entry)
        
        self.storage_count += 1
        
        return entry_id
    
    def retrieve(self, entry_id: str) -> Optional[MemoryEntry]:
        """
        检索数据
        
        Args:
            entry_id: 存储ID
            
        Returns:
            记忆条目
        """
        # 先从内存检索
        with self.memory_lock:
            if entry_id in self.memory_store:
                self.retrieval_count += 1
                return self.memory_store[entry_id]
        
        # 从磁盘检索
        entry = self._read_from_disk(entry_id)
        if entry:
            with self.memory_lock:
                self.memory_store[entry_id] = entry
            self.retrieval_count += 1
        
        return entry
    
    def query_by_category(self, category: str, limit: int = 100) -> List[MemoryEntry]:
        """
        按分类查询
        
        Args:
            category: 分类
            limit: 限制数量
            
        Returns:
            记忆条目列表
        """
        entries = []
        
        # 从内存查询
        with self.memory_lock:
            for entry in self.memory_store.values():
                if entry.category == category:
                    entries.append(entry)
        
        # 按时间排序，返回最新的
        entries.sort(key=lambda x: x.timestamp, reverse=True)
        return entries[:limit]
    
    def query_by_content(self, category: str, keyword: str, limit: int = 50) -> List[MemoryEntry]:
        """
        按内容关键词查询
        
        Args:
            category: 分类
            keyword: 关键词
            limit: 限制数量
            
        Returns:
            匹配的记忆条目列表
        """
        entries = self.query_by_category(category, limit=1000)
        results = []
        
        for entry in entries:
            content_str = json.dumps(entry.content)
            if keyword.lower() in content_str.lower():
                results.append(entry)
                if len(results) >= limit:
                    break
        
        return results
    
    def update_config(self, key: str, value: Any) -> None:
        """更新配置"""
        config_path = self.categories["config"]
        
        # 读取现有配置
        config = {}
        if config_path.exists():
            with open(config_path, "r") as f:
                config = json.load(f)
        
        # 更新配置
        config[key] = {
            "value": value,
            "timestamp": datetime.now().isoformat()
        }
        
        # 写入配置
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
    
    def get_config(self, key: str, default: Any = None) -> Any:
        """获取配置"""
        config_path = self.categories["config"]
        
        if not config_path.exists():
            return default
        
        with open(config_path, "r") as f:
            config = json.load(f)
        
        if key in config:
            return config[key].get("value", default)
        return default
    
    def get_snapshot(self) -> Dict[str, Any]:
        """获取存储系统快照"""
        return {
            "name": self.name,
            "binary": self.binary,
            "storage_count": self.storage_count,
            "retrieval_count": self.retrieval_count,
            "memory_entries": len(self.memory_store),
            "categories": {
                cat: path.stat().st_size if path.exists() else 0
                for cat, path in self.categories.items()
            }
        }
    
    def _generate_id(self, category: str, content: Any) -> str:
        """生成存储ID"""
        content_str = json.dumps(content, sort_keys=True)
        hash_val = hashlib.md5(content_str.encode()).hexdigest()[:12]
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        return f"{category}_{timestamp}_{hash_val}"
    
    def _write_to_disk(self, category: str, entry: MemoryEntry) -> None:
        """写入磁盘"""
        path = self.categories.get(category)
        if not path:
            return
        
        with open(path, "a") as f:
            f.write(json.dumps(asdict(entry), ensure_ascii=False) + "\n")
    
    def _read_from_disk(self, entry_id: str) -> Optional[MemoryEntry]:
        """从磁盘读取"""
        # 遍历所有分类文件
        for category, path in self.categories.items():
            if not path.exists():
                continue
            
            with open(path, "r") as f:
                for line in f:
                    try:
                        data = json.loads(line.strip())
                        if data.get("id") == entry_id:
                            return MemoryEntry(**data)
                    except json.JSONDecodeError:
                        continue
        
        return None


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("📦 坤存储系统 测试")
    print("=" * 60)
    
    storage = StorageSystem()
    
    # 测试1：存储决策
    print("\n📝 测试1：存储决策")
    decision = {
        "action": "优化系统",
        "confidence": 0.85,
        "reasoning": "CPU负载较高"
    }
    entry_id = storage.store("decisions", decision, {"source": "qian_engine"})
    print(f"   存储ID: {entry_id}")
    
    # 测试2：检索数据
    print("\n📝 测试2：检索数据")
    entry = storage.retrieve(entry_id)
    if entry:
        print(f"   分类: {entry.category}")
        print(f"   内容: {entry.content}")
        print(f"   时间: {entry.timestamp}")
    
    # 测试3：按分类查询
    print("\n📝 测试3：按分类查询")
    decisions = storage.query_by_category("decisions", limit=5)
    print(f"   找到 {len(decisions)} 条决策记录")
    
    # 测试4：配置管理
    print("\n📝 测试4：配置管理")
    storage.update_config("system_mode", "active")
    mode = storage.get_config("system_mode")
    print(f"   系统模式: {mode}")
    
    # 获取快照
    print("\n📊 存储系统快照:")
    snapshot = storage.get_snapshot()
    print(f"   存储次数: {snapshot['storage_count']}")
    print(f"   内存条目: {snapshot['memory_entries']}")
    
    print("\n✅ 坤存储系统测试完成")
