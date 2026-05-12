"""星核中继服务器 - 云电脑端
iPhone轮询这个服务器获取命令，执行后回传结果
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, threading, time

# 命令队列
pending = []       # 待执行命令
results = {}       # 命令ID -> 结果
cmd_id = 0
lock = threading.Lock()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        """iPhone轮询：获取待执行命令"""
        with lock:
            cmds = pending.copy()
            pending.clear()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({"commands": cmds}).encode())

    def do_POST(self):
        global cmd_id
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)
        
        if self.path == '/result':
            """iPhone回传执行结果"""
            data = json.loads(body)
            with lock:
                results[data.get('id', 0)] = data
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')
            
        elif self.path == '/command':
            """星核下发命令"""
            data = json.loads(body)
            with lock:
                cmd_id += 1
                data['id'] = cmd_id
                pending.append(data)
                rid = cmd_id
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps({"id": rid}).encode())
            
        elif self.path == '/check':
            """星核查看命令结果"""
            data = json.loads(body) if body else {}
            cid = data.get('id', 0)
            with lock:
                result = results.pop(cid, {"id": cid, "status": "pending"})
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        print(f"[{time.strftime('%H:%M:%S')}] {args[0]}")

# 启动cloudflared tunnel
import subprocess, os
print("启动中继服务器...")
# 先启动cloudflared
proc = subprocess.Popen(
    ['cloudflared', 'tunnel', '--url', 'http://localhost:9876'],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT
)
# 等待获取tunnel URL
tunnel_url = None
for line in iter(proc.stdout.readline, b''):
    line = line.decode()
    if 'trycloudflare.com' in line:
        parts = line.split('|')
        for p in parts:
            if 'https://' in p and 'trycloudflare.com' in p:
                tunnel_url = p.strip()
                break
        if tunnel_url:
            break
    if 'Registered tunnel connection' in line:
        break

if tunnel_url:
    print(f"Tunnel URL: {tunnel_url}")
else:
    print("等待tunnel...")
    # 再等一会
    for line in iter(proc.stdout.readline, b''):
        line = line.decode()
        if 'trycloudflare.com' in line:
            for p in line.split('|'):
                if 'https://' in p and 'trycloudflare.com' in p:
                    tunnel_url = p.strip()
                    break
            if tunnel_url:
                break

# 把URL写到文件
if tunnel_url:
    with open('/app/data/所有对话/主对话/StarCore/tunnel_url.txt', 'w') as f:
        f.write(tunnel_url)
    print(f"Tunnel已就绪: {tunnel_url}")

server = HTTPServer(('0.0.0.0', 9876), Handler)
print("中继服务器运行在 :9876")
server.serve_forever()
