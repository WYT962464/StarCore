#!/usr/bin/env python3
import re

# 读取原始文件
with open('StarCoreTweak/Tweak.xm', 'r') as f:
    content = f.read()

# 1. 修改文件头注释
content = content.replace('''/**
 * StarCoreTweak.xm v5.1 - 安全修复版
 * 
 * v5.0问题：IOHIDUserDeviceCreate在SpringBoard启动1秒后自动调用，导致SpringBoard崩溃（Safe Mode）
 * 
 * v5.1 安全修复：
 * 1. 禁用虚拟设备自动创建 - 用户需手动调用initDevice
 * 2. 修复HID Report打包问题 - 所有字段字节对齐
 * 3. keyPress功能独立可用 - 使用IOHIDEventSystemClient路径
 * 4. tap/swipe/longPress在虚拟设备不可用时回退到IOHIDEventSystemClient
 */''', '''/**
 * StarCoreTweak.xm v5.2 - 安全修复版
 * 
 * v5.1问题：keyPress命令通过IOHIDEventSystemClient分发Keyboard页面事件导致SpringBoard崩溃
 * 
 * v5.2 安全修复：
 * 1. 禁用keyPress通过IOHIDEventSystemClient - 会崩溃
 * 2. 创建虚拟键盘设备 - 通过IOHIDUserDevice发送键盘事件
 * 3. keyPress/textInput只在虚拟键盘设备就绪时工作
 * 4. pressHome保持不变 - Consumer页面事件安全
 * 5. initDevice返回更详细的状态信息
 */''')

# 2. 添加虚拟键盘设备全局变量
content = content.replace(
'''// ★ v5.1: 虚拟触摸设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";''',
'''// ★ v5.1: 虚拟触摸设备
static IOHIDUserDeviceRef g_virtualDevice = NULL;
static bool g_virtualDeviceReady = false;
static NSString *g_virtualDeviceError = @"";

// ★ v5.2: 虚拟键盘设备
static IOHIDUserDeviceRef g_virtualKeyboardDevice = NULL;
static bool g_virtualKeyboardReady = false;''')

# 3. 在触摸设备descriptor后添加键盘descriptor
content = content.replace(
'''    // Contact Count Maximum 作为 Feature Report 已移除（非必需）
    0xC0               // End Collection
};

// ==================== 前向声明 ====================''',
'''    // Contact Count Maximum 作为 Feature Report 已移除（非必需）
    0xC0               // End Collection
};

// ★ v5.2: 键盘HID Report Descriptor
// Keyboard Usage Page (0x07) - 标准101键键盘
// Report ID = 2
// 格式：Byte 0(Report ID) + Byte 1(Modifiers) + Byte 2(Reserved) + Bytes 3-8(KeyCodes)
static const uint8_t g_keyboard_descriptor[] = {
    0x05, 0x01,        // Usage Page (Generic Desktop)
    0x09, 0x06,        // Usage (Keyboard)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x02,        //   Report ID (2)
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0xE0,        //   Usage Minimum (224) - Left Control
    0x29, 0xE7,        //   Usage Maximum (231) - Right GUI
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x01,        //   Logical Maximum (1)
    0x75, 0x01,        //   Report Size (1)
    0x95, 0x08,        //   Report Count (8) - 8 modifier keys
    0x81, 0x02,        //   Input (Data, Variable, Absolute) - Modifier keys
    0x95, 0x01,        //   Report Count (1)
    0x75, 0x08,        //   Report Size (8)
    0x81, 0x01,        //   Input (Constant) - Reserved byte
    0x95, 0x06,        //   Report Count (6) - 6 key codes
    0x75, 0x08,        //   Report Size (8)
    0x15, 0x00,        //   Logical Minimum (0)
    0x25, 0x65,        //   Logical Maximum (101) - Keyboard a-z, 0-9, etc.
    0x05, 0x07,        //   Usage Page (Keyboard)
    0x19, 0x00,        //   Usage Minimum (0) - No Event
    0x29, 0x65,        //   Usage Maximum (101) - Keyboard Application
    0x81, 0x00,        //   Input (Data, Array) - Key codes
    0xC0               // End Collection
};

// ==================== 前向声明 ====================''')

