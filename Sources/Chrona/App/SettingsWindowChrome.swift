import AppKit
import SwiftUI

/// 设置窗口：无标题栏条、内容延伸至顶部；交通灯仅保留关闭。
private final class SettingsWindowChromeHostView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

private struct SettingsWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        SettingsWindowChromeHostView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    /// 设置窗口专用：隐藏标题栏、仅保留关闭按钮、可从背景拖动窗口。
    func chronaSettingsWindowChrome() -> some View {
        overlay(alignment: .topLeading) {
            SettingsWindowChrome()
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
        }
    }
}
