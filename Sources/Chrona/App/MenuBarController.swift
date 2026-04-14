import AppKit
import SwiftUI

final class MainWindowOpener {
    static let shared = MainWindowOpener()
    private var openHandler: (() -> Void)?

    private init() {}

    func bind(_ handler: @escaping () -> Void) {
        openHandler = handler
    }

    func openMainWindow() {
        openHandler?()
    }
}

private enum ChronaMenuBarIcon {
    /// 菜单栏状态项内绘制尺寸（pt）；略小于 `squareLength` 留白，比 16pt 更易辨认。
    static let statusItemImagePoints: CGFloat = 24

    static func applicationIconForStatusItem() -> NSImage? {
        let raw = NSWorkspace.shared.icon(forFile: Bundle.main.bundleURL.path)
        let s = NSSize(width: statusItemImagePoints, height: statusItemImagePoints)
        return NSImage(size: s, flipped: false) { rect in
            raw.draw(
                in: rect,
                from: NSRect(origin: .zero, size: raw.size),
                operation: .copy,
                fraction: 1
            )
            return true
        }
    }
}

final class MenuBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?

    func installIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = ChronaMenuBarIcon.applicationIconForStatusItem()
            button.imagePosition = .imageOnly
            button.toolTip = "Chrona"
            button.target = self
            button.action = #selector(handleStatusItemClick)
        }
        statusItem = item
    }

    func activateExistingMainWindowIfPossible() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == ChronaWindowID.main }) {
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }
        MainWindowOpener.shared.openMainWindow()
    }

    @objc private func handleStatusItemClick() {
        activateExistingMainWindowIfPossible()
    }
}

extension View {
    func chronaBindMainWindowOpener() -> some View {
        modifier(MainWindowOpenerBinder())
    }

    func chronaBindMainWindowIdentity() -> some View {
        background(MainWindowIdentifierBinder())
    }
}

private struct MainWindowOpenerBinder: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            MainWindowOpener.shared.bind {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: ChronaWindowID.main)
            }
        }
    }
}

private struct MainWindowIdentifierBinder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.identifier = NSUserInterfaceItemIdentifier(ChronaWindowID.main)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.identifier = NSUserInterfaceItemIdentifier(ChronaWindowID.main)
            }
        }
    }
}
