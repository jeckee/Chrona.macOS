import AppKit
import SwiftUI

struct AppKitTextEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: NoteEditingController

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AppKitTextEditor

        init(_ parent: AppKitTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.drawsBackground = false
        tv.font = .systemFont(ofSize: ChronaTokens.Typography.editorPointSize)
        tv.textColor = NSColor(ChronaTokens.Colors.text)
        tv.textContainerInset = NSSize(width: ChronaTokens.Card.padding, height: ChronaTokens.Card.padding)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
        tv.string = text

        scroll.documentView = tv
        controller.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        controller.textView = tv

        if tv.string != text {
            let selected = tv.selectedRange()
            tv.string = text
            let len = (text as NSString).length
            let loc = min(selected.location, len)
            tv.setSelectedRange(NSRange(location: loc, length: 0))
        }
    }
}
