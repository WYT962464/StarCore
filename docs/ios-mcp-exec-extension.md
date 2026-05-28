# iOS MCP Exec 工具扩展

## 概述

为 iOS MCP 添加 `exec` 工具，实现远程命令执行能力。

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    iOS MCP + Exec 扩展                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  StarCore App ──▶ iOS MCP (localhost:8090) ──▶ SSH 隧道 ──▶ iPhone │
│                                                                 │
│  工具调用流程：                                                  │
│  1. App 调用 iOS MCP exec 工具                                   │
│  2. iOS MCP 通过 SSH 隧道转发命令到 iPhone                        │
│  3. iPhone 执行命令并返回结果                                    │
│  4. iOS MCP 将结果返回给 App                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 工具定义

```json
{
  "name": "exec",
  "description": "在 iPhone 上执行 shell 命令",
  "inputSchema": {
    "type": "object",
    "properties": {
      "command": {
        "type": "string",
        "description": "要执行的 shell 命令"
      },
      "timeout": {
        "type": "integer",
        "description": "超时时间（秒）",
        "default": 30
      }
    },
    "required": ["command"]
  }
}
```

## 使用示例

```swift
// iOS MCP 工具调用
let result = try await iosMCP.callTool(
    name: "exec",
    arguments: [
        "command": "ls -la",
        "timeout": 30
    ]
)

print(result)
// 输出:
// {
//   "success": true,
//   "stdout": "total 12\ndrwxr-xr-x  3 mobile  102 May 29 04:00 .\n...",
//   "stderr": "",
//   "returncode": 0
// }
```

## 实现方式

### 方式 1: 服务器端 exec 服务（推荐）

使用 `exec_server.py` 作为中间层：

```python
# App 调用
POST http://localhost:8080/api/exec
{
  "command": "ls -la"
}

# 服务器通过 SSH 隧道执行
ssh -p 8028 mobile@localhost "ls -la"
```

### 方式 2: iOS MCP 原生扩展

修改 iOS MCP 源码，添加 exec 工具：

```python
# ios_mcp/tools/exec.py
async def exec_command(command: str) -> dict:
    """执行 iPhone 上的命令"""
    # 通过 SSH 隧道执行
    result = await ssh_tunnel.execute(command)
    return {
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode
    }

# 注册工具
mcp_server.add_tool("exec", exec_command)
```

## 安全性

1. **命令白名单**：限制可执行的命令范围
2. **超时控制**：防止命令无限期运行
3. **输出限制**：限制返回输出大小
4. **权限检查**：验证执行权限

## 下一步

1. 启动 exec_server.py
2. 测试 exec 工具
3. 集成到 TerminalManager
