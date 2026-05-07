import SwiftUI

@main
struct StarCoreApp: App {
    @StateObject private var lifeCore = LifeCore()
    @StateObject private var mindCore: MindCore
    
    init() {
        let life = LifeCore()
        _lifeCore = StateObject(wrappedValue: life)
        _mindCore = StateObject(wrappedValue: MindCore(lifeCoreReadOnly: life))
    }
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(lifeCore)
                .environmentObject(mindCore)
        }
    }
}
