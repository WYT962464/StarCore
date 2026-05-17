import websocket, json, ssl, time, urllib.request, sys

# iOS MCP本地调用
def ios_mcp_call(method, params={}):
    req = urllib.request.Request("http://127.0.0.1:8090/mcp",
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":method,"arguments":params}}).encode(),
        headers={"Content-Type":"application/json"})
    resp = urllib.request.urlopen(req, timeout=30)
    return json.loads(resp.read())

# 获取iOS MCP工具列表
req = urllib.request.Request("http://127.0.0.1:8090/mcp",
    data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}).encode(),
    headers={"Content-Type":"application/json"})
resp = urllib.request.urlopen(req, timeout=10)
ios_tools = json.loads(resp.read()).get("result",{}).get("tools",[])
print(f"iOS MCP tools: {len(ios_tools)}")

# 连接小智
token = "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOjg5NDI3OCwiYWdlbnRJZCI6MTY5MTc5MiwiZW5kcG9pbnRJZCI6ImFnZW50XzE2OTE3OTIiLCJwdXJwb3NlIjoibWNwLWVuZHBvaW50IiwiaWF0IjoxNzc4OTYzMDc1LCJleHAiOjE4MTA1MjA2NzV9.QGz-9PZjzJRYWxg6YSZma-ztXgSRkz2Ymbcy4CLDL0dXpTAGt_PHJ0iM2ybNNF_F7qNHyu2u6t6VyZfHK1xbAw"
url = f"wss://api.xiaozhi.me/mcp/?token={token}"

ws = websocket.create_connection(url, timeout=30, sslopt={"cert_reqs": ssl.CERT_NONE})
ws.settimeout(300)

# 收小智init
r1 = json.loads(ws.recv())
ws.send(json.dumps({
    "jsonrpc": "2.0", "id": r1.get("id", 0), "result": {
        "protocolVersion": "2024-11-05",
        "capabilities": {"tools": {"listChanged": False}},
        "serverInfo": {"name": "StarCore-iOS", "version": "1.0"}
    }
}))
print("Init done")

# 收initialized
ws.recv()

# 收tools/list
r2 = json.loads(ws.recv())
ws.send(json.dumps({"jsonrpc": "2.0", "id": r2["id"], "result": {"tools": ios_tools}}))
print(f"Registered {len(ios_tools)} tools to Xiaozhi")

# 等待调用
while True:
    try:
        msg = ws.recv()
        r = json.loads(msg)
        if r.get("method") == "tools/call":
            tn = r.get("params",{}).get("name","")
            ta = r.get("params",{}).get("arguments",{})
            cid = r.get("id")
            print(f"[Call] {tn}({json.dumps(ta,ensure_ascii=False)[:80]})")
            try:
                result = ios_mcp_call(tn, ta)
                ws.send(json.dumps({"jsonrpc":"2.0","id":cid,"result":result.get("result",{})}))
                print("  OK")
            except Exception as e:
                ws.send(json.dumps({"jsonrpc":"2.0","id":cid,"result":{"content":[{"type":"text","text":str(e)}],"isError":True}}))
                print(f"  ERR: {e}")
        else:
            print(f"Msg: {r.get('method','?')}")
    except websocket._exceptions.WebSocketTimeoutException:
        print(".", end="", flush=True)
    except Exception as e:
        print(f"Disconnected: {e}")
        break
ws.close()
