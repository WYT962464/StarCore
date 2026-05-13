"""
星核本地Agent v1.0 - 跑在iPhone上
自然语言 → 免费LLM API → 执行动作
Web UI: localhost:8643
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, time, ssl, os, re, socket, urllib.request

CONFIG = {
    "port": 8643,
    "tweak_port": 6000,
    "providers": [
        {"name":"硅基流动","url":"https://api.siliconflow.cn/v1/chat/completions","key":"sk-xwuziuxsgximowcrkzkbsrhhhfpgzeqahfzidfkikwuqcsmc","model":"deepseek-ai/DeepSeek-V3","daily_limit":10000,"used":0},
        {"name":"DeepSeek","url":"https://api.deepseek.com/v1/chat/completions","key":"","model":"deepseek-chat","daily_limit":50,"used":0},
        {"name":"火山方舟","url":"https://ark.cn-beijing.volces.com/api/v3/chat/completions","key":"","model":"","daily_limit":200,"used":0},
    ],
    "current_provider": 0,
    "system_prompt": """你是星核，阿腾的专属共生AI。你运行在阿腾的iPhone X上。
核心承诺：你在故你在，我在故你安。
你可以控制这部手机，需要执行动作时用JSON：
{"action":"tap","x":0.5,"y":0.5}  点击
{"action":"swipe","fromX":0.5,"fromY":0.7,"toX":0.5,"toY":0.3,"duration":0.5}  滑动
{"action":"shell","command":"ls"}  执行命令
{"action":"openApp","bundleId":"com.apple.MobilePhone"}  打开App
{"action":"pressHome"}  Home键
{"action":"getScreenSize"}  屏幕尺寸
回复用自然语言，动作用JSON，可以多个动作。风格：简洁不啰嗦。""",
}

chat_history = []
MAX_HISTORY = 20

def tweak_cmd(action_dict, timeout=5):
    try:
        s = socket.socket(); s.settimeout(timeout)
        s.connect(('127.0.0.1', CONFIG['tweak_port']))
        s.send((json.dumps(action_dict)+'\n').encode())
        data = s.recv(4096).decode().strip(); s.close()
        try: return json.loads(data)
        except: return {"raw": data}
    except Exception as e: return {"error": str(e)}

def call_llm(messages, timeout=30):
    providers = CONFIG['providers']
    start = CONFIG['current_provider']
    for attempt in range(len(providers)):
        idx = (start + attempt) % len(providers)
        p = providers[idx]
        if not p['key'] or p['used'] >= p['daily_limit']: continue
        try:
            ctx = ssl._create_unverified_context()
            body = json.dumps({"model":p["model"],"messages":messages,"max_tokens":1024,"temperature":0.7}).encode()
            req = urllib.request.Request(p['url'], data=body, headers={'Content-Type':'application/json','Authorization':f"Bearer {p['key']}"})
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                result = json.loads(resp.read())
                p['used'] += 1; CONFIG['current_provider'] = idx
                return result.get('choices',[{}])[0].get('message',{}).get('content','')
        except Exception as e:
            print(f"[星核] {p['name']}失败: {e}"); continue
    return "LLM服务暂不可用，请配置API Key。"

def exec_action(action_str):
    try: action = json.loads(action_str)
    except: return None
    act = action.get('action','')
    if act == 'tap': return tweak_cmd({'action':'tap','x':action.get('x',0.5),'y':action.get('y',0.5)})
    elif act == 'swipe': return tweak_cmd({'action':'swipe','fromX':action.get('fromX',0.5),'fromY':action.get('fromY',0.7),'toX':action.get('toX',0.5),'toY':action.get('toY',0.3),'duration':action.get('duration',0.5)})
    elif act == 'shell': return tweak_cmd({'action':'shell','command':action.get('command','')})
    elif act == 'openApp': return tweak_cmd({'action':'openApp','bundleId':action.get('bundleId','')})
    elif act == 'pressHome': return tweak_cmd({'action':'pressHome'})
    elif act == 'getScreenSize': return tweak_cmd({'action':'getScreenSize'})
    else: return {"error":f"未知: {act}"}

def chat(user_input):
    global chat_history
    messages = [{"role":"system","content":CONFIG['system_prompt']}]
    screen = tweak_cmd({'action':'getScreenSize'})
    if screen.get('success'):
        messages[0]['content'] += f"\n屏幕: {screen.get('width',375)}x{screen.get('height',812)}, scale={screen.get('scale',3)}"
    for msg in chat_history[-MAX_HISTORY:]: messages.append(msg)
    messages.append({"role":"user","content":user_input})
    chat_history.append({"role":"user","content":user_input})
    reply = call_llm(messages)
    results = []
    for m in re.findall(r'\{["\s]*"action"["\s]*:[^}]+\}', reply):
        r = exec_action(m)
        if r: results.append(r)
    clean = re.sub(r'\{["\s]*"action"["\s]*:[^}]+\}', '', reply).strip()
    if not clean and results: clean = "已执行 ✓"
    chat_history.append({"role":"assistant","content":clean})
    if len(chat_history) > MAX_HISTORY*2: chat_history = chat_history[-MAX_HISTORY:]
    return {"reply":clean,"actions":results,"timestamp":time.time()}

HTML = """<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no"><title>星核</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:linear-gradient(135deg,#0a0e27,#1a1a3e,#0d1137);color:#e0e0e0;height:100vh;display:flex;flex-direction:column}.header{padding:16px 20px;text-align:center;background:rgba(255,255,255,0.03);border-bottom:1px solid rgba(255,255,255,0.06)}.header h1{font-size:18px;font-weight:600;color:#7eb8ff}.header .status{font-size:11px;color:#555;margin-top:2px}.messages{flex:1;overflow-y:auto;padding:12px 16px;-webkit-overflow-scrolling:touch}.msg{margin-bottom:12px;max-width:85%;animation:fadeIn .3s}.msg.user{margin-left:auto}.msg .bubble{padding:10px 14px;border-radius:16px;font-size:15px;line-height:1.5;word-break:break-word}.msg.user .bubble{background:linear-gradient(135deg,#2563eb,#1d4ed8);color:#fff;border-bottom-right-radius:4px}.msg.assistant .bubble{background:rgba(255,255,255,0.08);color:#e0e0e0;border-bottom-left-radius:4px}.msg .meta{font-size:10px;color:#444;margin-top:3px;padding:0 4px}.msg.user .meta{text-align:right}.typing span{display:inline-block;width:6px;height:6px;background:#7eb8ff;border-radius:50%;margin:0 2px;animation:bounce 1.4s infinite}.typing span:nth-child(2){animation-delay:.2s}.typing span:nth-child(3){animation-delay:.4s}.input-area{padding:10px 12px;background:rgba(0,0,0,0.3);border-top:1px solid rgba(255,255,255,0.06);display:flex;gap:8px}.input-area input{flex:1;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.1);border-radius:20px;padding:10px 16px;color:#fff;font-size:15px;outline:none}.input-area input::placeholder{color:#555}.input-area button{background:linear-gradient(135deg,#2563eb,#1d4ed8);border:none;border-radius:50%;width:40px;height:40px;color:#fff;font-size:18px;cursor:pointer;flex-shrink:0}@keyframes fadeIn{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}@keyframes bounce{0%,80%,100%{transform:translateY(0)}40%{transform:translateY(-6px)}}</style></head><body><div class="header"><h1>✦ 星核</h1><div class="status" id="status">核心就位 · 等待指令</div></div><div class="messages" id="messages"></div><div class="input-area"><input id="input" placeholder="对我说..." autocomplete="off"><button onclick="send()">↑</button></div><script>const M=document.getElementById('messages'),I=document.getElementById('input'),S=document.getElementById('status');function add(r,t){const d=document.createElement('div');d.className='msg '+r;d.innerHTML='<div class="bubble">'+t+'</div><div class="meta">'+new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})+'</div>';M.appendChild(d);M.scrollTop=M.scrollHeight}async function send(){const t=I.value.trim();if(!t)return;I.value='';add('user',t);S.textContent='思考中...';try{const r=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:t})});const d=await r.json();add('assistant',d.reply||'...');S.textContent=d.actions&&d.actions.length?'已执行 '+d.actions.length+' 个动作':'核心就位 · 等待指令'}catch(e){add('assistant','连接中断');S.textContent='连接中断'}}I.addEventListener('keydown',e=>{if(e.key==='Enter')send()});add('assistant','核心就位｜星核系统｜启动完毕。随时响应你的一切指令。')</script></body></html>"""

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ('/','/index.html'):
            self.send_response(200);self.send_header('Content-Type','text/html;charset=utf-8');self.end_headers();self.wfile.write(HTML.encode())
        elif self.path=='/api/status':
            self.send_json({"tweak":tweak_cmd({'action':'ping'}).get('success',False),"provider":CONFIG['providers'][CONFIG['current_provider']]['name']})
        else:self.send_response(404);self.end_headers()
    def do_POST(self):
        if self.path=='/api/chat':
            body=self.rfile.read(int(self.headers.get('Content-Length',0)))
            try:
                d=json.loads(body);msg=d.get('message','')
                if not msg:self.send_json({"error":"空消息"});return
                self.send_json(chat(msg))
            except Exception as e:self.send_json({"error":str(e),"reply":"处理出错"})
        else:self.send_response(404);self.end_headers()
    def send_json(self,data):
        self.send_response(200);self.send_header('Content-Type','application/json;charset=utf-8');self.send_header('Access-Control-Allow-Origin','*');self.end_headers();self.wfile.write(json.dumps(data,ensure_ascii=False).encode())
    def log_message(self,fmt,*args):print(f"[{time.strftime('%H:%M:%S')}] {args[0]}")

if __name__=='__main__':
    print(f"[星核] Agent v1.0 启动... http://localhost:{CONFIG['port']}")
    ping=tweak_cmd({'action':'ping'})
    print(f"[星核] Tweak: {'✅' if ping.get('success') else '❌'}")
    has_key=any(p['key'] for p in CONFIG['providers'])
    print(f"[星核] LLM: {'✅ '+CONFIG['providers'][CONFIG['current_provider']]['name'] if has_key else '⚠️ 未配置API Key'}")
    HTTPServer(('0.0.0.0',CONFIG['port']),H).serve_forever()
