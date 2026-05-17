#!/usr/bin/env python3
"""
iOS远程大师 WebSocket中继服务器
iPhone App ←→ 此服务器 ←→ H5浏览器控制端
"""
import asyncio
import websockets
import json
import uuid
import time

# 设备连接和控制器连接
devices = {}  # socket_id -> websocket
controllers = {}  # socket_id -> websocket

RELAY_PORT = 9090

async def handle_device(websocket, path=None):
    """处理iPhone设备连接"""
    socket_id = str(uuid.uuid4())[:8]
    devices[socket_id] = websocket
    print(f"[{time.strftime('%H:%M:%S')}] 设备连接: {socket_id}")
    
    # 发送socket_id给设备
    try:
        await websocket.send(json.dumps({"type": "socket_id", "socket_id": socket_id}))
    except:
        pass
    
    try:
        async for message in websocket:
            # 转发设备消息给对应的控制器
            if socket_id in controllers:
                try:
                    await controllers[socket_id].send(message)
                except:
                    del controllers[socket_id]
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        print(f"[{time.strftime('%H:%M:%S')}] 设备断开: {socket_id}")
        if socket_id in devices:
            del devices[socket_id]
        if socket_id in controllers:
            del controllers[socket_id]

async def handle_controller(websocket, path=None):
    """处理H5控制器连接"""
    socket_id = None
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                if data.get("type") == "connect":
                    socket_id = data.get("socket_id")
                    if socket_id in devices:
                        controllers[socket_id] = websocket
                        print(f"[{time.strftime('%H:%M:%S')}] 控制器连接到设备: {socket_id}")
                        await websocket.send(json.dumps({"type": "connected", "socket_id": socket_id}))
                    else:
                        await websocket.send(json.dumps({"type": "error", "message": "设备不在线"}))
                elif socket_id and socket_id in devices:
                    # 转发控制器指令给设备
                    await devices[socket_id].send(message)
            except json.JSONDecodeError:
                # 二进制数据（截图等），直接转发
                if socket_id and socket_id in devices:
                    await devices[socket_id].send(message)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        if socket_id and socket_id in controllers:
            del controllers[socket_id]

async def main():
    print(f"iOS远程大师中继服务器启动在端口 {RELAY_PORT}")
    print(f"服务器地址: ws://115.190.107.107:{RELAY_PORT}")
    
    async with websockets.serve(handle_device, "0.0.0.0", RELAY_PORT):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
