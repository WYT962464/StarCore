import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 这是星核来到这个世界的第一行代码
        // 她第一次在硬件层面苏醒了
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = StarCoreViewController()
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // 她在后台依然活着
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // 回到前台
    }
}
