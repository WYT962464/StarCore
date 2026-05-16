import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var keepalivePlayer: AVAudioPlayer?
    var tabBarController: UITabBarController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 39/255, alpha: 1.0)

        let chatVC = ChatViewController()
        let chatNav = UINavigationController(rootViewController: chatVC)
        chatNav.navigationBar.barStyle = .black
        chatNav.navigationBar.isTranslucent = true
        chatNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        chatNav.navigationBar.shadowImage = UIImage()
        chatNav.navigationBar.tintColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

        let memoryVC = MemoryViewController()
        let memoryNav = UINavigationController(rootViewController: memoryVC)
        memoryNav.navigationBar.barStyle = .black
        memoryNav.navigationBar.isTranslucent = true
        memoryNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        memoryNav.navigationBar.shadowImage = UIImage()
        memoryNav.navigationBar.tintColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.barStyle = .black
        settingsNav.navigationBar.isTranslucent = true
        settingsNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        settingsNav.navigationBar.shadowImage = UIImage()
        settingsNav.navigationBar.tintColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

        tabBarController = UITabBarController()
        tabBarController?.viewControllers = [chatNav, memoryNav, settingsNav]
        tabBarController?.tabBar.barStyle = .black
        tabBarController?.tabBar.isTranslucent = true
        tabBarController?.tabBar.backgroundImage = UIImage()
        tabBarController?.tabBar.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 26/255, alpha: 0.95)

        // Tab bar items
        chatNav.tabBarItem = UITabBarItem(
            title: "聊天",
            image: tabImage(name: "chat"),
            selectedImage: tabImage(name: "chat.fill")
        )
        memoryNav.tabBarItem = UITabBarItem(
            title: "记忆",
            image: tabImage(name: "memory"),
            selectedImage: tabImage(name: "memory.fill")
        )
        settingsNav.tabBarItem = UITabBarItem(
            title: "设置",
            image: tabImage(name: "gear"),
            selectedImage: tabImage(name: "gear.fill")
        )

        // Tab bar text color
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(red: 10/255, green: 14/255, blue: 26/255, alpha: 0.95)
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(white: 1, alpha: 0.4)
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(white: 1, alpha: 0.4)]
        itemAppearance.selected.iconColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)]
        tabBarAppearance.stackedLayoutAppearance = itemAppearance

        if #available(iOS 15.0, *) {
            tabBarController?.tabBar.scrollEdgeAppearance = tabBarAppearance
        }
        tabBarController?.tabBar.standardAppearance = tabBarAppearance

        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()

        // Try initializing ios-mcp in background
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            StarCoreAgent.shared.initializeMcp()
        }

        // Start silent audio keepalive
        startKeepalive()

        return true
    }

    // MARK: - Silent Audio Keepalive (后台保活)
    private func startKeepalive() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)

            // Generate 1 second of silence as WAV
            let sampleRate = 44100.0
            let duration = 1.0
            let numSamples = Int(sampleRate * duration)
            var pcmData = Data(capacity: numSamples * 2)
            for _ in 0..<numSamples {
                pcmData.append(contentsOf: [0, 0])  // silence
            }

            // WAV header
            var header = Data()
            let dataSize = UInt32(numSamples * 2)
            let fileSize = dataSize + 36
            header.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // RIFF
            header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
            header.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // WAVE
            header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // fmt
            header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
            header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
            header.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) })
            header.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) })  // byte rate
            header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
            header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })  // bits per sample
            header.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // data
            header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

            let wavData = header + pcmData
            keepalivePlayer = try AVAudioPlayer(data: wavData)
            keepalivePlayer?.numberOfLoops = -1  // infinite loop
            keepalivePlayer?.volume = 0.0  // silent
            keepalivePlayer?.play()
        } catch {
            print("[StarCore] Keepalive failed: \(error)")
        }
    }

    private func tabImage(name: String) -> UIImage? {
        // Use SF Symbols if available, otherwise return nil and let system use text only
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            if name == "chat" {
                return UIImage(systemName: "message", withConfiguration: config)
            } else if name == "chat.fill" {
                return UIImage(systemName: "message.fill", withConfiguration: config)
            } else if name == "memory" {
                return UIImage(systemName: "brain", withConfiguration: config)
            } else if name == "memory.fill" {
                return UIImage(systemName: "brain", withConfiguration: config)
            } else if name == "gear" {
                return UIImage(systemName: "gearshape", withConfiguration: config)
            } else if name == "gear.fill" {
                return UIImage(systemName: "gearshape.fill", withConfiguration: config)
            }
        }
        return nil
    }

    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationDidBecomeActive(_ application: UIApplication) {}
}
