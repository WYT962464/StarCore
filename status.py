#!/usr/bin/env python3
"""
自循环状态查询工具
"""

import json
import sqlite3
import subprocess
from datetime import datetime

def get_self_cycle_status():
    """获取自循环状态"""
    
    print("=" * 60)
    print("🔄 星核自循环执行引擎状态")
    print("=" * 60)
    
    # 1. 自循环日志
    log_file = "/home/ubuntu/starcore/data/self_cycle_log.jsonl"
    try:
        with open(log_file) as f:
            lines = [json.loads(l) for l in f if l.strip()]
        
        print(f"\n📊 循环统计:")
        print(f"   总循环数: {len(lines)}")
        
        if lines:
            print(f"   第一轮: {lines[0]['timestamp']}")
            print(f"   最后一轮: {lines[-1]['timestamp']}")
            
            # 最近 5 轮
            print(f"\n📋 最近 5 轮:")
            for r in lines[-5:]:
                state = r.get('input_state', {})
                cs = state.get('cycle_system', {})
                dec = r.get('decision', {})
                ateng = r.get('ateng_calibration', {})
                
                status_icon = "✅" if r.get('execution_result', {}).get('success') else "❌"
                print(f"   #{r['cycle_id']:3d} | {r['timestamp'][-12:]} | {status_icon} | {dec.get('final_decision', 'N/A')[:20]}")
                if ateng:
                    print(f"        阿腾校准: {ateng.get('校准建议', '')[:40]}")
    except Exception as e:
        print(f"   ❌ 无法读取日志: {e}")
    
    # 2. 决策数据库
    print(f"\n📝 决策数据库:")
    try:
        conn = sqlite3.connect("/home/ubuntu/starcore/data/decisions.db")
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM decisions")
        count = cursor.fetchone()[0]
        print(f"   总记录数: {count}")
        
        cursor.execute("SELECT timestamp, final_decision, confidence FROM decisions ORDER BY id DESC LIMIT 3")
        print(f"   最近 3 条:")
        for row in cursor.fetchall():
            print(f"     {row[0][-12:]} | {row[1][:30]} | {row[2]:.2f}")
        conn.close()
    except Exception as e:
        print(f"   ❌ 无法查询数据库: {e}")
    
    # 3. 系统状态
    print(f"\n🔧 系统组件:")
    
    # daemon
    try:
        result = subprocess.run(
            ["curl", "-s", "--connect-timeout", "2", "http://localhost:9090/health"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            d = json.loads(result.stdout)
            print(f"   daemon: ✅ v{d.get('version', 'unknown')}")
        else:
            print(f"   daemon: ❌")
    except:
        print(f"   daemon: ❌")
    
    # CycleSystem
    try:
        result = subprocess.run(
            ["curl", "-s", "--connect-timeout", "2", "http://localhost:9092/state"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            d = json.loads(result.stdout)
            energy = d.get('energy', {}).get('cognitive', 0)
            entropy = d.get('entropy', {}).get('value', 0)
            icon = "✅" if energy > 30 else "⚠️"
            print(f"   CycleSystem: {icon} 卦象 {d.get('hexagram')}, 能量 {energy:.1f}%, 熵 {entropy:.2f}")
        else:
            print(f"   CycleSystem: ❌")
    except:
        print(f"   CycleSystem: ❌")
    
    # iOS Controller
    try:
        result = subprocess.run(
            ["curl", "-s", "--connect-timeout", "2", "http://localhost:9091/health"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            d = json.loads(result.stdout)
            print(f"   iOS Controller: ✅ v{d.get('version', 'unknown')}")
        else:
            print(f"   iOS Controller: ❌")
    except:
        print(f"   iOS Controller: ❌")
    
    # 4. 当前时间
    print(f"\n🕐 当前时间: {datetime.now().isoformat()}")
    
    print("\n" + "=" * 60)

if __name__ == "__main__":
    get_self_cycle_status()
