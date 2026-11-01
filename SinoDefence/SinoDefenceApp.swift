import SwiftUI

@main
struct SinoDefenceApp: App {
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetTabs") {
            UserDefaults.standard.removeObject(forKey: TabOrder.defaultsKey)
        }
        #endif
    }

    @State private var session = Session()
    @AppStorage(AppAppearance.defaultsKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .tint(AppTheme.accent)
                .environment(settings)
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
