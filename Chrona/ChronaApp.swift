import SwiftUI

@main
struct ChronaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // 主窗口
        WindowGroup {
            MainWindow()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        // 菜单栏
        MenuBarExtra("Chrona", systemImage: "clock.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        NotificationManager.shared.requestAuthorization()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭窗口后不退出应用
        return false
    }
}
