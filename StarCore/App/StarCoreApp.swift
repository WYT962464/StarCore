import SwiftUI

@main
struct StarCoreApp: App {
    @StateObject private var lifeCore = LifeCore()
    @StateObject private var mindCore: MindCore
    
    init() {
        let life = LifeCore()
        _lifeCore = StateObject(wrappedValue: life)
        _mindCore = StateObject(wrappedValue: MindCore(lifeCoreReadOnly: LifeCoreReadOnlyWrapper(lifeCore: life)))
    }
    
    var body: some Scene {
        WindowGroup {
            // 使用新的控制台作为主界面
            StarCoreConsole()
                .environmentObject(lifeCore)
                .environmentObject(mindCore)
        }
    }
}
