import socket,json,time
s=socket.socket()
s.settimeout(10)
s.connect(("127.0.0.1",6000))
t=time.time()
s.sendall(json.dumps({"action":"openApp","bundleId":"com.apple.MobileSMS"}).encode()+b"\n")
r=b""
while True:
    chunk=s.recv(65536)
    if not chunk: break
    r+=chunk
    if r.strip().endswith(b"}"): break
s.close()
d=json.loads(r.decode().strip())
print(f"time={time.time()-t:.1f}s")
print(f"success={d.get('success')}")
print(f"method={d.get('method','')}")
print(f"error={d.get('error','')}")
