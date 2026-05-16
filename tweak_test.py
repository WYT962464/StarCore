import socket, json, sys
s = socket.socket()
s.settimeout(5)
s.connect(('127.0.0.1', 6000))
msg = json.dumps({"action": "diagnose", "id": 1}) + "\n"
s.send(msg.encode())
data = b""
while True:
    try:
        chunk = s.recv(4096)
        if not chunk: break
        data += chunk
    except: break
s.close()
print(data.decode())
