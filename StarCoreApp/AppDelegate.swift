import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
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

        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.navigationBar.barStyle = .black
        settingsNav.navigationBar.isTranslucent = true
        settingsNav.navigationBar.setBackgroundImage(UIImage(), for: .default)
        settingsNav.navigationBar.shadowImage = UIImage()
        settingsNav.navigationBar.tintColor = UIColor(red: 0x60/255, green: 0xa5/255, blue: 0xfa/255, alpha: 1.0)

        tabBarController = UITabBarController()
        tabBarController?.viewControllers = [chatNav, settingsNav]
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

        return true
    }

    private func tabImage(name: String) -> UIImage? {
        // Use SF Symbols if available, otherwise return nil and let system use text only
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
            if name == "chat" {
                return UIImage(systemName: "message", withConfiguration: config)
            } else if name == "chat.fill" {
                return UIImage(systemName: "message.fill", withConfiguration: config)
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
