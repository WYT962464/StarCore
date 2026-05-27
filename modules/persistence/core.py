"""
持久化核心模块 (Persistence Core Module)
==========================================
系统状态的持久化存储与恢复机制。

存储内容：
- 无极潜能数据
- 太极演化阶段
- 两仪/四象/八卦状态
- 六十四卦当前卦象
- 演化循环次数
- iOS 数据快照

存储策略：
- 主存储：JSON 文件（人类可读）
- 增量存储：JSONL 日志（可追溯）
- 数据库：SQLite（查询优化）

恢复策略：
- 自动恢复：启动时加载最后状态
- 版本兼容：支持版本迁移
- 损坏恢复：备份 + 校验
"""

import json
import sqlite3
import threading
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from dataclasses import dataclass, asdict, field
from enum import Enum
import shutil


class PersistableType(Enum):
    """可持久化类型"""
    WUJI = "wuji"           # 无极
    TAIJI = "taiji"         # 太极
    LIANGYI = "liangyi"     # 两仪
    SIXIANG = "sixiang"     # 四象
    BAGUA = "bagua"         # 八卦
    GUA64 = "gua64"         # 六十四卦
    IOS_DATA = "ios_data"   # iOS 数据
    SYSTEM = "system"       # 系统配置


class SaveMode(Enum):
    """保存模式"""
    FULL = "full"           # 全量保存
    INCREMENTAL = "incremental"  # 增量保存
    BACKUP = "backup"       # 备份保存


@dataclass
class PersistableState:
    """可持久化状态"""
    type: PersistableType
    version: str
    timestamp: str
    data: Dict[str, Any]
    checksum: str = ""
    
    def __post_init__(self):
        if not self.checksum:
            self.checksum = self._compute_checksum()
    
    def _compute_checksum(self) -> str:
        """计算校验和"""
        content = json.dumps({
            "type": self.type.value,
            "version": self.version,
            "data": self.data
        }, sort_keys=True)
        return hashlib.sha256(content.encode()).hexdigest()[:16]
    
    def verify(self) -> bool:
        """验证完整性"""
        return self.checksum == self._compute_checksum()


@dataclass
class SaveRecord:
    """保存记录"""
    id: str
    timestamp: str
    mode: SaveMode
    types: List[PersistableType]
    record_count: int
    checksum: str


@dataclass
class RecoveryResult:
    """恢复结果"""
    success: bool
    recovered_types: List[PersistableType]
    failed_types: List[str]
    warnings: List[str]
    timestamp: str


