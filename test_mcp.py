import json,urllib.request

def mcp_call(method, params={}):
    req = urllib.request.Request("http://127.0.0.1:8090/mcp",
        data=json.dumps({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":method,"arguments":params}}).encode(),
        headers={"Content-Type":"application/json"})
    try:
        resp = urllib.request.urlopen(req, timeout=15)
        return json.loads(resp.read())
    except Exception as e:
        return {"error": str(e)}

def show(method, r):
    if "error" in r:
        print("FAIL %s: %s" % (method, str(r["error"])[:80]))
        return
    contents = r.get("result",{}).get("content",[])
    if not contents:
        print("OK   %s: (empty)" % method)
        return
    c = contents[0]
    if c.get("type") == "image":
        print("OK   %s: image/jpeg %dB" % (method, len(c.get("data",""))))
    else:
        txt = c.get("text","")[:120]
        err = c.get("isError", False)
        print("%s %s: %s" % ("FAIL" if err else "OK  ", method, txt))

show("get_device_info", mcp_call("get_device_info"))
show("get_screen_info", mcp_call("get_screen_info"))
show("get_frontmost_app", mcp_call("get_frontmost_app"))
show("list_running_apps", mcp_call("list_running_apps"))
show("get_brightness", mcp_call("get_brightness"))
show("get_volume", mcp_call("get_volume"))
show("get_clipboard", mcp_call("get_clipboard"))
show("screenshot", mcp_call("screenshot", {"debug": True}))
show("tap_screen", mcp_call("tap_screen", {"x": 187, "y": 406}))
show("input_text", mcp_call("input_text", {"text": "test"}))
show("run_command", mcp_call("run_command", {"command": "echo hello_mcp"}))
show("launch_app", mcp_call("launch_app", {"bundle_id": "com.apple.MobileSMS"}))
show("get_ui_elements", mcp_call("get_ui_elements"))

print("\n=== ALL TESTS DONE ===")
