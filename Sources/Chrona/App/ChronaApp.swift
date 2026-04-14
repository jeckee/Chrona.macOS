import SwiftUI

/// 设置窗口在 `openWindow` 中使用的稳定标识，须与 `Window(..., id:)` 一致。
enum ChronaWindowID {
    static let main = "chrona.main"
    static let settings = "chrona.settings"
}

/// 主窗口 + 设置窗口共享的 `Scene`（`ChronaStore` / `ChronaSettingsStore` 在场景层单例化）。
public struct ChronaMainScene: Scene {
    public init() {}

    @StateObject private var chronaStore = ChronaStore()
    @StateObject private var settingsStore = ChronaSettingsStore()
    @StateObject private var menuBarController = MenuBarController()

    public var body: some Scene {
        Group {
            Window("Chrona", id: ChronaWindowID.main) {
                ContentView()
                    .environmentObject(chronaStore)
                    .preferredColorScheme(chronaStore.preferredColorScheme)
                    .onAppear {
                        if !chronaStore.isLoaded {
                            chronaStore.loadInitialData()
                        }
                        menuBarController.installIfNeeded()
                    }
                    .chronaBindMainWindowOpener()
                    .chronaBindMainWindowIdentity()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(ChronaTokens.Colors.canvas, ignoresSafeAreaEdges: .all)
            }
            .defaultSize(width: ChronaTokens.Layout.windowWidth, height: ChronaTokens.Layout.windowHeight)

            Window("Settings", id: ChronaWindowID.settings) {
                ChronaSettingsWindowView(store: settingsStore)
                    .environmentObject(chronaStore)
                    .preferredColorScheme(chronaStore.preferredColorScheme)
            }
            .defaultSize(width: 800, height: 620)
        }
    }
}

/// 供 Xcode App 目标或 `ChronaRunner` 可执行文件作为入口挂接的主场景。
public func chronaMainScene() -> some Scene {
    ChronaMainScene()
}
