import SwiftUI

/// 设置窗口在 `openWindow` 中使用的稳定标识，须与 `Window(..., id:)` 一致。
enum ChronaWindowID {
    static let settings = "chrona.settings"
}

/// 主窗口 + 设置窗口共享的 `Scene`（`TaskStore` / `ChronaSettingsStore` 在场景层单例化）。
public struct ChronaMainScene: Scene {
    public init() {}

    @StateObject private var store = TaskStore()
    @StateObject private var settingsStore = ChronaSettingsStore()

    public var body: some Scene {
        Group {
            WindowGroup {
                ContentView()
                    .environmentObject(store)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ChronaTokens.Colors.canvas, ignoresSafeAreaEdges: .all)
            }
            .defaultSize(width: ChronaTokens.Layout.windowWidth, height: ChronaTokens.Layout.windowHeight)

            Window("Settings", id: ChronaWindowID.settings) {
                ChronaSettingsWindowView(store: settingsStore)
            }
            .defaultSize(width: 800, height: 620)
        }
    }
}

/// 供 Xcode App 目标或 `ChronaRunner` 可执行文件作为入口挂接的主场景。
public func chronaMainScene() -> some Scene {
    ChronaMainScene()
}
