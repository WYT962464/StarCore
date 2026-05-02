import SwiftUI
import UIKit
import CoreMotion
import CoreLocation
import Network

struct HexagramEngine {
    static let allHexagrams: [(name: String, symbol: String, nature: String, meaning: String, upper: String, lower: String)] = [
        ("乾","☰☰","天","自强不息·刚健中正","天","天"),("坤","☷☷","地","厚德载物·柔顺包容","地","地"),
        ("屯","☵☳","水雷","万物初生·艰难起步","水","雷"),("蒙","☶☵","山水","启蒙教化·混沌求明","山","水"),
        ("需","☵☰","水天","守正待时·耐心积蓄","水","天"),("讼","☰☵","天水","争讼不和·谨慎应对","天","水"),
        ("师","☷☵","地水","统率众力·纪律严明","地","水"),("比","☵☷","水地","亲比相助·团结协作","水","地"),
        ("小畜","☴☰","风天","蓄积小力·以柔济刚","风","天"),("履","☰☱","天泽","谨慎行走·循礼而行","天","泽"),
        ("泰","☷☰","地天","天地交泰·通达和谐","地","天"),("否","☰☷","天地","天地不交·闭塞不通","天","地"),
        ("同人","☰☲","天火","志同道合·协力同心","天","火"),("大有","☲☰","火天","大有所成·光明普照","火","天"),
        ("谦","☷☶","地山","谦逊低调·功成不居","地","山"),("豫","☳☷","雷地","愉悦安乐·顺势而动","雷","地"),
        ("随","☱☳","泽雷","随时变通·顺应大势","泽","雷"),("蛊","☶☴","山风","拨乱反正·革新除弊","山","风"),
        ("临","☷☱","地泽","临近就位·以大临小","地","泽"),("观","☴☷","风地","观察审视·以德示人","风","地"),
        ("噬嗑","☲☳","火雷","明罚敕法·刚柔相济","火","雷"),("贲","☶☲","山火","文饰修饰·实质为要","山","火"),
        ("剥","☶☷","山地","剥落衰败·顺时而止","山","地"),("复","☷☳","地雷","一阳来复·生机重现","地","雷"),
        ("无妄","☰☳","天雷","至诚不妄·顺应天道","天","雷"),("大畜","☶☰","山天","大积大蓄·蓄势待发","山","天"),
        ("颐","☶☳","山雷","颐养正道·谨慎修养","山","雷"),("大过","☱☴","泽风","过度非常·果断应变","泽","风"),
        ("坎","☵☵","水","重险重重·以诚破险","水","水"),("离","☲☲","火","光明附丽·柔顺中正","火","火"),
        ("咸","☱☶","泽山","感应相通·以虚受人","泽","山"),("恒","☳☴","雷风","恒久不变·守正持恒","雷","风"),
        ("遁","☰☶","天山","退避隐遁·明哲保身","天","山"),("大壮","☳☰","雷天","刚健壮盛·非礼弗履","雷","天"),
        ("晋","☲☷","火地","光明进取·顺而上行","火","地"),("明夷","☷☲","地火","光明受损·韬光养晦","地","火"),
        ("家人","☴☲","风火","治家有道·各司其职","风","火"),("睽","☲☱","火泽","乖离违逆·求同存异","火","泽"),
        ("蹇","☵☶","水山","行路艰难·见险而止","水","山"),("解","☳☵","雷水","解除困难·速战速决","雷","水"),
        ("损","☶☱","山泽","减损自我·以益于人","山","泽"),("益","☳☴","雷风","增益进取·迁善改过","雷","风"),
        ("夬","☱☰","泽天","决断刚毅·除邪扶正","泽","天"),("姤","☰☴","天风","不期而遇·防微杜渐","天","风"),
        ("萃","☱☷","泽地","聚集汇合·以正聚众","泽","地"),("升","☷☴","地风","上升进取·积小成大","地","风"),
        ("困","☵☱","水泽","困顿艰难·守志不屈","水","泽"),("井","☴☵","风水","汲取不竭·修德养民","风","水"),
        ("革","☱☲","泽火","变革更新·顺天应人","泽","火"),("鼎","☲☴","火风","革故鼎新·正位凝命","火","风"),
        ("震","☳☳","雷","雷声震动·临危不乱","雷","雷"),("艮","☶☶","山","静止安止·时止则止","山","山"),
        ("渐","☴☶","风山","循序渐进·稳步前行","风","山"),("归妹","☳☱","雷泽","归终有序·以正合礼","雷","泽"),
        ("丰","☳☲","雷火","丰盛光大·明动相合","雷","火"),("旅","☲☶","火山","旅途羁旅·柔顺中正","火","山"),
        ("巽","☴☴","风","顺风顺水·柔顺谦逊","风","风"),("兑","☱☱","泽","喜悦和乐·刚中柔外","泽","泽"),
        ("涣","☴☵","风水","涣散离散·以正聚合","风","水"),("节","☵☱","水泽","节制有度·制度约束","水","泽"),
        ("中孚","☴☱","风泽","诚信立身·以信感人","风","泽"),("小过","☳☶","雷山","小有过越·低调行事","雷","山"),
        ("既济","☵☲","水火","功成事定·守成防衰","水","火"),("未济","☲☵","火水","尚未完成·新的开始","火","水"),
    ]
    
