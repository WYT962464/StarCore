"""
离 ☲ 状态渲染器 (State Renderer)
==================================
八卦之六，明，代表输出与可视化能力。

功能：
- 系统状态渲染
- 可视化输出
- 状态快照生成
- 报告生成

卦象：离 ☲ (101) - 火，明
属性：明、光明、显示、呈现
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from enum import Enum
import threading


class RenderFormat(Enum):
    """渲染格式"""
    TEXT = "text"
    JSON = "json"
    TABLE = "table"
    CHART = "chart"
    REPORT = "report"


class StateCategory(Enum):
    """状态类别"""
    SYSTEM = "system"       # 系统状态
    GUA = "gua"             # 卦象状态
    DECISION = "decision"   # 决策状态
    PERFORMANCE = "performance"  # 性能状态
    ERROR = "error"         # 错误状态


@dataclass
class StateSnapshot:
    """状态快照"""
    id: str
    category: StateCategory
    timestamp: str
    data: Dict[str, Any]
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


@dataclass
class RenderOutput:
    """渲染输出"""
    format: RenderFormat
    content: str
    timestamp: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


class StateRenderer:
    """离状态渲染器"""
    
    def __init__(self, name: str = "LI"):
        self.name = name
        self.binary = "101"  # 离卦二进制
        
        # 存储路径
        self.base_path = Path("/home/ubuntu/starcore/data/bagua/li_renderer")
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.snapshot_path = self.base_path / "snapshots.jsonl"
        self.render_log_path = self.base_path / "render_log.jsonl"
        
        # 状态缓存
        self.state_cache: Dict[str, StateSnapshot] = {}
        self.cache_lock = threading.Lock()
        
        # 渲染模板
        self.templates: Dict[RenderFormat, Callable] = {}
        self._register_default_templates()
        
        # 统计
        self.render_count = 0
        self.snapshot_count = 0
    
    def _register_default_templates(self) -> None:
        """注册默认渲染模板"""
        self.templates[RenderFormat.TEXT] = self._render_text
        self.templates[RenderFormat.JSON] = self._render_json
        self.templates[RenderFormat.TABLE] = self._render_table
        self.templates[RenderFormat.REPORT] = self._render_report
    
    def render(self, state: Dict[str, Any], format: RenderFormat = RenderFormat.TEXT,
               category: StateCategory = StateCategory.SYSTEM) -> RenderOutput:
        """
        渲染状态
        
        Args:
            state: 状态数据
            format: 渲染格式
            category: 状态类别
            
        Returns:
            渲染输出
        """
        # 创建快照
        snapshot = self.create_snapshot(state, category)
        
        # 获取渲染器
        renderer = self.templates.get(format, self._render_text)
        
        # 渲染
        content = renderer(snapshot)
        
        # 创建输出
        output = RenderOutput(
            format=format,
            content=content,
            timestamp=datetime.now().isoformat(),
            metadata={"snapshot_id": snapshot.id}
        )
        
        self.render_count += 1
        
        # 记录日志
        self._log_render(output)
        
        return output
    
    def create_snapshot(self, state: Dict[str, Any], 
                       category: StateCategory) -> StateSnapshot:
        """创建状态快照"""
        snapshot_id = f"{category.value}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        snapshot = StateSnapshot(
            id=snapshot_id,
            category=category,
            timestamp=datetime.now().isoformat(),
            data=state,
            metadata={"renderer": self.name}
        )
        
        # 缓存
        with self.cache_lock:
            self.state_cache[snapshot_id] = snapshot
        
        self.snapshot_count += 1
        
        # 记录到文件
        self._save_snapshot(snapshot)
        
        return snapshot
    
    def get_snapshot(self, snapshot_id: str) -> Optional[StateSnapshot]:
        """获取快照"""
        with self.cache_lock:
            return self.state_cache.get(snapshot_id)
    
    def get_recent_snapshots(self, category: Optional[StateCategory] = None,
                            limit: int = 10) -> List[StateSnapshot]:
        """获取最近快照"""
        with self.cache_lock:
            snapshots = list(self.state_cache.values())
        
        if category:
            snapshots = [s for s in snapshots if s.category == category]
        
        snapshots.sort(key=lambda s: s.timestamp, reverse=True)
        return snapshots[:limit]
    
    def render_system_status(self, system_data: Dict[str, Any]) -> str:
        """渲染系统状态（便捷方法）"""
        return self.render(system_data, RenderFormat.TABLE, StateCategory.SYSTEM).content
    
    def render_gua_status(self, gua_data: Dict[str, Any]) -> str:
        """渲染卦象状态（便捷方法）"""
        return self.render(gua_data, RenderFormat.TEXT, StateCategory.GUA).content
    
    def render_decision(self, decision_data: Dict[str, Any]) -> str:
        """渲染决策（便捷方法）"""
        return self.render(decision_data, RenderFormat.TEXT, StateCategory.DECISION).content
    
    def generate_report(self, title: str, sections: List[Dict[str, Any]]) -> str:
        """生成报告"""
        report_data = {
            "title": title,
            "timestamp": datetime.now().isoformat(),
            "sections": sections,
            "renderer": self.name
        }
        
        return self._render_report(StateSnapshot(
            id=f"report_{datetime.now().strftime('%Y%m%d%H%M%S')}",
            category=StateCategory.PERFORMANCE,
            timestamp=datetime.now().isoformat(),
            data=report_data
        ))
    
    def _render_text(self, snapshot: StateSnapshot) -> str:
        """文本渲染"""
        lines = [
            f"{'=' * 60}",
            f"{snapshot.category.value.upper()} STATE SNAPSHOT",
            f"{'=' * 60}",
            f"ID: {snapshot.id}",
            f"Timestamp: {snapshot.timestamp}",
            f"",
            f"Data:",
        ]
        
        for key, value in snapshot.data.items():
            if isinstance(value, dict):
                lines.append(f"  {key}:")
                for k, v in value.items():
                    lines.append(f"    {k}: {v}")
            else:
                lines.append(f"  {key}: {value}")
        
        lines.append(f"")
        lines.append(f"{'=' * 60}")
        
        return "\n".join(lines)
    
    def _render_json(self, snapshot: StateSnapshot) -> str:
        """JSON 渲染"""
        return json.dumps(asdict(snapshot), default=str, indent=2, ensure_ascii=False)
    
    def _render_table(self, snapshot: StateSnapshot) -> str:
        """表格渲染"""
        lines = [
            f"┌{'─' * 58}┐",
            f"│ {snapshot.category.value.upper()} STATE SNAPSHOT".ljust(59) + "│",
            f"├{'─' * 58}┤",
            f"│ ID: {snapshot.id}".ljust(59) + "│",
            f"│ Timestamp: {snapshot.timestamp}".ljust(59) + "│",
            f"├{'─' * 58}┤",
        ]
        
        for key, value in snapshot.data.items():
            row = f"│ {key}: {str(value)[:45]}".ljust(59) + "│"
            lines.append(row)
        
        lines.append(f"└{'─' * 58}┘")
        
        return "\n".join(lines)
    
    def _render_report(self, snapshot: StateSnapshot) -> str:
        """报告渲染"""
        data = snapshot.data
        
        lines = [
            f"",
            f"{'=' * 60}",
            f"                    {data.get('title', 'REPORT')}",
            f"{'=' * 60}",
            f"",
            f"Generated: {data.get('timestamp', 'N/A')}",
            f"Renderer: {data.get('renderer', 'N/A')}",
            f"",
        ]
        
        for section in data.get("sections", []):
            lines.append(f"## {section.get('title', 'Section')}")
            lines.append(f"")
            
            if "content" in section:
                if isinstance(section["content"], list):
                    for item in section["content"]:
                        lines.append(f"  • {item}")
                else:
                    lines.append(f"  {section['content']}")
            
            if "metrics" in section:
                lines.append(f"  Metrics:")
                for metric, value in section["metrics"].items():
                    lines.append(f"    - {metric}: {value}")
            
            lines.append(f"")
        
        lines.append(f"{'=' * 60}")
        lines.append(f"                    END OF REPORT")
        lines.append(f"{'=' * 60}")
        lines.append(f"")
        
        return "\n".join(lines)
    
    def _save_snapshot(self, snapshot: StateSnapshot) -> None:
        """保存快照"""
        with open(self.snapshot_path, "a") as f:
            f.write(json.dumps(asdict(snapshot), default=str, ensure_ascii=False) + "\n")
    
    def _log_render(self, output: RenderOutput) -> None:
        """记录渲染日志"""
        log_entry = {
            "timestamp": output.timestamp,
            "format": output.format.value,
            "content_length": len(output.content),
            "snapshot_id": output.metadata.get("snapshot_id", "")
        }
        
        with open(self.render_log_path, "a") as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
    
    def get_status(self) -> Dict[str, Any]:
        """获取渲染器状态"""
        return {
            "name": self.name,
            "binary": self.binary,
            "render_count": self.render_count,
            "snapshot_count": self.snapshot_count,
            "cached_snapshots": len(self.state_cache),
            "available_formats": [f.value for f in RenderFormat]
        }


# 测试
if __name__ == "__main__":
    print("=" * 60)
    print("☲ 离状态渲染器 测试")
    print("=" * 60)
    
    renderer = StateRenderer()
    
    # 测试 1：渲染系统状态
    print("\n📝 测试 1：渲染系统状态（表格）")
    system_data = {
        "cpu_load": 0.45,
        "memory_usage": 0.62,
        "disk_usage": 0.38,
        "uptime": "2d 14h 32m",
        "status": "healthy"
    }
    output = renderer.render(system_data, RenderFormat.TABLE, StateCategory.SYSTEM)
    print(output.content)
    
    # 测试 2：渲染卦象状态
    print("\n📝 测试 2：渲染卦象状态（文本）")
    gua_data = {
        "current_gua": "QIAN",
        "binary": "111111",
        "cycle_count": 5,
        "evolution_level": 3
    }
    output = renderer.render(gua_data, RenderFormat.TEXT, StateCategory.GUA)
    print(output.content)
    
    # 测试 3：生成报告
    print("\n📝 测试 3：生成报告")
    sections = [
        {
            "title": "系统概览",
            "content": "系统运行正常，所有核心模块已加载",
            "metrics": {"uptime": "2d 14h", "status": "healthy"}
        },
        {
            "title": "性能指标",
            "content": [
                "CPU 使用率: 45%",
                "内存使用率: 62%",
                "磁盘使用率: 38%"
            ]
        },
        {
            "title": "卦象状态",
            "content": "当前卦象: QIAN (乾)",
            "metrics": {"cycle": 5, "level": 3}
        }
    ]
    report = renderer.generate_report("系统运行报告", sections)
    print(report)
    
    # 测试 4：获取状态
    print("\n📝 测试 4：获取渲染器状态")
    status = renderer.get_status()
    print(f"   渲染次数: {status['render_count']}")
    print(f"   快照数: {status['snapshot_count']}")
    
    print("\n✅ 离状态渲染器测试完成")
