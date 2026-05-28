#!/usr/bin/env python3
"""
易经记忆体系 — 定期维护脚本
功能：容量检查、自动清理、索引重建、归档管理

执行计划：
  • 每周检查容量（cronjob: 0 9 * * 1）
  • 80% 阈值触发清理
  • 索引自动重建
  • 已完成项目自动归档
"""

import os
import re
import shutil
from pathlib import Path
from datetime import datetime, timedelta

# 配置
MEMORY_LIMIT = 2200  # chars
PROFILE_LIMIT = 1375  # chars
WARNING_THRESHOLD = 0.80  # 80%
CRITICAL_THRESHOLD = 0.90  # 90%

ARCHIVE_DIR = Path("/home/ubuntu/.hermes/memory/archive")
PROJECTS_DIR = Path("/home/ubuntu/starcore/data/plans")
INDEX_DIR = Path("/home/ubuntu/starcore/data/plans")

# 临时/可清理文件模式
TEMP_PATTERNS = [
    ("prefix", "temp-"),
    ("prefix", "tmp-"),
    ("prefix", "draft-"),
    ("prefix", "backup-"),
    ("ext", ".bak"),
    ("prefix", "test-"),
    ("prefix", "debug-"),
    ("prefix", "log-"),
    ("prefix", "cache-")
]

# 核心保留文件（不可删除）
CORE_FILES = [
    "yijing-memory-system/SKILL.md",
    "yijing-memory-index.md",
    "64-hexagrams-work-mapping.md",
    "yijing-memory-supplement.md",
    "completed-projects.md"
]


def check_memory_capacity():
    """检查记忆容量（占位符，需集成 Hermes API）"""
    # 实际实现需要调用 Hermes memory 工具获取实时数据
    return {
        'memory_usage': 1829,  # 示例值
        'memory_limit': MEMORY_LIMIT,
        'memory_percent': 83,
        'profile_usage': 1141,
        'profile_limit': PROFILE_LIMIT,
        'profile_percent': 83
    }


def get_temp_files():
    """获取临时/可清理文件列表"""
    temp_files = []
    
    for pattern_type, pattern in TEMP_PATTERNS:
        if pattern_type == "prefix":
            # 前缀模式，如 temp-
            search_path = PROJECTS_DIR.glob(f"{pattern}*")
        elif pattern_type == "ext":
            # 扩展名模式，如 .bak
            search_path = PROJECTS_DIR.glob(f"*{pattern}")
        else:
            # 包含模式
            search_path = PROJECTS_DIR.glob(f"*{pattern}*")
        
        for f in search_path:
            if f.is_file() and not any(cf in str(f) for cf in CORE_FILES):
                temp_files.append(f)
    
    return list(set(temp_files))


def get_completed_projects():
    """获取已完成项目列表（占位符）"""
    # 实际实现需要扫描项目目录或读取状态文件
    completed = []
    
    # 示例：检查是否有完成标记
    for project_dir in PROJECTS_DIR.iterdir():
        if project_dir.is_dir():
            done_marker = project_dir / ".done"
            if done_marker.exists():
                completed.append(project_dir.name)
    
    return completed


def archive_project(project_name: str):
    """归档已完成项目"""
    project_path = PROJECTS_DIR / project_name
    archive_path = ARCHIVE_DIR / f"{project_name}-{datetime.now().strftime('%Y%m%d')}"
    
    if not project_path.exists():
        print(f"⚠️ 项目不存在: {project_path}")
        return False
    
    # 创建归档目录
    archive_path.mkdir(parents=True, exist_ok=True)
    
    # 复制文件
    for f in project_path.rglob('*'):
        if f.is_file():
            dest = archive_path / f.relative_to(project_path)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dest)
    
    print(f"✅ 已归档: {project_name} → {archive_path}")
    return True


