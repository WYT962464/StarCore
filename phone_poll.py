"""星核手机端轮询脚本 - 跑在iPhone上
每3秒轮询中继服务器获取命令，执行后回传结果
"""
import json, subprocess, time, sys, os

# SSL跳过验证
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

# 中继服务器地址（cloudflare tunnel）
RELAY_URL = os.environ.get('RELAY_URL', 'https://xxxx.trycloudflare.com')
POLL_INTERVAL = 3  # 秒

def http_get(url, timeout=10):
    import urllib.request
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    except Exception as e:
        return None

def http_post(url, data, timeout=10):
    import urllib.request
    try:
        body = json.dumps(data).encode()
        req = urllib.request.Request(url, data=body, headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode()
    except Exception as e:
        return None

def execute_command(cmd):
    """执行shell命令并返回结果"""
    try:
        result = subprocess.run(
            cmd, shell=True, executable='/var/jb/bin/sh',
            capture_output=True, text=True, timeout=30
        )
        return {
            'stdout': result.stdout[:65536],
            'stderr': result.stderr[:65536],
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {'stdout': '', 'stderr': 'timeout (30s)', 'returncode': -1}
    except Exception as e:
        return {'stdout': '', 'stderr': str(e), 'returncode': -1}

def main():
    print(f"[StarCore-Poll] connected: {RELAY_URL}")
    sys.stdout.flush()
    
    while True:
        try:
            # 获取待执行命令
            resp = http_get(f'{RELAY_URL}/')
            if resp and resp.get('commands'):
                for cmd in resp['commands']:
                    cmd_id = cmd.get('id', 0)
                    action = cmd.get('action', '')
                    command = cmd.get('command', '')
                    
                    print(f"[StarCore-Poll] exec #{cmd_id}: {command or action}")
                    sys.stdout.flush()
                    
                    if action == 'shell' or command:
                        exec_result = execute_command(command)
                        result = {
                            'id': cmd_id,
                            'status': 'done',
                            'stdout': exec_result['stdout'],
                            'stderr': exec_result['stderr'],
                            'returncode': exec_result['returncode']
                        }
                    elif action == 'ping':
                        result = {'id': cmd_id, 'status': 'done', 'pong': True}
                    else:
                        result = {'id': cmd_id, 'status': 'error', 'error': f'unknown action: {action}'}
                    
                    # 回传结果
                    http_post(f'{RELAY_URL}/result', result)
                    print(f"[StarCore-Poll] done #{cmd_id}")
                    sys.stdout.flush()
        except Exception as e:
            print(f"[StarCore-Poll] err: {e}")
            sys.stdout.flush()
        
        time.sleep(POLL_INTERVAL)

if __name__ == '__main__':
    main()
