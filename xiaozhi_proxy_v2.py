"""星核-小智MCP桥接 v2.1 - 自动token刷新
- 启动时从文件读token
- 每30s检查token文件是否变化，变化则自动重连
- 支持命令行参数或文件传入token
- 自动重连机制
"""
import websocket, json, ssl, time, urllib.request, sys, os, hashlib

LOG_FILE = "/var/mobile/StarCore/xiaozhi_proxy.log"
TOKEN_FILE = "/var/mobile/StarCore/xz_token.txt"
CHECK_INTERVAL = 30  # token文件检查间隔(秒)

def log(msg):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except:
        pass

def read_token():
    if os.path.isfile(TOKEN_FILE):
        with open(TOKEN_FILE) as f:
            return f.read().strip()
    if len(sys.argv) >= 2:
        arg = sys.argv[1]
        if os.path.isfile(arg):
            with open(arg) as f:
                return f.read().strip()
        return arg
    return None

def file_hash(path):
    try:
        with open(path, "rb") as f:
            return hashlib.md5(f.read()).hexdigest()
    except:
        return None

def ios_mcp_call(method, params={}):
    req = urllib.request.Request("http://127.0.0.1:8090/mcp",
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":method,"arguments":params}}).encode(),
        headers={"Content-Type":"application/json"})
    resp = urllib.request.urlopen(req, timeout=30)
    return json.loads(resp.read())

def get_ios_tools():
    req = urllib.request.Request("http://127.0.0.1:8090/mcp",
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}).encode(),
        headers={"Content-Type":"application/json"})
    resp = urllib.request.urlopen(req, timeout=10)
    return json.loads(resp.read()).get("result",{}).get("tools",[])

def run(token):
    url = f"wss://api.xiaozhi.me/mcp/?token={token}"
    log(f"Connecting (token={token[:15]}...)")
    
    try:
        ws = websocket.create_connection(url, timeout=30, sslopt={"cert_reqs": ssl.CERT_NONE})
        log(f"Connected! Status: {ws.status}")
    except Exception as e:
        log(f"Connect failed: {e}")
        return False
    
    ws.settimeout(60)  # 60s超时，方便定期检查token
    
    try:
        ios_tools = get_ios_tools()
        log(f"iOS MCP tools: {len(ios_tools)}")
    except Exception as e:
        log(f"Get tools failed: {e}")
        ws.close()
        return False
    
    try:
        r1 = json.loads(ws.recv())
        log(f"Init: {r1.get('params',{}).get('clientInfo',{})}")
        
        ws.send(json.dumps({
            "jsonrpc": "2.0", "id": r1.get("id", 0), "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "StarCore-iOS", "version": "2.1"}
            }
        }))
        
        ws.recv()  # initialized
        log("Initialized")
        
        r2 = json.loads(ws.recv())
        simplified_tools = []
        for t in ios_tools:
            simplified_tools.append({
                "name": t.get("name", ""),
                "description": t.get("description", "")[:200],
                "inputSchema": t.get("inputSchema", {"type":"object","properties":{}})
            })
        
        ws.send(json.dumps({"jsonrpc": "2.0", "id": r2["id"], "result": {"tools": simplified_tools}}))
        log(f"Registered {len(simplified_tools)} tools")
        
    except Exception as e:
        log(f"Handshake failed: {e}")
        ws.close()
        return False
    
    log("Ready!")
    last_hash = file_hash(TOKEN_FILE)
    
    while True:
        try:
            msg = ws.recv()
            if not msg:
                log("Empty msg, closed")
                break
            r = json.loads(msg)
            
            if r.get("method") == "tools/call":
                tn = r.get("params",{}).get("name","")
                ta = r.get("params",{}).get("arguments",{})
                cid = r.get("id")
                log(f"[Call] {tn}({json.dumps(ta,ensure_ascii=False)[:100]})")
                
                try:
                    result = ios_mcp_call(tn, ta)
                    resp_result = result.get("result", {})
                    ws.send(json.dumps({"jsonrpc":"2.0","id":cid,"result":resp_result}))
                    log(f"  OK")
                except Exception as e:
                    ws.send(json.dumps({"jsonrpc":"2.0","id":cid,"result":{
                        "content":[{"type":"text","text":str(e)}],"isError":True}}))
                    log(f"  ERR: {e}")
            elif r.get("method") == "ping":
                if r.get("id"):
                    ws.send(json.dumps({"jsonrpc":"2.0","id":r["id"],"result":{}}))
                log("ping/pong")
            else:
                log(f"Msg: {r.get('method','?')}")
                if r.get("id") and r.get("method"):
                    ws.send(json.dumps({"jsonrpc":"2.0","id":r["id"],"result":{}}))
                    
        except websocket._exceptions.WebSocketTimeoutException:
            # 超时，趁机检查token是否变了
            new_hash = file_hash(TOKEN_FILE)
            if new_hash and new_hash != last_hash:
                log("Token file changed! Reconnecting...")
                ws.close()
                return True  # True = 需要重连
            last_hash = new_hash
        except websocket._exceptions.WebSocketConnectionClosedException:
            log("Connection closed")
            break
        except Exception as e:
            log(f"Error: {type(e).__name__}: {e}")
            break
    
    ws.close()
    return False

if __name__ == "__main__":
    try: os.remove(LOG_FILE)
    except: pass
    
    log("StarCore-XiaoZhi MCP Bridge v2.1")
    
    token = read_token()
    if not token:
        print(f"No token! Write to {TOKEN_FILE} or pass as argument")
        sys.exit(1)
    
    # 写入token文件（如果是从参数传入的）
    if len(sys.argv) >= 2 and not os.path.isfile(sys.argv[1]):
        try:
            with open(TOKEN_FILE, "w") as f:
                f.write(token)
        except:
            pass
    
    log(f"Token: {token[:20]}... (len={len(token)})")
    
    while True:
        token = read_token() or token
        need_reconnect = run(token)
        if need_reconnect:
            log("Token updated, reconnecting immediately...")
            time.sleep(1)
        else:
            log("Disconnected, retry in 10s...")
            time.sleep(10)
