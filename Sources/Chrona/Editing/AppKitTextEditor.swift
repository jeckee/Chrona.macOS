import AppKit
import SwiftUI

struct AppKitTextEditor: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var controller: NoteEditingController
    var isComposingText: Binding<Bool>? = nil
    var editorHasVisibleContent: Binding<Bool>? = nil
    var onCommit: (() -> Void)? = nil

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AppKitTextEditor
        weak var textView: NSTextView?

        init(_ parent: AppKitTextEditor) {
            self.parent = parent
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tv = self.textView else { return }
                self.syncEditorVisibleContent(for: tv)
            }
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            syncEditorVisibleContent(for: tv)
            updateCompositionState(for: tv)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isComposingText?.wrappedValue = false
            if let tv = notification.object as? NSTextView {
                syncEditorVisibleContent(for: tv)
            }
            parent.onCommit?()
        }

        func updateCompositionState(for textView: NSTextView) {
            guard let isComposingText = parent.isComposingText else { return }
            let composing = textView.hasMarkedText()
            if isComposingText.wrappedValue != composing {
                isComposingText.wrappedValue = composing
            }
        }

        func syncEditorVisibleContent(for textView: NSTextView) {
            guard let binding = parent.editorHasVisibleContent else { return }
            let visible = !textView.string.isEmpty || textView.hasMarkedText()
            if binding.wrappedValue != visible {
                binding.wrappedValue = visible
            }
        }
    }

    final class CompositionAwareTextView: NSTextView {
        var onCompositionStateChange: ((Bool) -> Void)?

        override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
            super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
            onCompositionStateChange?(true)
        }

        override func unmarkText() {
            super.unmarkText()
            onCompositionStateChange?(false)
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

        let tv = CompositionAwareTextView()
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
        tv.onCompositionStateChange = { [weak coordinator = context.coordinator, weak tv] _ in
            guard let coordinator, let tv else { return }
            coordinator.updateCompositionState(for: tv)
        }

        scroll.documentView = tv
        context.coordinator.textView = tv
        controller.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.textView = tv
        controller.textView = tv

        if tv.string != text {
            if tv.hasMarkedText() {
                // 同上：IME 期间勿用滞后的 binding 覆盖。
            } else {
                let selected = tv.selectedRange()
                tv.string = text
                let len = (text as NSString).length
                let loc = min(selected.location, len)
                tv.setSelectedRange(NSRange(location: loc, length: 0))
            }
        }
        context.coordinator.syncEditorVisibleContent(for: tv)
        context.coordinator.updateCompositionState(for: tv)
    }
}