class PersistenceCore:
    """持久化核心"""
    
    CURRENT_VERSION = "1.0.0"
    
    def __init__(self, name: str = "PERSISTENCE"):
        self.name = name
        self.base_path = Path("/home/ubuntu/starcore/data/persistence")
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        # 存储路径
        self.state_dir = self.base_path / "states"
        self.state_dir.mkdir(exist_ok=True)
        
        self.incremental_dir = self.base_path / "incremental"
        self.incremental_dir.mkdir(exist_ok=True)
        
        self.backup_dir = self.base_path / "backups"
        self.backup_dir.mkdir(exist_ok=True)
        
        # 数据库
        self.db_path = self.base_path / "persistence.db"
        self._init_database()
        
        # 锁
        self.lock = threading.RLock()
        
        # 缓存
        self.state_cache: Dict[PersistableType, PersistableState] = {}
        self.cache_dirty: Dict[PersistableType, bool] = {}
        
        # 统计
        self.save_count = 0
        self.load_count = 0
        self.recovery_count = 0
        self.error_count = 0
    
    def _init_database(self) -> None:
        """初始化数据库"""
        conn = sqlite3.connect(str(self.db_path))
        cursor = conn.cursor()
        
        # 状态表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS states (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                version TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                data TEXT NOT NULL,
                checksum TEXT NOT NULL,
                saved_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # 保存记录表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS save_records (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                mode TEXT NOT NULL,
                types TEXT NOT NULL,
                record_count INTEGER NOT NULL,
                checksum TEXT NOT NULL
            )
        """)
        
        # 恢复记录表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS recovery_records (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                success INTEGER NOT NULL,
                recovered_types TEXT,
                failed_types TEXT,
                warnings TEXT
            )
        """)
        
        # 版本表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS schema_version (
                id INTEGER PRIMARY KEY,
                version TEXT NOT NULL,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # 插入版本
        cursor.execute("""
            INSERT OR IGNORE INTO schema_version (id, version) VALUES (1, ?)
        """, (self.CURRENT_VERSION,))
        
        conn.commit()
        conn.close()
    
    def save_state(self, ptype: PersistableType, data: Dict[str, Any],
                   mode: SaveMode = SaveMode.INCREMENTAL) -> bool:
        """
        保存状态
        
        Args:
            ptype: 状态类型
            data: 状态数据
            mode: 保存模式
            
        Returns:
            是否成功
        """
        with self.lock:
            try:
                # 创建可持久化状态
                state = PersistableState(
                    type=ptype,
                    version=self.CURRENT_VERSION,
                    timestamp=datetime.now().isoformat(),
                    data=data
                )
                
                # 更新缓存
                self.state_cache[ptype] = state
                self.cache_dirty[ptype] = True
                
                # 根据模式保存
                if mode == SaveMode.FULL:
                    self._save_full(state)
                elif mode == SaveMode.INCREMENTAL:
                    self._save_incremental(state)
                elif mode == SaveMode.BACKUP:
                    self._save_backup(state)
                
                # 写入数据库
                self._db_save_state(state)
                
                self.save_count += 1
                return True
                
            except Exception as e:
                self.error_count += 1
                import traceback
                traceback.print_exc()
                return False
    
    def load_state(self, ptype: PersistableType) -> Optional[Dict[str, Any]]:
        """
        加载状态
        
        Args:
            ptype: 状态类型
            
        Returns:
            状态数据
        """
        with self.lock:
            # 先检查缓存
            if ptype in self.state_cache:
                state = self.state_cache[ptype]
                if state.verify():
                    self.load_count += 1
                    return state.data
            
            # 从数据库加载
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            
            cursor.execute("""
                SELECT data, checksum FROM states WHERE type = ? ORDER BY saved_at DESC LIMIT 1
            """, (ptype.value,))
            
            row = cursor.fetchone()
            conn.close()
            
            if row:
                data, checksum = row
                # 验证校验和
                temp_state = PersistableState(
                    type=ptype,
                    version=self.CURRENT_VERSION,
                    timestamp="",
                    data=json.loads(data),
                    checksum=checksum
                )
                if temp_state.verify():
                    self.load_count += 1
                    self.state_cache[ptype] = temp_state
                    return temp_state.data
            
            return None
    
    def save_all(self, states: Dict[PersistableType, Dict[str, Any]],
                 mode: SaveMode = SaveMode.INCREMENTAL) -> SaveRecord:
        """
        批量保存所有状态
        
        Args:
            states: 状态字典
            mode: 保存模式
            
        Returns:
            保存记录
        """
        with self.lock:
            record_id = f"save_{datetime.now().strftime('%Y%m%d%H%M%S')}"
            types = list(states.keys())
            
            # 保存每个状态
            for ptype, data in states.items():
                self.save_state(ptype, data, mode)
            
            # 创建记录
            record = SaveRecord(
                id=record_id,
                timestamp=datetime.now().isoformat(),
                mode=mode,
                types=types,
                record_count=len(states),
                checksum=hashlib.md5(json.dumps({k.value: v for k, v in states.items()}, sort_keys=True).encode()).hexdigest()[:16]
            )
            
            # 写入数据库
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO save_records (id, timestamp, mode, types, record_count, checksum)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (record.id, record.timestamp, mode.value, 
                  json.dumps([t.value for t in types]), record.record_count, record.checksum))
            conn.commit()
            conn.close()
            
            # 全量保存时创建备份（避免递归）
            if mode == SaveMode.FULL and not record.id.startswith("backup_"):
                self.create_backup(f"save_{record.id}")
            
            return record
    
    def recover_all(self) -> RecoveryResult:
        """
        恢复所有状态
        
        Returns:
            恢复结果
        """
        with self.lock:
            recovered = []
            failed = []
            warnings = []
            
            # 所有可恢复类型
            all_types = list(PersistableType)
            
            for ptype in all_types:
                data = self.load_state(ptype)
                if data:
                    recovered.append(ptype)
                else:
                    failed.append(ptype.value)
                    warnings.append(f"{ptype.value}: 无可用状态")
            
            # 记录恢复
            record_id = f"recovery_{datetime.now().strftime('%Y%m%d%H%M%S')}"
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO recovery_records (id, timestamp, success, recovered_types, failed_types, warnings)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (record_id, datetime.now().isoformat(),
                  1 if not failed else 0,
                  json.dumps([t.value for t in recovered]),
                  json.dumps(failed),
                  json.dumps(warnings)))
            conn.commit()
            conn.close()
            
            self.recovery_count += 1
            
            return RecoveryResult(
                success=len(failed) == 0,
                recovered_types=recovered,
                failed_types=failed,
                warnings=warnings,
                timestamp=datetime.now().isoformat()
            )
    
    def create_backup(self, name: Optional[str] = None) -> str:
        """
        创建完整备份
        
        Args:
            name: 备份名称
            
        Returns:
            备份文件路径
        """
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_name = name or f"backup_{timestamp}"
        backup_path = self.backup_dir / backup_name
        
        # 排除 backups 目录本身
        exclude = {str(self.backup_dir)}
        
        # 复制整个数据目录（排除 backups）
        if backup_path.exists():
            shutil.rmtree(backup_path)
        
        backup_path.mkdir(parents=True, exist_ok=True)
        
        for item in self.base_path.iterdir():
            if item.name == "backups":
                continue  # 跳过 backups 目录
            if item.is_file():
                shutil.copy2(item, backup_path / item.name)
            elif item.is_dir():
                shutil.copytree(item, backup_path / item.name)
        
        # 创建备份记录
        record = {
            "name": backup_name,
            "timestamp": datetime.now().isoformat(),
            "path": str(backup_path),
            "size_bytes": sum(f.stat().st_size for f in backup_path.rglob('*') if f.is_file())
        }
        
        with open(self.backup_dir / f"{backup_name}_meta.json", "w") as f:
            json.dump(record, f, indent=2)
        
        return str(backup_path)
    
    def restore_backup(self, backup_name: str) -> bool:
        """
        从备份恢复
        
        Args:
            backup_name: 备份名称
            
        Returns:
            是否成功
        """
        backup_path = self.backup_dir / backup_name
        
        if not backup_path.exists():
            return False
        
        with self.lock:
            # 清空当前数据
            for f in self.base_path.glob('*'):
                if f.is_file():
                    f.unlink()
                elif f.is_dir():
                    shutil.rmtree(f)
            
            # 从备份恢复
            for f in backup_path.rglob('*'):
                if f.is_file():
                    target = self.base_path / f.relative_to(backup_path)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(f, target)
            
            # 重新初始化数据库
            self._init_database()
            
            # 清空缓存
            self.state_cache.clear()
            self.cache_dirty.clear()
            
            return True
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self.lock:
            # 获取备份列表
            backups = []
            for f in self.backup_dir.glob('backup_*'):
                if f.is_dir():
                    backups.append(f.name)
            
            # 获取数据库统计
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) FROM states")
            state_count = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM save_records")
            save_record_count = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM recovery_records")
            recovery_record_count = cursor.fetchone()[0]
            
            conn.close()
            
            return {
                "name": self.name,
                "version": self.CURRENT_VERSION,
                "save_count": self.save_count,
                "load_count": self.load_count,
                "recovery_count": self.recovery_count,
                "error_count": self.error_count,
                "cached_types": list(self.state_cache.keys()),
                "dirty_types": [k.value for k, v in self.cache_dirty.items() if v],
                "database": {
                    "states": state_count,
                    "save_records": save_record_count,
                    "recovery_records": recovery_record_count
                },
                "backups": backups,
                "storage": {
                    "base_path": str(self.base_path),
                    "size_bytes": sum(f.stat().st_size for f in self.base_path.rglob('*') if f.is_file())
                }
            }
    
    def clear_cache(self) -> None:
        """清空缓存"""
        with self.lock:
            self.state_cache.clear()
            self.cache_dirty.clear()
    
    def _save_full(self, state: PersistableState) -> None:
        """全量保存"""
        state_path = self.state_dir / f"{state.type.value}.json"
        
        # 转换为可序列化的字典
        state_dict = asdict(state)
        state_dict["type"] = state.type.value  # 枚举转字符串
        
        with open(state_path, "w") as f:
            json.dump(state_dict, f, indent=2, ensure_ascii=False)
    
    def _save_incremental(self, state: PersistableState) -> None:
        """增量保存"""
        log_path = self.incremental_dir / f"{state.type.value}.jsonl"
        
        # 转换为可序列化的字典
        state_dict = asdict(state)
        state_dict["type"] = state.type.value  # 枚举转字符串
        
        with open(log_path, "a") as f:
            f.write(json.dumps(state_dict, ensure_ascii=False) + "\n")
    
    def _save_backup(self, state: PersistableState) -> None:
        """备份保存"""
        backup_path = self.backup_dir / f"{state.type.value}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        # 转换为可序列化的字典
        state_dict = asdict(state)
        state_dict["type"] = state.type.value  # 枚举转字符串
        
        with open(backup_path, "w") as f:
            json.dump(state_dict, f, indent=2, ensure_ascii=False)
    
    def _create_backup(self, record: SaveRecord) -> None:
        """创建完整备份"""
        self.create_backup(f"save_{record.id}")
    
    def _db_save_state(self, state: PersistableState) -> None:
        """保存到数据库"""
        try:
            conn = sqlite3.connect(str(self.db_path))
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT OR REPLACE INTO states (id, type, version, timestamp, data, checksum)
                VALUES (?, ?, ?, ?, ?, ?)
            """, (
                f"{state.type.value}_{state.timestamp}",
                state.type.value,
                state.version,
                state.timestamp,
                json.dumps(state.data),
                state.checksum
            ))
            
            conn.commit()
            conn.close()
        except Exception as e:
            print(f"   [WARN] 数据库保存失败：{e}")


# 测试
if __name__ == "__main__":
    print("=" * 70)
    print("💾 持久化核心模块 测试")
    print("=" * 70)
    
    persistence = PersistenceCore()
    
    # 测试 1：保存状态
    print("\n📝 测试 1：保存无极状态")
    wuji_data = {
        "base_potential": 0.5,
        "accumulated_potential": 0.3,
        "total_potential": 0.8,
        "cycle_count": 5,
        "evolution_speed": 1.5
    }
    success = persistence.save_state(PersistableType.WUJI, wuji_data)
    print(f"   保存成功：{success}")
    
    # 测试 2：加载状态
    print("\n📝 测试 2：加载无极状态")
    loaded = persistence.load_state(PersistableType.WUJI)
    if loaded:
        print(f"   基础潜能：{loaded['base_potential']}")
        print(f"   循环次数：{loaded['cycle_count']}")
    else:
        print("   加载失败")
    
# 测试 3：批量保存所有状态
    print("\n📝 测试 3：批量保存所有状态")
    all_states = {
        PersistableType.WUJI: {"potential": 0.8, "cycles": 5},
        PersistableType.TAIJI: {"phase": "taiji", "cycle": "phase_3"},
        PersistableType.LIANGYI: {"yin": 0.4, "yang": 0.6},
        PersistableType.SIXIANG: {"old_yin": 0.1, "young_yang": 0.9},
        PersistableType.BAGUA: {"qian": 1, "kun": 0},
        PersistableType.GUA64: {"current_gua": 1, "name": "乾"},
        PersistableType.IOS_DATA: {"battery": 85, "memory": 60},
        PersistableType.SYSTEM: {"version": "1.0.0"}
    }
    record = persistence.save_all(all_states, SaveMode.FULL)
    print(f"   保存记录：{record.id}")
    print(f"   类型数：{record.record_count}")
    
    # 测试 4：恢复所有状态
    print("\n📝 测试 4：恢复所有状态")
    # 清空缓存模拟重启
    persistence.clear_cache()
    
    result = persistence.recover_all()
    print(f"   恢复成功：{result.success}")
    print(f"   恢复类型：{[t.value for t in result.recovered_types]}")
    if result.failed_types:
        print(f"   失败类型：{result.failed_types}")
    
    # 测试 5：创建备份
    print("\n📝 测试 5：创建备份")
    backup_path = persistence.create_backup("test_backup")
    print(f"   备份路径：{backup_path}")
    
    # 测试 6：获取统计
    print("\n📝 测试 6：获取统计")
    stats = persistence.get_stats()
    print(f"   保存次数：{stats['save_count']}")
    print(f"   加载次数：{stats['load_count']}")
    print(f"   恢复次数：{stats['recovery_count']}")
    print(f"   数据库状态：{stats['database']['states']} 条")
    print(f"   备份数：{len(stats['backups'])}")
    
    # 测试 7：从备份恢复
    print("\n📝 测试 7：从备份恢复")
    if stats['backups']:
        success = persistence.restore_backup(stats['backups'][0])
        print(f"   恢复成功：{success}")
    
    print("\n✅ 持久化核心模块测试完成")