# 4. 在v5.1 IOHIDUserDevice虚拟触摸设备前添加虚拟键盘设备函数
content = content.replace(
'''// ==================== v5.1: IOHIDUserDevice虚拟触摸设备 ====================

// 创建虚拟触摸设备''',
'''// ==================== v5.1: IOHIDUserDevice虚拟触摸设备 ====================

// ★ v5.2: 初始化虚拟键盘设备
static bool initVirtualKeyboardDevice() {
    if (g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] 虚拟键盘设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // 构建设备属性字典
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // Report Descriptor
    NSData *descriptorData = [NSData dataWithBytes:g_keyboard_descriptor length:sizeof(g_keyboard_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    
    // 设备信息
    properties[@"Product"] = @"StarCore Virtual Keyboard";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0002);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    
    // HID设备类型 - 键盘
    properties[@"PrimaryUsagePage"] = @(0x07);
    properties[@"PrimaryUsage"] = @(0x06);
    properties[@"DeviceUsagePage"] = @(0x01);
    properties[@"DeviceUsage"] = @(0x06);
    
    // 转为CFDictionary
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    
    // 创建虚拟键盘设备
    g_virtualKeyboardDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualKeyboardDevice) {
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate键盘设备失败");
        return false;
    }
    
    g_virtualKeyboardReady = true;
    NSLog(@"[StarCoreTweak] ✅ 虚拟键盘设备创建成功");
    
    return true;
}

// ★ v5.2: 发送键盘报告
// Report格式（9字节）：
// Byte 0: Report ID = 2
// Byte 1: Modifiers (bit flags)
// Byte 2: Reserved = 0
// Bytes 3-8: Key codes (最多6个同时按键)
static bool sendKeyboardReport(uint8_t modifiers, const uint8_t *keyCodes, int keyCodeCount) {
    if (!g_virtualKeyboardReady || !IOHIDUserDeviceHandleReportFunc) {
        return false;
    }
    
    uint8_t report[9] = {0};
    report[0] = 0x02;  // Report ID = 2
    report[1] = modifiers;
    report[2] = 0;  // Reserved
    
    // 填充key codes（最多6个）
    int count = (keyCodeCount > 6) ? 6 : keyCodeCount;
    for (int i = 0; i < count; i++) {
        report[3 + i] = keyCodes[i];
    }
    
    IOReturn result = IOHIDUserDeviceHandleReportFunc(g_virtualKeyboardDevice, report, sizeof(report));
    
    if (result != kIOReturnSuccess) {
        NSLog(@"[StarCoreTweak] ⚠️ 键盘HandleReport返回: 0x%x", result);
        return false;
    }
    
    return true;
}

// ★ v5.2: 通过虚拟键盘设备发送按键
static void handleKeyPressViaVirtualDevice(uint32_t page, uint32_t usage) {
    if (!g_virtualKeyboardReady) return;
    
    // key down - 发送usage code
    uint8_t keys[1] = { (uint8_t)usage };
    sendKeyboardReport(0, keys, 1);
    usleep(50000);
    
    // key up - 发送0表示无按键
    uint8_t noKeys[1] = { 0 };
    sendKeyboardReport(0, noKeys, 0);
    
    resetIdleTimer();
}

// 创建虚拟触摸设备''')

print("Phase 1-4 done, length:", len(content))