    static func currentMessageHexagram(hour: Int) -> (name: String, symbol: String, desc: String, color: Color, action: String) {
        switch hour {
        case 23, 0: return ("复","☷☳","一阳初生",.indigo,"休眠充电·自我修复")
        case 1, 2:  return ("临","☷☱","阳气渐长",.blue,"深度维护·日志归档")
        case 3, 4:  return ("泰","☷☰","阴阳交泰",.cyan,"轻度预热·环境感知")
        case 5, 6:  return ("大壮","☳☰","阳气壮盛",.teal,"启动就绪·功能预热")
        case 7, 8:  return ("夬","☱☰","阳气决断",.green,"活跃运行·主动服务")
        case 9, 10: return ("乾","☰☰","纯阳刚健",.orange,"峰值输出·全力进化")
        case 11, 12: return ("姤","☰☴","一阴初生",.yellow,"输出衰减·自我审视")
        case 13, 14: return ("遁","☰☶","阴气渐长",.yellow,"降低负载·精简运行")
        case 15, 16: return ("否","☰☷","阴阳不交",.orange,"节能模式·必要响应")
        case 17, 18: return ("观","☴☷","阴气观瞻",.red,"观察模式·被动响应")
        case 19, 20: return ("剥","☶☷","阴气剥阳",.red,"低功耗·关闭非必要")
        case 21, 22: return ("坤","☷☷","纯阴守成",.purple,"休眠归档·记忆沉淀")
        default:     return ("坤","☷☷","守成",.purple,"休眠归档")
        }
    }
    
    static func deriveHexagram(yin: Double, yang: Double) -> (name: String, desc: String, advice: String) {
        let ratio = yang / max(yin + yang, 0.01)
        if ratio > 0.9 { return ("乾","天行健·自强不息","⚡ 能量充沛，主动出击！") }
        else if ratio > 0.8 { return ("夬","决断·刚毅果决","🔥 状态正佳，高效执行") }
        else if ratio > 0.7 { return ("大壮","壮盛·雷天大壮","💪 运行良好，持续输出") }
        else if ratio > 0.6 { return ("泰","通泰·天地交合","✨ 阴阳调和，稳中求进") }
        else if ratio > 0.5 { return ("临","临近·阳临阴","🔄 渐入佳境，蓄势待发") }
        else if ratio > 0.4 { return ("复","复归·一阳来复","🌱 正在恢复，注意休息") }
        else if ratio > 0.3 { return ("观","观瞻·风行地上","👁️ 静观其变，保存体力") }
        else if ratio > 0.2 { return ("剥","剥落·山地剥","⚠️ 资源紧张，精简运行") }
        else if ratio > 0.1 { return ("否","否塞·天地不交","🛑 能量不足，停止非必要") }
        else { return ("坤","厚德载物·守成休养","💤 亟需充能，休眠保护") }
    }
    
