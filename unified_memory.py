#!/usr/bin/env python3
"""
统一记忆层 v1.0

融合目标：Hermes memory + 星核决策数据库 + 自循环日志 → 统一存储

架构：
┌─────────────────────────────────────────────────────────────┐
│                    统一记忆层                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Hermes      │  │ 星核决策    │  │ 自循环日志  │        │
│  │ memory      │  │ 数据库      │  │             │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
│         │                │                │                │
│         └────────────────┼────────────────┘                │
│                          ↓                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              UnifiedMemory (统一接口)                  │   │
│  │  - save(key, value, source)                          │   │
│  │  - get(key)                                          │   │
│  │  - search(query, source="all")                       │   │
│  │  - get_all_decisions(limit=10)                       │   │
│  │  - get_self_cycle_history(limit=10)                  │   │
│  │  - get_system_state()                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
"""

import json
import sqlite3
import os
from datetime import datetime
from typing import Dict, List, Optional, Any
from pathlib import Path

class UnifiedMemory:
    """统一记忆层"""
    
    def __init__(self):
        # 路径配置
        self.memory_file = Path.home() / ".hermes" / "memory.json"
        self.decision_db = "/home/ubuntu/starcore/data/decisions.db"
        self.cycle_log = "/home/ubuntu/starcore/data/self_cycle_log.jsonl"
        self.fusion_log = "/home/ubuntu/starcore/data/fusion_memory.jsonl"
        
        # 确保目录存在
        os.makedirs(os.path.dirname(self.decision_db), exist_ok=True)
        
        # 初始化决策数据库
        self._init_db()
    
    def _init_db(self):
        """初始化统一记忆数据库"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        
        # 决策表（已有）
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
        
        # 统一记忆表（新增）
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS unified_memory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                source TEXT NOT NULL,
                category TEXT NOT NULL,
                key TEXT NOT NULL,
                value TEXT NOT NULL,
                metadata TEXT
            )
        ''')
        
        # 融合日志表（新增）
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS fusion_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                action TEXT NOT NULL,
                details TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    # ==================== 写入接口 ====================
    
    def save(self, key: str, value: Any, source: str = "fusion", category: str = "general") -> Dict:
        """
        统一保存记忆
        
        source: "hermes" | "starcore" | "fusion" | "user"
        category: "general" | "decision" | "state" | "config" | "preference"
        """
        timestamp = datetime.now().isoformat()
        
        # 保存到统一记忆表
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO unified_memory (timestamp, source, category, key, value, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            timestamp,
            source,
            category,
            key,
            json.dumps(value, ensure_ascii=False),
            json.dumps({"fusion_version": "1.0"})
        ))
        conn.commit()
        conn.close()
        
        # 记录融合日志
        self._log_fusion("save", {
            "key": key,
            "source": source,
            "category": category,
            "timestamp": timestamp
        })
        
        return {"status": "saved", "key": key, "source": source, "timestamp": timestamp}
    
    def save_decision(self, decision: Dict) -> Dict:
        """保存决策（兼容原有格式）"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO decisions 
            (timestamp, input_source, hexagram, yang_directions, yin_evaluation, 
             ateng_calibration, final_decision, confidence, execution_result)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            decision.get("timestamp", datetime.now().isoformat()),
            decision.get("input_source", "fusion"),
            json.dumps(decision.get("hexagram", {})),
            json.dumps(decision.get("yang_directions", [])),
            json.dumps(decision.get("yin_evaluation", {})),
            json.dumps(decision.get("ateng_calibration")),
            decision.get("final_decision", ""),
            decision.get("confidence", 0),
            json.dumps(decision.get("execution_result"))
        ))
        conn.commit()
        conn.close()
        
        # 同时保存到统一记忆表
        self.save(
            key=f"decision_{decision.get('id', 'unknown')}",
            value=decision,
            source="starcore",
            category="decision"
        )
        
        return {"status": "saved", "type": "decision"}
    
    # ==================== 读取接口 ====================
    
    def get(self, key: str) -> Optional[Dict]:
        """根据 key 读取记忆"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT timestamp, source, category, key, value, metadata 
            FROM unified_memory WHERE key = ? ORDER BY id DESC LIMIT 1
        ''', (key,))
        row = cursor.fetchone()
        conn.close()
        
        if row:
            return {
                "timestamp": row[0],
                "source": row[1],
                "category": row[2],
                "key": row[3],
                "value": json.loads(row[4]),
                "metadata": json.loads(row[5]) if row[5] else None
            }
        return None
    
    def search(self, query: str, source: str = "all", category: str = "all", limit: int = 10) -> List[Dict]:
        """搜索记忆"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        
        sql = "SELECT timestamp, source, category, key, value, metadata FROM unified_memory WHERE 1=1"
        params = []
        
        if source != "all":
            sql += " AND source = ?"
            params.append(source)
        if category != "all":
            sql += " AND category = ?"
            params.append(category)
        if query:
            sql += " AND (key LIKE ? OR value LIKE ?)"
            params.extend([f"%{query}%", f"%{query}%"])
        
        sql += f" ORDER BY id DESC LIMIT {limit}"
        
        cursor.execute(sql, params)
        rows = cursor.fetchall()
        conn.close()
        
        results = []
        for row in rows:
            results.append({
                "timestamp": row[0],
                "source": row[1],
                "category": row[2],
                "key": row[3],
                "value": json.loads(row[4]),
                "metadata": json.loads(row[5]) if row[5] else None
            })
        
        return results
    
    def get_decisions(self, limit: int = 10) -> List[Dict]:
        """获取最近决策"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT id, timestamp, input_source, final_decision, confidence, ateng_calibration
            FROM decisions ORDER BY id DESC LIMIT ?
        ''', (limit,))
        rows = cursor.fetchall()
        conn.close()
        
        results = []
        for row in rows:
            results.append({
                "id": row[0],
                "timestamp": row[1],
                "source": row[2],
                "decision": row[3],
                "confidence": row[4],
                "ateng_calibration": json.loads(row[5]) if row[5] else None
            })
        
        return results
    
    def get_self_cycle_history(self, limit: int = 10) -> List[Dict]:
        """获取自循环历史"""
        try:
            with open(self.cycle_log) as f:
                lines = [json.loads(l) for l in f if l.strip()]
            return lines[-limit:]
        except Exception:
            return []
    
    def get_system_state(self) -> Dict:
        """获取当前系统状态（融合视角）"""
        import subprocess
        
        def _curl(url: str):
            try:
                result = subprocess.run(
                    ["curl", "-s", "--connect-timeout", "2", url],
                    capture_output=True, text=True, timeout=5
                )
                if result.returncode == 0 and result.stdout:
                    return json.loads(result.stdout)
            except Exception:
                pass
            return None
        
        # 获取各组件状态
        daemon = _curl("http://localhost:9090/health")
        cycle = _curl("http://localhost:9092/state")
        controller = _curl("http://localhost:9091/health")
        
        # 获取记忆统计
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM decisions")
        decision_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM unified_memory")
        memory_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT source, COUNT(*) FROM unified_memory GROUP BY source")
        memory_by_source = dict(cursor.fetchall())
        
        conn.close()
        
        return {
            "timestamp": datetime.now().isoformat(),
            "components": {
                "daemon": daemon,
                "cycle_system": cycle,
                "ios_controller": controller
            },
            "memory": {
                "total_decisions": decision_count,
                "total_memory_entries": memory_count,
                "by_source": memory_by_source
            },
            "fusion": {
                "version": "1.0",
                "status": "active"
            }
        }
    
    # ==================== 融合日志 ====================
    
    def _log_fusion(self, action: str, details: Dict):
        """记录融合操作日志"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO fusion_log (timestamp, action, details)
            VALUES (?, ?, ?)
        ''', (
            datetime.now().isoformat(),
            action,
            json.dumps(details, ensure_ascii=False)
        ))
        conn.commit()
        conn.close()
        
        # 同时写入 JSONL 文件
        with open(self.fusion_log, "a") as f:
            f.write(json.dumps({
                "timestamp": datetime.now().isoformat(),
                "action": action,
                "details": details
            }, ensure_ascii=False) + "\n")
    
    def get_fusion_log(self, limit: int = 20) -> List[Dict]:
        """获取融合日志"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        cursor.execute('''
            SELECT timestamp, action, details FROM fusion_log 
            ORDER BY id DESC LIMIT ?
        ''', (limit,))
        rows = cursor.fetchall()
        conn.close()
        
        return [
            {"timestamp": r[0], "action": r[1], "details": json.loads(r[2])}
            for r in rows
        ]
    
    # ==================== 统计接口 ====================
    
    def get_stats(self) -> Dict:
        """获取融合统计"""
        conn = sqlite3.connect(self.decision_db)
        cursor = conn.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM decisions")
        decision_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM unified_memory")
        memory_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM fusion_log")
        fusion_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT source, COUNT(*) as cnt FROM unified_memory GROUP BY source")
        by_source = {r[0]: r[1] for r in cursor.fetchall()}
        
        cursor.execute("SELECT category, COUNT(*) as cnt FROM unified_memory GROUP BY category")
        by_category = {r[0]: r[1] for r in cursor.fetchall()}
        
        conn.close()
        
        return {
            "decisions": decision_count,
            "memory_entries": memory_count,
            "fusion_logs": fusion_count,
            "memory_by_source": by_source,
            "memory_by_category": by_category
        }


# ==================== 主程序 ====================

if __name__ == "__main__":
    memory = UnifiedMemory()
    
    print("=" * 60)
    print("🧠 统一记忆层 v1.0 已初始化")
    print("=" * 60)
    
    # 测试写入
    print("\n📝 测试写入...")
    result = memory.save(
        key="test_fusion_key",
        value={"message": "融合测试成功", "timestamp": datetime.now().isoformat()},
        source="fusion",
        category="test"
    )
    print(f"   {result}")
    
    # 测试读取
    print("\n📖 测试读取...")
    result = memory.get("test_fusion_key")
    print(f"   {json.dumps(result, ensure_ascii=False, indent=2)}")
    
    # 测试搜索
    print("\n🔍 测试搜索...")
    results = memory.search("融合", limit=5)
    print(f"   找到 {len(results)} 条记录")
    
    # 统计
    print("\n📊 融合统计...")
    stats = memory.get_stats()
    print(json.dumps(stats, indent=2, ensure_ascii=False))
    
    # 系统状态
    print("\n🔧 系统状态...")
    state = memory.get_system_state()
    print(f"   daemon: {'✅' if state['components']['daemon'] else '❌'}")
    print(f"   CycleSystem: {'✅' if state['components']['cycle_system'] else '❌'}")
    print(f"   决策记录: {state['memory']['total_decisions']} 条")
    print(f"   记忆条目: {state['memory']['total_memory_entries']} 条")
    
    print("\n✅ 统一记忆层就绪")
