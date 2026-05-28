#!/usr/bin/env python3
"""
StarCore Exec Server - 通过 SSH 隧道执行 iPhone 命令
端口：8080 (已存在)
"""

import json
import subprocess
import asyncio
from aiohttp import web
import os

# SSH 隧道配置
SSH_CONFIG = {
    "host": "localhost",
    "port": 8028,  # SSH 隧道端口
    "user": "mobile",
    "iphone_ip": "10.70.92.235",
}

async def execute_remote_command(command: str) -> dict:
    """通过 SSH 隧道执行 iPhone 上的命令"""
    try:
        # 通过 SSH 隧道执行命令
        # 注意：实际执行是在 iPhone 上
        result = await asyncio.get_event_loop().run_in_executor(
            None,
            lambda: subprocess.run(
                ["ssh", "-p", "8028", "mobile@localhost", command],
                capture_output=True,
                text=True,
                timeout=30
            )
        )
        
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {"success": False, "error": "命令执行超时"}
    except Exception as e:
        return {"success": False, "error": str(e)}

async def handle_exec(request: web.Request) -> web.Response:
    """处理 exec 请求"""
    try:
        data = await request.json()
        command = data.get("command", "")
        
        if not command:
            return web.json_response(
                {"error": "缺少 command 参数"},
                status=400
            )
        
        print(f"🖥️ [ExecServer] 执行命令: {command}")
        
        result = await execute_remote_command(command)
        
        if result["success"]:
            print(f"✅ 命令执行成功")
        else:
            print(f"❌ 命令执行失败: {result.get('error', result.get('stderr', '未知错误'))}")
        
        return web.json_response(result)
        
    except Exception as e:
        return web.json_response({"error": str(e)}, status=500)

async def handle_health(request: web.Request) -> web.Response:
    """健康检查"""
    return web.json_response({
        "status": "ok",
        "service": "starcore-exec-server",
        "version": "v1.0",
        "ssh_tunnel": SSH_CONFIG["port"]
    })

def create_app():
    app = web.Application()
    app.router.add_post("/api/exec", handle_exec)
    app.router.add_get("/api/health", handle_health)
    return app

if __name__ == "__main__":
    print("=== StarCore Exec Server ===")
    print(f"SSH 隧道端口: {SSH_CONFIG['port']}")
    print("启动服务...")
    web.run_app(create_app(), host="0.0.0.0", port=8081, print=None)