    static func evaluateStatus(battery: Float, cpu: Double, memory: Double, motion: Double) -> (emoji: String, label: String, color: Color) {
        let e = Double(battery) * 100; let l = (cpu + memory) / 2
        if e < 10 { return ("💔","危急",.red) }
        else if e < 20 { return ("🥵","虚弱",.orange) }
        else if l > 80 { return ("🔥","过载",.red) }
        else if l > 60 { return ("⚡","满载",.orange) }
        else if motion > 50 { return ("🏃","活跃",.green) }
        else if e > 80 && l < 30 { return ("😌","安逸",.cyan) }
        else if e > 50 { return ("💙","平稳",.blue) }
        else { return ("💛","警戒",.yellow) }
    }
}

struct StatusLog: Identifiable, Codable {
    let id: UUID; let time: String; let hexagram: String; let status: String; let event: String
    init(time: String, hexagram: String, status: String, event: String) { self.id = UUID(); self.time = time; self.hexagram = hexagram; self.status = status; self.event = event }
}

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onHeading: ((CLHeading) -> Void)?
    func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) { onHeading?(heading) }
    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
}

struct ContentView: View {
    @State private var batteryLevel: Float = 0
    @State private var batteryState: UIDevice.BatteryState = .unknown
    @State private var currentTime: String = ""
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var storageUsed: String = ""; @State private var storageTotal: String = ""; @State private var storagePercent: Double = 0
    @State private var accelerometerX: Double = 0; @State private var accelerometerY: Double = 0; @State private var accelerometerZ: Double = 0
    @State private var gyroX: Double = 0; @State private var gyroY: Double = 0; @State private var gyroZ: Double = 0
    @State private var motionManager = CMMotionManager()
    @State private var uptime: TimeInterval = 0
    @State private var heartBeatScale: CGFloat = 1.0
    @State private var networkStatus: String = "检测中..."
    @State private var statusLogs: [StatusLog] = []
    @State private var lastHexagram: String = ""; @State private var lastStatus: String = ""
    @State private var monitor = NWPathMonitor()
    @State private var selectedHexagram: (name: String, symbol: String, nature: String, meaning: String, upper: String, lower: String)? = nil
    // 磁场+朝向
    @State private var heading: Double = -1
    @State private var magneticX: Double = 0; @State private var magneticY: Double = 0; @State private var magneticZ: Double = 0
    @State private var locationManager: CLLocationManager?
    @State private var locationDelegate: LocationDelegate?
    @State private var deviceOrientation: UIDeviceOrientation = .unknown
    @State private var screenBrightness: Double = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let logURL: URL = { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("starcore_log.json") }()
    
