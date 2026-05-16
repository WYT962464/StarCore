import socket, json, base64, sys
s = socket.socket()
s.settimeout(10)
s.connect(('127.0.0.1', 6000))
msg = json.dumps({"action": "screenshot", "id": 2}) + "\n"
s.send(msg.encode())
data = b""
while True:
    try:
        chunk = s.recv(65536)
        if not chunk: break
        data += chunk
        if b'\n' in data: break
    except: break
s.close()
result = json.loads(data.decode().strip())
if result.get('success'):
    img_data = base64.b64decode(result['image'])
    with open('/var/mobile/StarCore/screenshot.jpg', 'wb') as f:
        f.write(img_data)
    print(f"截图成功! {len(img_data)} bytes, 保存到 /var/mobile/StarCore/screenshot.jpg")
else:
    print(f"截图失败: {result}")