# 5. 修改initVirtualTouchDevice函数
content = content.replace(
'''// 创建虚拟触摸设备
static bool initVirtualTouchDevice() {
    if (g_virtualDeviceReady) {
        NSLog(@"[StarCoreTweak] 虚拟设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        g_virtualDeviceError = @"IOHIDUserDevice函数未加载";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // 构建设备属性字典
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // Report Descriptor (CFDataRef)
    NSData *descriptorData = [NSData dataWithBytes:g_multitouch_descriptor length:sizeof(g_multitouch_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    
    // 设备信息
    properties[@"Product"] = @"StarCore Virtual Touch";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0001);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    
    // HID设备类型 - 触摸屏
    properties[@"PrimaryUsagePage"] = @(0x0D);
    properties[@"PrimaryUsage"] = @(0x04);
    properties[@"DeviceUsagePage"] = @(0x0D);
    properties[@"DeviceUsage"] = @(0x04);
    
    // 转为CFDictionary
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    
    // 创建虚拟设备
    g_virtualDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualDevice) {
        g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate失败");
        return false;
    }
    
    g_virtualDeviceReady = true;
    g_virtualDeviceError = @"";
    NSLog(@"[StarCoreTweak] ✅ 虚拟触摸设备创建成功");
    
    return true;
}''',
'''// ★ v5.2: 创建虚拟触摸设备（并尝试创建键盘设备）
static bool initVirtualTouchDevice() {
    // 如果两个设备都已就绪，直接返回
    if (g_virtualDeviceReady && g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] 虚拟设备已就绪");
        return true;
    }
    
    if (!IOHIDUserDeviceCreateFunc || !IOHIDUserDeviceHandleReportFunc) {
        g_virtualDeviceError = @"IOHIDUserDevice函数未加载";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDevice函数未加载");
        return false;
    }
    
    // ★ v5.2: 先创建键盘设备（比触摸设备简单，优先创建）
    if (!g_virtualKeyboardReady) {
        initVirtualKeyboardDevice();
        // 键盘设备创建失败不阻止触摸设备创建
    }
    
    // 创建触摸设备
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    
    // Report Descriptor (CFDataRef)
    NSData *descriptorData = [NSData dataWithBytes:g_multitouch_descriptor length:sizeof(g_multitouch_descriptor)];
    properties[@"ReportDescriptor"] = descriptorData;
    
    // 设备信息
    properties[@"Product"] = @"StarCore Virtual Touch";
    properties[@"VendorID"] = @(0x05AC);
    properties[@"ProductID"] = @(0x0001);
    properties[@"Transport"] = @"Virtual";
    properties[@"VersionNumber"] = @(0x0100);
    
    // HID设备类型 - 触摸屏
    properties[@"PrimaryUsagePage"] = @(0x0D);
    properties[@"PrimaryUsage"] = @(0x04);
    properties[@"DeviceUsagePage"] = @(0x0D);
    properties[@"DeviceUsage"] = @(0x04);
    
    // 转为CFDictionary
    CFDictionaryRef cfProps = (__bridge CFDictionaryRef)properties;
    
    // 创建虚拟设备
    g_virtualDevice = IOHIDUserDeviceCreateFunc(kCFAllocatorDefault, cfProps, 0);
    
    if (!g_virtualDevice) {
        g_virtualDeviceError = @"IOHIDUserDeviceCreate返回NULL";
        NSLog(@"[StarCoreTweak] ❌ IOHIDUserDeviceCreate触摸设备失败");
        // 不返回false，让键盘设备继续工作
    } else {
        g_virtualDeviceReady = true;
        g_virtualDeviceError = @"";
        NSLog(@"[StarCoreTweak] ✅ 虚拟触摸设备创建成功");
    }
    
    // ★ v5.2: 返回任一设备就绪即可
    return g_virtualDeviceReady || g_virtualKeyboardReady;
}''')

print("Phase 5 done, length:", len(content))

# 6. 修改handleKeyPress和handleTextInput函数
content = content.replace(
'''// ★ v5.1: 键盘字符输入
static void handleKeyPress(NSString *key) {
    if (!loadFunctions() || !IOHIDEventCreateKeyboardEventFunc) {
        NSLog(@"[StarCoreTweak] ⚠️ 键盘函数未加载");
        return;
    }
    
    uint32_t page = 0, usage = 0;
    if (!keyToUsage(key, &page, &usage)) {
        NSLog(@"[StarCoreTweak] ⚠️ 无法映射键: %@", key);
        return;
    }
    
    uint64_t ts = mach_absolute_time();
    
    // key down
    IOHIDEventRef keyDown = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, ts, page, usage, true, 0);
    if (keyDown) {
        if (IOHIDEventSetSenderIDFunc) {
            IOHIDEventSetSenderIDFunc(keyDown, kIOHIDEventDigitizerSenderID);
        }
        dispatchHIDEvent(keyDown);
    }
    
    usleep(50000);
    
    // key up
    IOHIDEventRef keyUp = IOHIDEventCreateKeyboardEventFunc(
        kCFAllocatorDefault, ts, page, usage, false, 0);
    if (keyUp) {
        if (IOHIDEventSetSenderIDFunc) {
            IOHIDEventSetSenderIDFunc(keyUp, kIOHIDEventDigitizerSenderID);
        }
        dispatchHIDEvent(keyUp);
    }
    
    resetIdleTimer();
}

// ★ v5.1: 带文本输入的键盘输入
static void handleTextInput(NSString *text) {
    if (!text || text.length == 0) return;
    
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        NSString *charStr = [NSString stringWithCharacters:&c length:1];
        handleKeyPress(charStr);
        usleep(30000);
    }
}''',
'''// ★ v5.2: 键盘字符输入（只通过虚拟键盘设备，禁用IOHIDEventSystemClient）
static void handleKeyPress(NSString *key) {
    uint32_t page = 0, usage = 0;
    if (!keyToUsage(key, &page, &usage)) {
        NSLog(@"[StarCoreTweak] ⚠️ 无法映射键: %@", key);
        return;
    }
    
    // ★ v5.2: 只通过虚拟键盘设备发送
    if (g_virtualKeyboardReady) {
        handleKeyPressViaVirtualDevice(page, usage);
        return;
    }
    
    // ⚠️ 不再通过IOHIDEventSystemClient发送键盘事件（会崩溃）
    NSLog(@"[StarCoreTweak] ⚠️ 键盘输入需要虚拟键盘设备，请先调用initDevice");
}

// ★ v5.2: 带文本输入的键盘输入（通过虚拟键盘设备）
static void handleTextInput(NSString *text) {
    if (!text || text.length == 0) return;
    
    // ★ v5.2: 检查虚拟键盘设备就绪
    if (!g_virtualKeyboardReady) {
        NSLog(@"[StarCoreTweak] ⚠️ 文本输入需要虚拟键盘设备");
        return;
    }
    
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        NSString *charStr = [NSString stringWithCharacters:&c length:1];
        uint32_t page = 0, usage = 0;
        if (keyToUsage(charStr, &page, &usage)) {
            handleKeyPressViaVirtualDevice(page, usage);
        }
        usleep(30000);
    }
}''')

