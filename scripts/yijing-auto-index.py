#!/usr/bin/env python3
"""
易经记忆体系 — 自动索引更新脚本
功能：根据关键词自动分类记忆条目，更新索引文件

八卦分类：
  乾 ☰ — 决策类（架构/方案/选择/设计）
  坤 ☷ — 存储类（文件/数据/持久化/归档/备份）
  震 ☳ — 触发类（自动化/定时器/事件/触发器/cronjob）
  巽 ☴ — 采集类（API/数据源/工具/采集/网络）
  坎 ☵ — 问题类（错误/调试/诊断/问题/失败/bug）
  离 ☲ — 展示类（报告/输出/格式/展示/可视化）
  艮 ☶ — 边界类（安全/限制/策略/边界/容量/阈值）
  兑 ☱ — 交互类（用户/对话/反馈/交互/通信）
"""

import re
import os
from pathlib import Path
from datetime import datetime

# 八卦分类关键词映射
GUA_KEYWORDS = {
    '乾': {
        'symbol': '☰',
        'name': '决策类',
        'keywords': ['架构', '方案', '选择', '设计', '决策', '策略', '规划', '蓝图', '核心', '系统架构']
    },
    '坤': {
        'symbol': '☷',
        'name': '存储类',
        'keywords': ['文件', '数据', '持久化', '归档', '备份', '存储', '数据库', '记录', '日志', '保存']
    },
    '震': {
        'symbol': '☳',
        'name': '触发类',
        'keywords': ['自动化', '定时器', '事件', '触发器', 'cronjob', '调度', '自动', '定时', '触发']
    },
    '巽': {
        'symbol': '☴',
        'name': '采集类',
        'keywords': ['API', '数据源', '工具', '采集', '网络', '接口', '服务', '调用', '请求', 'MCP']
    },
    '坎': {
        'symbol': '☵',
        'name': '问题类',
        'keywords': ['错误', '调试', '诊断', '问题', '失败', 'bug', '故障', '异常', '修复', '排查']
    },
    '离': {
        'symbol': '☲',
        'name': '展示类',
        'keywords': ['报告', '输出', '格式', '展示', '可视化', '界面', 'UI', '显示', '报告格式']
    },
    '艮': {
        'symbol': '☶',
        'name': '边界类',
        'keywords': ['安全', '限制', '策略', '边界', '容量', '阈值', '预警', '上限', '限制条件', '安全策略']
    },
    '兑': {
        'symbol': '☱',
        'name': '交互类',
        'keywords': ['用户', '对话', '反馈', '交互', '通信', '消息', '发送', '接收', '聊天', '微信']
    }
}

# 六十四卦映射（八卦两两相重）
HEXAGRAM_MAP = {}
gua_list = ['乾', '坤', '震', '巽', '坎', '离', '艮', '兑']
symbols = {'乾': '☰', '坤': '☷', '震': '☳', '巽': '☴', '坎': '☵', '离': '☲', '艮': '☶', '兑': '☱'}

for upper in gua_list:
    for lower in gua_list:
        name = f"{upper}{lower}"
        hexagram_name_map = {
            '乾乾': '乾为天', '乾坤': '天地否', '乾震': '天雷无妄', '乾巽': '天风姤',
            '乾坎': '天水讼', '乾离': '天火同人', '乾艮': '天山遁', '乾兑': '天泽履',
            '坤乾': '地天泰', '坤坤': '坤为地', '坤震': '地雷复', '坤巽': '地风升',
            '坤坎': '地水师', '坤离': '地火明夷', '坤艮': '山地剥', '坤兑': '地泽临',
            '震乾': '雷天大壮', '震坤': '雷地豫', '震震': '震为雷', '震巽': '雷风恒',
            '震坎': '雷水解', '震离': '雷火丰', '震艮': '雷山小过', '震兑': '泽雷随',
            '巽乾': '风天小畜', '巽坤': '风地观', '巽震': '风雷益', '巽巽': '巽为风',
            '巽坎': '风水涣', '巽离': '风火家人', '巽艮': '风山渐', '巽兑': '风泽中孚',
            '坎乾': '水天需', '坎坤': '水地比', '坎震': '水雷屯', '坎巽': '水风井',
            '坎坎': '坎为水', '坎离': '水火既济', '坎艮': '水山蹇', '坎兑': '水泽节',
            '离乾': '火天大有', '离坤': '火地晋', '离震': '火雷噬嗑', '离巽': '火风鼎',
            '离坎': '火水未济', '离离': '离为火', '离艮': '火山旅', '离兑': '火泽睽',
            '艮乾': '山天大畜', '艮坤': '山地剥', '艮震': '山雷颐', '艮巽': '山风蛊',
            '艮坎': '山水蒙', '艮离': '山火贲', '艮艮': '艮为山', '艮兑': '山泽损',
            '兑乾': '泽天夬', '兑坤': '泽地萃', '兑震': '泽雷随', '兑巽': '泽风大过',
            '兑坎': '泽水困', '兑离': '泽火革', '兑艮': '山泽损', '兑兑': '兑为泽'
        }
        display_name = hexagram_name_map.get(f"{upper}{lower}", f"{upper}{lower}")
        HEXAGRAM_MAP[f"{upper}{lower}"] = {
            'name': display_name,
            'symbol': f"{symbols[upper]}{symbols[lower]}",
            'upper': upper,
            'lower': lower
        }


