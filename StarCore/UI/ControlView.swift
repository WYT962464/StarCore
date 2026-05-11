/**
 * ControlView.swift
 * 操控面板 - ZXTouch远程操控界面
 *
 * 功能：
 * - 连接状态实时指示
 * - 手动测试按钮（点击/滑动/截图/输入）
 * - 执行日志输出
 * - 坐标预设快捷操作
 */

import SwiftUI

@available(iOS 15.0, *)
struct ControlView: View {
    @ObservedObject private var coordinator = ActionCoordinator.shared
    @State private var tapX: String = "187"
    @State private var tapY: String = "400"
    @State private var inputText: String = ""
    @State private var isExecuting = false
    @State private var controlLogs: [String] = []
    @State private var screenshotImage: UIImage?

    private let maxLogs = 100

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                connectionCard
                tapControlCard
                swipeControlCard
                inputControlCard
                quickActionsCard
                screenshotCard
                logCard
            }
            .padding()
        }
    }

    // MARK: - 连接状态卡片

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接状态").font(.headline).foregroundColor(.white)

            HStack(spacing: 16) {
                // Tweak状态
                connectionIndicator(
                    name: "Tweak/XPC",
                    available: coordinator.isTweakAvailable
                )
                // ZXTouch状态
                connectionIndicator(
                    name: "ZXTouch",
                    available: coordinator.isZXTouchAvailable
                )
            }

            if !coordinator.isAnyControlAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("无可用操控服务，请确认Tweak或ZXTouch已安装")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Button(action: {
                coordinator.connectAll()
                addLog("重新检测连接...")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("重新检测")
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }

    private func connectionIndicator(name: String, available: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(available ? Color.green : Color.red.opacity(0.5))
                .frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white)
            Text(available ? "可用" : "不可用")
                .font(.caption)
                .foregroundColor(available ? .green : .gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 点击控制卡片

    private var tapControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("点击控制").font(.headline).foregroundColor(.white)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("X").font(.caption).foregroundColor(.gray)
                    TextField("X", text: $tapX)
                        .keyboardType(.numberPad)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Y").font(.caption).foregroundColor(.gray)
                    TextField("Y", text: $tapY)
                        .keyboardType(.numberPad)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                }
            }

            HStack(spacing: 8) {
                actionButton("点击", icon: "hand.tap") {
                    await executeCommand(.tap(x: Int(tapX) ?? 187, y: Int(tapY) ?? 400))
                }
                actionButton("长按1s", icon: "hand.point.up.left") {
                    await executeCommand(.touchHold(x: Int(tapX) ?? 187, y: Int(tapY) ?? 400, duration: 1000))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 45/255, green: 45/255, blue: 74/255)))
    }

    // MARK: - 滑动控制卡片

    private var swipeControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("滑动控制").font(.headline).foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                actionButton("↑ 上滑", icon: "arrow.up") {
                    await executeCommand(ActionCommandBuilder.swipeUp())
                }
                actionButton("↓ 下滑", icon: "arrow.down") {
                    await executeCommand(ActionCommandBuilder.swipeDown())
                }
                actionButton("← 左滑", icon: "arrow.left") {
                    await executeCommand(ActionCommandBuilder.swipeLeft())
                }
                actionButton("→ 右滑", icon: "arrow.right") {
                    await executeCommand(ActionCommandBuilder.swipeRight())
                }
                actionButton("🏠 回主屏", icon: "house") {
                    await executeCommand(.goHome)
                }
                actionButton("📋 多任务", icon: "square.grid.2x2") {
                    // 双击底部横条模拟多任务
                    await executeCommand(.tap(x: 187, y: 790))
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await executeCommand(.tap(x: 187, y: 790))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }

    // MARK: - 输入控制卡片

    private var inputControlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文字输入").font(.headline).foregroundColor(.white)

            HStack(spacing: 8) {
                TextField("输入要键入的文字...", text: $inputText)
                    .font(.subheadline)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.white)

                Button(action: {
                    let text = inputText.trimmingCharacters(in: .whitespaces)
                    guard !text.isEmpty else { return }
                    Task {
                        await executeCommand(.typeText(text: text))
                    }
                }) {
                    Image(systemName: "keyboard")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }

    // MARK: - 快捷操作卡片

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷操作").font(.headline).foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                actionButton("打开设置", icon: "gear") {
                    await executeCommand(.openApp(bundleId: "com.apple.Preferences"))
                }
                actionButton("打开相册", icon: "photo") {
                    await executeCommand(.openApp(bundleId: "com.apple.mobileslideshow"))
                }
                actionButton("屏幕中心", icon: "scope") {
                    await executeCommand(.tap(x: 187, y: 406))
                }
                actionButton("通知中心", icon: "bell") {
                    await executeCommand(.swipe(fromX: 187, fromY: 0, toX: 187, toY: 400, duration: 300))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 30/255, green: 30/255, blue: 63/255)))
    }

    // MARK: - 截图卡片

    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("截图").font(.headline).foregroundColor(.white)

            actionButton("截取屏幕", icon: "camera") {
                let result = await coordinator.takeScreenshot()
                if let data = result.screenshotData {
                    screenshotImage = UIImage(data: data)
                    addLog("截图成功 (\(data.count) bytes)")
                } else {
                    addLog("截图失败: \(result.message)")
                }
            }

            if let image = screenshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 45/255, green: 45/255, blue: 74/255)))
    }

    // MARK: - 日志卡片

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行日志").font(.headline).foregroundColor(.white)
                Spacer()
                Button(action: { controlLogs.removeAll() }) {
                    Text("清除")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            if controlLogs.isEmpty {
                Text("暂无日志")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(controlLogs.reversed(), id: \.self) { log in
                            Text(log)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 37/255, green: 37/255, blue: 64/255)))
    }

    // MARK: - 辅助方法

    private func actionButton(_ title: String, icon: String, action: @escaping () async -> Void) -> some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isExecuting ? Color.gray.opacity(0.3) : Color.blue.opacity(0.3))
            .cornerRadius(8)
            .foregroundColor(isExecuting ? .gray : .white)
        }
        .disabled(isExecuting)
    }

    private func executeCommand(_ command: ActionCommand) async {
        guard !isExecuting else { return }
        isExecuting = true
        defer { isExecuting = false }

        addLog("→ \(command.description)")
        let result = await coordinator.execute(command)
        let status = result.success ? "✅" : "❌"
        addLog("\(status) \(command.description) [\(result.method.rawValue)] \(result.message)")
    }

    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        controlLogs.append("[\(timestamp)] \(message)")
        if controlLogs.count > maxLogs {
            controlLogs.removeFirst()
        }
    }
}
