/**
 * StarCoreTweak Bridge Protocol v3.0
 * 
 * TCP Server: 127.0.0.1:6000 (JSON over TCP, \n delimited)
 * Injection Target: backboardd (v3.0)
 * 
 * 坐标系统：归一化坐标 0.0-1.0
 * - 传入逻辑像素(x>1)会自动转换
 * - 推荐直接传归一化坐标
 * 
 * 支持的action：
 * 
 * 1. ping - 心跳检测
 *    请求: {"action":"ping","id":1}
 *    响应: {"success":true,"message":"pong","id":1}
 * 
 * 2. tap - 点击
 *    请求: {"action":"tap","x":0.5,"y":0.5,"id":2}
 *    响应: {"success":true,"id":2}
 *    注意: x,y可以是归一化(0-1)或逻辑像素(>1自动转换)
 * 
 * 3. swipe - 滑动
 *    请求: {"action":"swipe","fromX":0.5,"fromY":0.8,"toX":0.5,"toY":0.2,"duration":0.5,"id":3}
 *    响应: {"success":true,"id":3}
 * 
 * 4. longPress - 长按
 *    请求: {"action":"longPress","x":0.5,"y":0.5,"duration":1.0,"id":4}
 *    响应: {"success":true,"id":4}
 * 
 * 5. pressHome - Home键
 *    请求: {"action":"pressHome","id":5}
 *    响应: {"success":true,"id":5}
 * 
 * 6. getScreenSize - 获取屏幕尺寸
 *    请求: {"action":"getScreenSize","id":6}
 *    响应: {"success":true,"width":375,"height":812,"scale":3,"physicalWidth":1125,"physicalHeight":2436,"id":6}
 * 
 * 7. diagnose - 诊断检查
 *    请求: {"action":"diagnose","id":7}
 *    响应: {"success":true,"diagnostics":{...},"id":7}
 * 
 * v3.0变更：
 * - 注入目标从SpringBoard改为backboardd
 * - 坐标系统改为归一化(0.0-1.0)
 * - 新增diagnose诊断接口
 * - Home键改用HID键盘事件
 * - openApp/getCurrentApp在backboardd中不可用
 */
