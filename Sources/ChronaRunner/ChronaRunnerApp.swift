import Chrona
import SwiftUI

@main
struct ChronaRunnerApp: App {
    @NSApplicationDelegateAdaptor(ChronaLifecycleDelegate.self) private var appDelegate

    var body: some Scene {
        chronaMainScene()
    }
}