print("Phase 6 done, length:", len(content))

# 7. 修改TCP日志
content = content.replace(
    'NSLog(@"[StarCoreTweak] TCP :6000 v5.1 (IOHIDUserDevice + keyPress)");',
    'NSLog(@"[StarCoreTweak] TCP :6000 v5.2 (IOHIDUserDevice + virtual keyboard)");')

# 8. 修改keyPress命令处理
content = content.replace(
'''    // ★ v5.1: keyPress - 键盘字符输入
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"key required";
        } else {
            handleKeyPress(key);
            resp[@"success"]=@YES;
        }
    }
    
    // ★ v5.1: textInput - 文本输入
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"text required";
        } else {
            handleTextInput(text);
            resp[@"success"]=@YES;
        }
    }''',
'''    // ★ v5.2: keyPress - 键盘字符输入（需要虚拟键盘设备）
    else if([action isEqualToString:@"keyPress"]) {
        NSString *key = req[@"key"];
        if (!key || key.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"key required";
        } else if (!g_virtualKeyboardReady) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"virtual keyboard not ready, call initDevice first";
        } else {
            uint32_t page = 0, usage = 0;
            if (keyToUsage(key, &page, &usage)) {
                handleKeyPressViaVirtualDevice(page, usage);
                resp[@"success"]=@YES;
            } else {
                resp[@"success"]=@NO;
                resp[@"error"]=[NSString stringWithFormat:@"unknown key: %@", key];
            }
        }
    }
    
    // ★ v5.2: textInput - 文本输入（需要虚拟键盘设备）
    else if([action isEqualToString:@"textInput"]) {
        NSString *text = req[@"text"];
        if (!text || text.length == 0) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"text required";
        } else if (!g_virtualKeyboardReady) {
            resp[@"success"]=@NO;
            resp[@"error"]=@"virtual keyboard not ready, call initDevice first";
        } else {
            handleTextInput(text);
            resp[@"success"]=@YES;
        }
    }''')

print("Phase 7-8 done, length:", len(content))

# 9. 修改initDevice命令
content = content.replace(
'''    // ★ v5.1: initDevice - 手动初始化虚拟设备
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady ? @"OK" : @"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
    }''',
'''    // ★ v5.2: initDevice - 手动初始化虚拟设备（触摸+键盘）
    else if([action isEqualToString:@"initDevice"]) {
        bool ok = initVirtualTouchDevice();
        resp[@"success"]=@(ok);
        resp[@"virtualDevice"]=g_virtualDeviceReady ? @"OK" : @"FAILED";
        resp[@"virtualKeyboardDevice"]=g_virtualKeyboardReady ? @"OK" : @"FAILED";
        resp[@"error"]=g_virtualDeviceError ?: @"";
    }''')

