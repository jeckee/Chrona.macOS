import AppKit

public final class ChronaLifecycleDelegate: NSObject, NSApplicationDelegate {
    public override init() {
        super.init()
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