def clean_temp_files():
    """清理临时文件"""
    temp_files = get_temp_files()
    cleaned = 0
    freed_space = 0
    
    for f in temp_files:
        try:
            size = f.stat().st_size
            f.unlink()
            cleaned += 1
            freed_space += size
            print(f"   🗑️ 已清理: {f.name} ({size} bytes)")
        except Exception as e:
            print(f"   ⚠️ 清理失败: {f.name} - {e}")
    
    print(f"\n✅ 清理完成: {cleaned} 个文件, 释放 {freed_space} bytes")
    return cleaned, freed_space


def rebuild_indexes():
    """重建所有索引文件"""
    print("\n🔄 重建索引...")
    
    # 调用自动索引脚本
    import subprocess
    result = subprocess.run(
        ['python3', '/home/ubuntu/starcore/scripts/yijing-auto-index.py'],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        print("✅ 索引重建成功")
    else:
        print(f"⚠️ 索引重建失败: {result.stderr}")
    
    return result.returncode == 0


def generate_report(capacity: dict, cleaned: int = 0, freed: int = 0):
    """生成维护报告"""
    report = f"""
# 易经记忆体系 — 维护报告

**时间**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## 容量状态

| 存储 | 使用 | 上限 | 百分比 | 状态 |
|------|------|------|--------|------|
| MEMORY | {capacity['memory_usage']} | {capacity['memory_limit']} | {capacity['memory_percent']}% | {'⚠️ 警告' if capacity['memory_percent'] >= 80 else '✅ 正常'} |
| USER PROFILE | {capacity['profile_usage']} | {capacity['profile_limit']} | {capacity['profile_percent']}% | {'⚠️ 警告' if capacity['profile_percent'] >= 80 else '✅ 正常'} |

## 清理结果

- 清理文件: {cleaned} 个
- 释放空间: {freed} bytes

## 建议

"""
    
    if capacity['memory_percent'] >= WARNING_THRESHOLD:
        report += """
⚠️ **容量警告**：MEMORY 使用率超过 80%

建议操作：
1. 清理临时记忆条目
2. 归档已完成项目
3. 压缩重复信息
"""
    
    if capacity['memory_percent'] >= CRITICAL_THRESHOLD:
        report += """
🚨 **容量临界**：MEMORY 使用率超过 90%

建议操作：
1. 立即清理临时条目
2. 紧急归档项目
3. 考虑扩容或迁移
"""
    
    if capacity['memory_percent'] < WARNING_THRESHOLD:
        report += """
✅ **状态良好**：容量在安全范围内

建议：
1. 继续定期维护
2. 保持索引更新
"""
    
    return report


def main():
    """主函数"""
    print("=" * 60)
    print("📍 易经记忆体系 — 定期维护")
    print("=" * 60)
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 1. 检查容量
    print("\n📊 检查容量...")
    capacity = check_memory_capacity()
    print(f"   MEMORY: {capacity['memory_usage']}/{capacity['memory_limit']} ({capacity['memory_percent']}%)")
    print(f"   PROFILE: {capacity['profile_usage']}/{capacity['profile_limit']} ({capacity['profile_percent']}%)")
    
    # 2. 检查是否需要清理
    cleaned = 0
    freed = 0
    
    if capacity['memory_percent'] >= WARNING_THRESHOLD:
        print("\n⚠️ 容量超过阈值，开始清理...")
        cleaned, freed = clean_temp_files()
    
    # 3. 归档已完成项目
    print("\n📦 检查已完成项目...")
    completed = get_completed_projects()
    for project in completed:
        archive_project(project)
    
    # 4. 重建索引
    rebuild_indexes()
    
    # 5. 生成报告
    report = generate_report(capacity, cleaned, freed)
    report_path = INDEX_DIR / f"maintenance-report-{datetime.now().strftime('%Y%m%d')}.md"
    
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write(report)
    
    print(f"\n📄 报告已保存: {report_path}")
    print("\n✅ 维护完成")


if __name__ == "__main__":
    main()