# 10. 修改diagnose命令
content = content.replace(
'''        resp[@"diagnostics"]=@{
            @"version": @"5.1",''',
'''        resp[@"diagnostics"]=@{
            @"version": @"5.2",''')

content = content.replace(
'''            // ★ v5.1: IOHIDUserDevice
            @"IOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualDeviceError": g_virtualDeviceError ?: @"",''',
'''            // ★ v5.2: IOHIDUserDevice
            @"IOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@"OK":@"NULL",
            @"IOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@"OK":@"NULL",
            @"virtualDevice": g_virtualDeviceReady?@"OK":@"FAILED",
            @"virtualKeyboardDevice": g_virtualKeyboardReady?@"OK":@"FAILED",
            @"virtualDeviceError": g_virtualDeviceError ?: @"",''')

print("Phase 9-10 done, length:", len(content))

# 11. 修改validate命令
content = content.replace(
'''            // ★ v5.1: IOHIDUserDevice
            @"functionIOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@YES:@NO,
            @"functionIOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
            @"frontmostContextID": @(frontmostCID),''',
'''            // ★ v5.2: IOHIDUserDevice
            @"functionIOHIDUserDeviceCreate": IOHIDUserDeviceCreateFunc?@YES:@NO,
            @"functionIOHIDUserDeviceHandleReport": IOHIDUserDeviceHandleReportFunc?@YES:@NO,
            @"canInjectTouch": @(canInjectTouch),
            @"virtualDeviceReady": @(g_virtualDeviceReady),
            @"virtualKeyboardReady": @(g_virtualKeyboardReady),
            @"frontmostContextID": @(frontmostCID),''')

# 12. 修改SpringBoard日志
content = content.replace(
    'NSLog(@"[StarCoreTweak] SpringBoard启动 v5.1 (安全修复版)");',
    'NSLog(@"[StarCoreTweak] SpringBoard启动 v5.2 (安全修复版)");')

content = content.replace(
'''// ★ v5.1 安全修复：禁用自动创建虚拟设备（防止SpringBoard崩溃）
// 用户需要手动调用 initDevice 命令来初始化虚拟设备
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        bool ok = initVirtualTouchDevice();
//        NSLog(@"[StarCoreTweak] 虚拟触摸设备初始化: %@", ok ? @"成功" : @"失败");
//    });
    NSLog(@"[StarCoreTweak] v5.1 安全模式: 虚拟设备未自动创建，需手动调用initDevice");''',
'''// ★ v5.2 安全修复：禁用自动创建虚拟设备（防止SpringBoard崩溃）
// 用户需要手动调用 initDevice 命令来初始化虚拟设备
// 虚拟键盘设备需要单独创建，用于keyPress/textInput
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        bool ok = initVirtualTouchDevice();
//        NSLog(@"[StarCoreTweak] 虚拟触摸设备初始化: %@", ok ? @"成功" : @"失败");
//    });
    NSLog(@"[StarCoreTweak] v5.2 安全模式: 虚拟设备未自动创建，需手动调用initDevice");''')

# 13. 修改ctor日志
content = content.replace(
    '%ctor { NSLog(@"[StarCoreTweak] v5.1 loading... (安全修复版)"); }',
    '%ctor { NSLog(@"[StarCoreTweak] v5.2 loading... (安全修复版)"); }')

print("Phase 11-13 done, length:", len(content))

# 写入修改后的文件
with open('StarCoreTweak/Tweak.xm', 'w') as f:
    f.write(content)

print("Tweak.xm written successfully!")

# 修改control文件
with open('StarCoreTweak/control', 'r') as f:
    control = f.read()

control = control.replace(
'''Package: com.starcore.tweak
Name: StarCoreTweak
Version: 5.1.0
Architecture: iphoneos-arm64
Description: StarCore Tweak v5.1 - 安全修复版（禁用自动虚拟设备创建，修复HID Report打包）
Maintainer: StarCore
Author: StarCore
Section: Tweaks
Depends: mobilesubstrate''',
'''Package: com.starcore.tweak
Name: StarCoreTweak
Version: 5.2.0
Architecture: iphoneos-arm64
Description: StarCore Tweak v5.2 - 安全修复版（禁用keyPress通过IOHIDEventSystemClient，创建虚拟键盘设备）
Maintainer: StarCore
Author: StarCore
Section: Tweaks
Depends: mobilesubstrate''')

with open('StarCoreTweak/control', 'w') as f:
    f.write(control)

print("control written successfully!")
