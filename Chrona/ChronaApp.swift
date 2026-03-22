import SwiftUI
import UserNotifications
import AppKit

@main
struct ChronaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        // 主窗口
        WindowGroup(id: "main") {
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
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 请求通知权限
        NotificationManager.shared.requestAuthorization()
        
        // 延迟检查权限，如果未授权则提醒
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus != .authorized {
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "通知权限未开启"
                        alert.informativeText = "为了能准时提醒你开始任务，Chrona 需要通知权限。请在系统设置中开启。"
                        alert.addButton(withTitle: "去设置")
                        alert.addButton(withTitle: "稍后")
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            NotificationManager.shared.openSettings()
                        }
                    }
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭窗口后不退出应用
        return false
    }
}
