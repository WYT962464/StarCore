import urllib.request, json, ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
payload = json.dumps({"model":"ep-20260510055844-7bsvl","messages":[{"role":"user","content":"hi"}],"max_tokens":50}).encode()
req = urllib.request.Request("https://ark.cn-beijing.volces.com/api/v3/chat/completions", data=payload, headers={"Content-Type":"application/json","Authorization":"Bearer ark-5db3deab-6e44-46f5-ad83-95877754bc4d-27897"})
try:
    resp = urllib.request.urlopen(req, timeout=15, context=ctx)
    print(resp.read().decode()[:500])
except Exception as e:
    print(f"ERROR: {e}")
