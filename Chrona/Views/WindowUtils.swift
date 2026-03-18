import SwiftUI
import AppKit

/// Bridges SwiftUI view hierarchy to the hosting `NSWindow`.
struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { [weak nsView] in
            guard let window = nsView?.window else { return }
            onResolve(window)
        }
    }
}

enum WindowIDs {
    static let main = "main"
}

@MainActor
enum WindowManager {
    static func bringToFront(id: String) -> Bool {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == id }) else {
            return false
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
    }
}