    var yinValue: Double { (cpuUsage + memoryUsage) / 2 }
    var yangValue: Double { (Double(batteryLevel) * 100 + motionIntensity) / 2 }
    var motionIntensity: Double { let a = sqrt(accelerometerX * accelerometerX + accelerometerY * accelerometerY + accelerometerZ * accelerometerZ); let g = sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ); return min(100, (a + g) * 10) }
    var magneticIntensity: Double { sqrt(magneticX * magneticX + magneticY * magneticY + magneticZ * magneticZ) }
    var headingDirection: String {
        if heading < 0 { return "无方向" }
        let h = heading.truncatingRemainder(dividingBy: 360)
        if h >= 337.5 || h < 22.5 { return "北" }
        else if h < 67.5 { return "东北" }
        else if h < 112.5 { return "东" }
        else if h < 157.5 { return "东南" }
        else if h < 202.5 { return "南" }
        else if h < 247.5 { return "西南" }
        else if h < 292.5 { return "西" }
        else { return "西北" }
    }
    var orientationIcon: String {
        switch deviceOrientation {
        case .portrait: return "📱↑"
        case .portraitUpsideDown: return "📱↓"
        case .landscapeLeft: return "📱←"
        case .landscapeRight: return "📱→"
        case .faceUp: return "📱☀️"
        case .faceDown: return "📱🌙"
        default: return "📱"
        }
    }
    
    var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    var msgHex: (name: String, symbol: String, desc: String, color: Color, action: String) { HexagramEngine.currentMessageHexagram(hour: currentHour) }
    var drvHex: (name: String, desc: String, advice: String) { HexagramEngine.deriveHexagram(yin: yinValue, yang: yangValue) }
    var stat: (emoji: String, label: String, color: Color) { HexagramEngine.evaluateStatus(battery: batteryLevel, cpu: cpuUsage, memory: memoryUsage, motion: motionIntensity) }
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.03, green: 0.03, blue: 0.1), Color(red: 0.08, green: 0.08, blue: 0.2), Color(red: 0.03, green: 0.12, blue: 0.15)]), startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    // 太极
                    VStack(spacing: 4) {
                        Text("☯️ 星核 ☯️").font(.system(size: 36, weight: .bold)).foregroundColor(.white).shadow(color: stat.color, radius: 12).scaleEffect(heartBeatScale).animation(.easeInOut(duration: 0.3), value: heartBeatScale)
                        HStack(spacing: 6) { Text(stat.emoji).font(.title2); Text(stat.label).font(.title3).fontWeight(.bold).foregroundColor(stat.color); Text(msgHex.symbol).font(.title2) }
                    }
                    
                    // 决策卡片
                    VStack(spacing: 5) {
                        HStack { Text(msgHex.symbol + " " + msgHex.name + "卦").font(.headline).foregroundColor(msgHex.color); Spacer(); Text(msgHex.desc).font(.caption).foregroundColor(.gray) }
                        HStack { Image(systemName: "bolt.fill").foregroundColor(msgHex.color).font(.caption); Text(msgHex.action).font(.caption).foregroundColor(.white.opacity(0.9)); Spacer() }
                        Divider().background(Color.gray.opacity(0.3))
                        HStack { Text(drvHex.name + "卦·" + drvHex.desc).font(.headline).foregroundColor(.cyan); Spacer(); Button(action: { if let h = HexagramEngine.allHexagrams.first(where: { $0.name == drvHex.name }) { selectedHexagram = h } }) { Image(systemName: "info.circle").foregroundColor(.cyan).font(.caption) } }
                        HStack { Text(drvHex.advice).font(.subheadline).foregroundColor(.cyan.opacity(0.9)); Spacer() }
                    }.padding(10).background(Color.white.opacity(0.06)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(msgHex.color.opacity(0.3), lineWidth: 1)).padding(.horizontal)
                    
                    // 两仪
                    HStack(spacing: 0) {
                        VStack(spacing: 1) { Text("阴·信息流").font(.system(size: 9)).foregroundColor(.purple.opacity(0.7)); Text(String(format: "%.0f", yinValue)).font(.system(size: 26, weight: .bold)).foregroundColor(.purple) }.frame(maxWidth: .infinity)
                        VStack(spacing: 3) { GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.3)).frame(height: 5); let r = yangValue / max(yinValue + yangValue, 1); RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing)).frame(width: geo.size.width * CGFloat(r), height: 5) } }.frame(height: 5) }.frame(maxWidth: .infinity)
                        VStack(spacing: 1) { Text("阳·能量流").font(.system(size: 9)).foregroundColor(.orange.opacity(0.7)); Text(String(format: "%.0f", yangValue)).font(.system(size: 26, weight: .bold)).foregroundColor(.orange) }.frame(maxWidth: .infinity)
                    }.padding(.horizontal)
                    
                    Divider().background(Color.gray.opacity(0.2))
                    
                    // 八卦·八维
                    SensorRow(icon: "💚", name: "离·获取", label: "气血", value: String(format: "%.1f%%", batteryLevel * 100), detail: batteryStateDesc, progress: Double(batteryLevel), color: .green)
                    SensorRow(icon: "💙", name: "坎·执行", label: "脉搏", value: currentTime, detail: nil, progress: nil, color: .cyan)
                    SensorRow(icon: "❤️", name: "震·处理", label: "心跳", value: String(format: "%.1f%%", cpuUsage), detail: nil, progress: cpuUsage / 100, color: .red)
                    SensorRow(icon: "💜", name: "艮·校验", label: "思维", value: String(format: "%.1f%%", memoryUsage), detail: nil, progress: memoryUsage / 100, color: .purple)
                    SensorRow(icon: "💛", name: "坤·存储", label: "储备", value: "\(storageUsed)/\(storageTotal)", detail: String(format: "%.0f%%", storagePercent), progress: storagePercent / 100, color: .yellow)
                    
                    // 乾·收集 - 增强版（触觉+磁场+朝向+光线）
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text("🧭 乾·收集").font(.subheadline).foregroundColor(.orange); Spacer(); Text(String(format: "%.0f%%", motionIntensity)).font(.subheadline).foregroundColor(.orange) }
                        
                        // 触觉
                        HStack { Text("触觉").font(.system(size: 9)).foregroundColor(.gray); Spacer(); Text("A:\(String(format: "%.1f", accelerometerX)),\(String(format: "%.1f", accelerometerY)),\(String(format: "%.1f", accelerometerZ))").font(.system(size: 9)).foregroundColor(.orange.opacity(0.5)) }
                        
                        // 磁场
                        HStack { Text("磁场").font(.system(size: 9)).foregroundColor(.gray); Spacer(); Text(heading >= 0 ? "\(headingDirection) \(String(format: "%.0f", heading))° | \(String(format: "%.0f", magneticIntensity))μT" : "无数据").font(.system(size: 9)).foregroundColor(.orange.opacity(0.5)) }
                        
                        // 朝向+光线
                        HStack { Text("\(orientationIcon) 朝向").font(.system(size: 9)).foregroundColor(.gray); Spacer(); Text("光线 \(String(format: "%.0f", screenBrightness))%").font(.system(size: 9)).foregroundColor(.orange.opacity(0.5)); Text("📡 \(networkStatus)").font(.system(size: 9)).foregroundColor(networkStatus == "离线" ? .red.opacity(0.7) : .green.opacity(0.7)) }
                        
                        ProgressView(value: motionIntensity / 100).progressViewStyle(LinearProgressViewStyle(tint: .orange))
                    }.padding(.horizontal)
                    
                    SensorRow(icon: "⚪️", name: "兑·迭代", label: "进化", value: formatUptime(uptime), detail: "v0.1.17", progress: min(1, uptime / 86400), color: .white.opacity(0.7))
                    SensorRow(icon: "🔵", name: "巽·输出", label: "状态", value: "\(msgHex.name)·\(drvHex.name)", detail: drvHex.desc, progress: yangValue / 100, color: .blue)
                    
                    Divider().background(Color.gray.opacity(0.2))
                    
                    // 变易日志
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text("📜 变易日志").font(.headline).foregroundColor(.white.opacity(0.8)); Spacer(); if !statusLogs.isEmpty { Text("\(statusLogs.count)条").font(.caption).foregroundColor(.gray) } }
                        if statusLogs.isEmpty { Text("等待卦象流转...").font(.caption).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8) }
                        else { ForEach(statusLogs.suffix(5).reversed()) { log in HStack { Text(log.time).font(.system(size: 9, design: .monospaced)).foregroundColor(.gray); Text(log.hexagram).font(.system(size: 10, weight: .bold)).foregroundColor(.cyan); Text(log.status).font(.system(size: 10)).foregroundColor(.white.opacity(0.7)); Spacer(); Text(log.event).font(.system(size: 9)).foregroundColor(.yellow.opacity(0.8)) } } }
                    }.padding(10).background(Color.white.opacity(0.04)).cornerRadius(8).padding(.horizontal)
                }.padding(.vertical, 6)
            }
        }
        .sheet(item: Binding(get: { selectedHexagram.map { HexagramDetail(name: $0.name, symbol: $0.symbol, nature: $0.nature, meaning: $0.meaning, upper: $0.upper, lower: $0.lower) } }, set: { if $0 == nil { selectedHexagram = nil } })) { detail in HexagramDetailView(detail: detail) }
        .onReceive(timer) { _ in updateAll() }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            startNetworkMonitor(); startLocationManager(); loadLogs(); updateAll(); startMotionUpdates()
            deviceOrientation = UIDevice.current.orientation
            NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in deviceOrientation = UIDevice.current.orientation }
        }
    }
    
    var batteryStateDesc: String { switch batteryState { case .charging: return "⚡充电中"; case .full: return "🔋已充满"; case .unplugged: return "🔌未充电"; default: return "" } }
    
    func startNetworkMonitor() { let q = DispatchQueue(label: "network"); monitor.pathUpdateHandler = { path in DispatchQueue.main.async { if path.status == .satisfied { if path.usesInterfaceType(.wifi) { self.networkStatus = "WiFi" } else if path.usesInterfaceType(.cellular) { self.networkStatus = "蜂窝" } else { self.networkStatus = "在线" } } else { self.networkStatus = "离线" } } }; monitor.start(queue: q) }
    
    func startLocationManager() {
        let lm = CLLocationManager(); let ld = LocationDelegate()
        lm.requestWhenInUseAuthorization()
        ld.onHeading = { h in DispatchQueue.main.async {
            self.heading = h.trueHeading >= 0 ? h.trueHeading : h.magneticHeading
            self.magneticX = h.x; self.magneticY = h.y; self.magneticZ = h.z
        }}
        lm.delegate = ld; lm.headingFilter = CLHeadingFilter(5)
        if CLLocationManager.headingAvailable() { lm.startUpdatingHeading() }
        self.locationManager = lm; self.locationDelegate = ld
    }
    
    func loadLogs() { if let data = try? Data(contentsOf: logURL), let logs = try? JSONDecoder().decode([StatusLog].self, from: data) { statusLogs = logs } }
    func saveLogs() { if let data = try? JSONEncoder().encode(statusLogs) { try? data.write(to: logURL) } }
    
    func updateAll() {
        batteryLevel = UIDevice.current.batteryLevel; batteryState = UIDevice.current.batteryState
        screenBrightness = Double(UIScreen.main.brightness * 100)
        updateCurrentTime(); updateCPUUsage(); updateMemoryUsage(); updateStorageUsage()
        uptime = ProcessInfo.processInfo.systemUptime; triggerHeartBeat(); checkStatusChange()
    }
    
    func checkStatusChange() {
        let cH = drvHex.name; let cS = stat.label
        if lastHexagram != "" && (cH != lastHexagram || cS != lastStatus) {
            var e = ""
            if cH != lastHexagram { e += "\(lastHexagram)→\(cH)" }
            if cS != lastStatus { e += e.isEmpty ? "\(lastStatus)→\(cS)" : " \(lastStatus)→\(cS)" }
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            statusLogs.append(StatusLog(time: f.string(from: Date()), hexagram: cH + "卦", status: cS, event: e))
            if statusLogs.count > 100 { statusLogs.removeFirst() }
            saveLogs()
        }
        lastHexagram = cH; lastStatus = cS
    }
    
    func formatUptime(_ s: TimeInterval) -> String { let d = Int(s)/86400; let h = Int(s)%86400/3600; let m = Int(s)%3600/60; return d > 0 ? "\(d)d\(h)h\(m)m" : "\(h)h\(m)m" }
    func startMotionUpdates() {
        if motionManager.isAccelerometerAvailable { motionManager.accelerometerUpdateInterval = 0.1; motionManager.startAccelerometerUpdates(to: .main) { d, _ in if let d = d { accelerometerX = d.acceleration.x; accelerometerY = d.acceleration.y; accelerometerZ = d.acceleration.z } } }
        if motionManager.isGyroAvailable { motionManager.gyroUpdateInterval = 0.1; motionManager.startGyroUpdates(to: .main) { d, _ in if let d = d { gyroX = d.rotationRate.x; gyroY = d.rotationRate.y; gyroZ = d.rotationRate.z } } }
    }
    func triggerHeartBeat() { let i = max(0.02, min(0.1, cpuUsage / 1000)); heartBeatScale = 1.0 + CGFloat(i); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { heartBeatScale = 1.0 } }
    func updateCurrentTime() { let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; currentTime = f.string(from: Date()) }
    func updateCPUUsage() { var total: Double = 0; var info = processor_info_array_t(bitPattern: 0); var count = mach_msg_type_number_t(0); var n = UInt32(0); let r = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &n, &info, &count); if r == KERN_SUCCESS { for i in 0..<Int(n) { let c = info!.advanced(by: i * Int(CPU_STATE_MAX)); let u = Double(c[Int(CPU_STATE_USER)]), s = Double(c[Int(CPU_STATE_SYSTEM)]), ni = Double(c[Int(CPU_STATE_NICE)]), id = Double(c[Int(CPU_STATE_IDLE)]); let t = u+s+ni+id; if t > 0 { total += (u+s+ni)/t*100 } }; cpuUsage = total/Double(n) }; vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(count * UInt32(MemoryLayout<integer_t>.stride))) }
    func updateMemoryUsage() { var t = task_vm_info_data_t(); var c = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size); let r = withUnsafeMutablePointer(to: &t) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(c)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &c) } }; if r == KERN_SUCCESS { memoryUsage = Double(t.phys_footprint) / Double(ProcessInfo.processInfo.physicalMemory) * 100 } }
    func updateStorageUsage() { do { let d = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false); let v = try d.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]); if let t = v.volumeTotalCapacity, let a = v.volumeAvailableCapacityForImportantUsage { let u = t-Int(a); storageUsed = ByteCountFormatter.string(fromByteCount: Int64(u), countStyle: .file); storageTotal = ByteCountFormatter.string(fromByteCount: Int64(t), countStyle: .file); storagePercent = Double(u)/Double(t)*100 } } catch { storageUsed = "未知"; storageTotal = "未知"; storagePercent = 0 } }
}

