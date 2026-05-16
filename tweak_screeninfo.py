import socket, json
s = socket.socket()
s.settimeout(5)
s.connect(('127.0.0.1', 6000))
msg = json.dumps({"action": "getScreenInfo", "id": 3}) + "\n"
s.send(msg.encode())
data = b""
while True:
    try:
        chunk = s.recv(4096)
        if not chunk: break
        data += chunk
        if b'\n' in data: break
    except: break
s.close()
print(data.decode().strip())