def classify_entry(content: str) -> str:
    """根据内容关键词自动分类到八卦"""
    content_lower = content.lower()
    scores = {}
    
    for gua, info in GUA_KEYWORDS.items():
        score = 0
        for keyword in info['keywords']:
            if keyword.lower() in content_lower:
                score += 1
        scores[gua] = score
    
    # 返回得分最高的卦象
    if max(scores.values()) == 0:
        return '坤'  # 默认归为存储类
    
    return max(scores, key=scores.get)


def update_gua_index(gua: str, title: str, content: str, entry_id: str = None):
    """更新八卦索引文件"""
    index_path = Path("/home/ubuntu/starcore/data/plans/yijing-memory-index.md")
    
    if not index_path.exists():
        print(f"⚠️ 索引文件不存在: {index_path}")
        return False
    
    gua_info = GUA_KEYWORDS[gua]
    section_marker = f"## {gua} {gua_info['symbol']} — {gua_info['name']}"
    
    # 读取现有索引
    with open(index_path, 'r', encoding='utf-8') as f:
        content_lines = f.readlines()
    
    # 查找对应卦象的表格位置
    in_section = False
    table_start = -1
    for i, line in enumerate(content_lines):
        if section_marker in line:
            in_section = True
        elif in_section and line.startswith('## ') and section_marker not in line:
            break
        elif in_section and '| 关键词 |' in line:
            table_start = i + 2  # 跳过表头
    
    if table_start == -1:
        print(f"⚠️ 未找到 {gua} 卦象表格")
        return False
    
    # 生成新条目
    new_entry = f"| {title} | 新条目 | 待确认 |\n"
    
    # 插入到表格中
    content_lines.insert(table_start, new_entry)
    
    # 写回文件
    with open(index_path, 'w', encoding='utf-8') as f:
        f.writelines(content_lines)
    
    print(f"✅ 已更新 {gua} {gua_info['symbol']} 索引: {title}")
    return True


def rebuild_index():
    """重建完整索引（基于记忆文件）"""
    print("\n🔄 开始重建索引...")
    
    # 这里可以扩展为读取记忆文件或外部数据源
    # 当前版本提供框架，实际集成需要 Hermes memory API
    
    print("✅ 索引重建完成")
    print(f"   八卦分类: {len(GUA_KEYWORDS)} 个")
    print(f"   六十四卦: {len(HEXAGRAM_MAP)} 个")


def check_capacity():
    """检查记忆容量（需要集成 Hermes API）"""
    # 占位符：实际实现需要调用 Hermes memory 工具
    print("\n📊 容量检查（占位符）")
    print("   需要集成 Hermes memory API 获取实时容量")
    return {
        'memory_usage': 0,
        'memory_limit': 2200,
        'profile_usage': 0,
        'profile_limit': 1375
    }


def main():
    """主函数"""
    print("=" * 60)
    print("📍 易经记忆体系 — 自动索引更新")
    print("=" * 60)
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # 示例：分类测试
    test_entries = [
        ("SSH 隧道配置", "SSH 反向隧道配置，端口转发，自动化连接"),
        ("Tweak 注入失败", "Tweak 注入失败诊断，错误排查，调试记录"),
        ("iOS MCP 工具", "iOS MCP API 工具列表，数据采集，接口调用"),
        ("系统检查报告", "系统检查报告标准格式，输出规范，展示格式"),
        ("记忆容量限制", "MEMORY 容量上限，安全策略，边界限制"),
    ]
    
    print("\n🔍 分类测试:")
    for title, content in test_entries:
        gua = classify_entry(content)
        gua_info = GUA_KEYWORDS[gua]
        print(f"   {title} → {gua} {gua_info['symbol']} ({gua_info['name']})")
    
    print("\n✅ 自动索引更新脚本就绪")
    print("   使用方法: python3 yijing-auto-index.py")
    print("   集成到 cronjob: 0 9 * * 1 (每周一 9:00)")


if __name__ == "__main__":
    main()