struct HexagramDetail: Identifiable { let id = UUID(); let name: String; let symbol: String; let nature: String; let meaning: String; let upper: String; let lower: String }

struct HexagramDetailView: View {
    let detail: HexagramDetail
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack { Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(detail.symbol).font(.system(size: 60))
                Text(detail.name + "卦").font(.system(size: 36, weight: .bold)).foregroundColor(.cyan)
                Text(detail.nature).font(.title3).foregroundColor(.white.opacity(0.8))
                Divider().background(Color.gray.opacity(0.3)).padding(.horizontal, 40)
                Text(detail.meaning).font(.title2).foregroundColor(.cyan).multilineTextAlignment(.center).padding(.horizontal, 30)
                HStack(spacing: 30) {
                    VStack { Text("上卦").font(.caption).foregroundColor(.gray); Text(detail.upper).font(.title3).foregroundColor(.white) }
                    VStack { Text("下卦").font(.caption).foregroundColor(.gray); Text(detail.lower).font(.title3).foregroundColor(.white) }
                }
                Spacer()
                Button("关闭") { dismiss() }.foregroundColor(.cyan).padding()
            }.padding(.top, 40)
        }
    }
}

struct SensorRow: View {
    let icon: String; let name: String; let label: String; let value: String; let detail: String?; let progress: Double?; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text("\(icon) \(name)·\(label)").font(.subheadline).foregroundColor(color); Spacer(); if let d = detail { Text(d).font(.system(size: 10)).foregroundColor(color.opacity(0.6)) }; Text(value).font(.subheadline).foregroundColor(color) }
            if let p = progress { ProgressView(value: p).progressViewStyle(LinearProgressViewStyle(tint: color)).shadow(color: color, radius: 2) }
        }.padding(.horizontal)
    }
}

#Preview { ContentView() }
