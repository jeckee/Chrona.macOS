import Chrona
import SwiftUI

@main
struct ChronaMacApp: App {
    @NSApplicationDelegateAdaptor(ChronaLifecycleDelegate.self) private var appDelegate

    var body: some Scene {
        chronaMainScene()
    }
}
