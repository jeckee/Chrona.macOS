import AppKit
import SwiftUI

// MARK: - Tokens (integer layout for crisp rendering)

private enum FloatingInputMetrics {
    static let minHeight: CGFloat = 25
    static let maxHeight: CGFloat = minHeight * 5
    static let cornerRadius: CGFloat = 12
    static let horizontalPadding: CGFloat = 13
    static let verticalPadding: CGFloat = 10
    static let textButtonSpacing: CGFloat = 10
    static let fontSize: CGFloat = 15
}

// MARK: - AutoSizingTextView

struct AutoSizingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isComposingText: Bool
    /// 与 `NSTextView` 实际内容同步，用于占位符叠层：`text` 可能比视图晚一帧更新。
    @Binding var editorHasVisibleContent: Bool
    var onSubmit: () -> Void

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
        Coordinator(
            text: $text,
            calculatedHeight: $calculatedHeight,
            isComposingText: $isComposingText,
            editorHasVisibleContent: $editorHasVisibleContent,
            onSubmit: onSubmit
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = .init()
        scroll.scrollerInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 1)
        scroll.verticalScroller?.controlSize = .small

        let tv = CompositionAwareTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.drawsBackground = false
        tv.importsGraphics = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.font = .systemFont(ofSize: FloatingInputMetrics.fontSize)
        tv.textColor = NSColor(ChronaTokens.Colors.text)
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.heightTracksTextView = false
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.minSize = .zero
        tv.maxSize = NSSize(width: 10_000, height: 10_000)
        tv.focusRingType = .none
        tv.string = text
        tv.onCompositionStateChange = { [weak coordinator = context.coordinator, weak tv] _ in
            guard let coordinator, let tv else { return }
            coordinator.updateCompositionState(for: tv)
        }

        scroll.documentView = tv
        context.coordinator.scrollView = scroll
        context.coordinator.textView = tv

        context.coordinator.recalculateHeightAndLayout()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        guard let tv = scroll.documentView as? NSTextView else { return }

        if tv.string != text {
            // IME：标记文本已写入 tv，但 `text` 可能尚未更新，勿用旧 binding 覆盖。
            if tv.hasMarkedText() {
                // 保留 NSTextView；`textDidChange` 会同步 binding。
            } else {
                let selected = tv.selectedRange()
                tv.string = text
                let len = (text as NSString).length
                let loc = min(selected.location, len)
                tv.setSelectedRange(NSRange(location: loc, length: 0))
                if text.isEmpty {
                    tv.scrollToBeginningOfDocument(nil)
                } else {
                    tv.scrollToEndOfDocument(nil)
                }
            }
        }

        context.coordinator.syncEditorVisibleContent(for: tv)
        context.coordinator.updateCompositionState(for: tv)
        context.coordinator.recalculateHeightAndLayout()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var calculatedHeight: Binding<CGFloat>
        var isComposingText: Binding<Bool>
        var editorHasVisibleContent: Binding<Bool>
        var onSubmit: () -> Void
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?

        init(
            text: Binding<String>,
            calculatedHeight: Binding<CGFloat>,
            isComposingText: Binding<Bool>,
            editorHasVisibleContent: Binding<Bool>,
            onSubmit: @escaping () -> Void
        ) {
            self.text = text
            self.calculatedHeight = calculatedHeight
            self.isComposingText = isComposingText
            self.editorHasVisibleContent = editorHasVisibleContent
            self.onSubmit = onSubmit
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
            text.wrappedValue = tv.string
            syncEditorVisibleContent(for: tv)
            updateCompositionState(for: tv)
            recalculateHeightAndLayout()
        }

        func textDidEndEditing(_ notification: Notification) {
            isComposingText.wrappedValue = false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) {
                    return false
                }
                onSubmit()
                return true
            }
            return false
        }

        func recalculateHeightAndLayout() {
            guard let tv = textView, let scroll = scrollView,
                  let lm = tv.layoutManager, let tc = tv.textContainer
            else { return }

            let visibleWidth = max(1, floor(scroll.bounds.width))
            guard visibleWidth > 8 else { return }
            tc.containerSize = NSSize(width: visibleWidth, height: CGFloat.greatestFiniteMagnitude)

            lm.ensureLayout(for: tc)
            let used = lm.usedRect(for: tc)
            let font = tv.font ?? .systemFont(ofSize: FloatingInputMetrics.fontSize)
            let lineH = ceil(lm.defaultLineHeight(for: font))
            let rawContent = ceil(used.height)
            let intrinsic = max(rawContent, lineH)

            let visible = min(
                max(intrinsic, FloatingInputMetrics.minHeight),
                FloatingInputMetrics.maxHeight
            )
            let documentH = max(intrinsic, visible)

            let current = calculatedHeight.wrappedValue
            if abs(current - intrinsic) >= 1 {
                let binding = calculatedHeight
                DispatchQueue.main.async {
                    binding.wrappedValue = intrinsic
                }
            }

            // 单行 / 空内容时 intrinsic 小于 documentH（受 minHeight 限制），否则首行贴顶、插入点不垂直居中。
            let verticalInset = max(0, (documentH - intrinsic) / 2)
            tv.textContainerInset = NSSize(width: 0, height: verticalInset)

            let len = (tv.string as NSString).length
            let caretAtEnd = tv.selectedRange().location >= len

            tv.frame = NSRect(x: 0, y: 0, width: visibleWidth, height: documentH)
            if scroll.documentView !== tv {
                scroll.documentView = tv
            }

            if documentH > visible + 0.5, caretAtEnd {
                let endRange = NSRange(location: len, length: 0)
                tv.scrollRangeToVisible(endRange)
                DispatchQueue.main.async { [weak tv] in
                    guard let tv else { return }
                    let n = (tv.string as NSString).length
                    tv.scrollRangeToVisible(NSRange(location: n, length: 0))
                }
            }
        }

        func updateCompositionState(for textView: NSTextView) {
            let isComposing = textView.hasMarkedText()
            if isComposingText.wrappedValue != isComposing {
                isComposingText.wrappedValue = isComposing
            }
        }

        func syncEditorVisibleContent(for textView: NSTextView) {
            let visible = !textView.string.isEmpty || textView.hasMarkedText()
            if editorHasVisibleContent.wrappedValue != visible {
                editorHasVisibleContent.wrappedValue = visible
            }
        }
    }
}

// MARK: - FloatingTaskInputView

struct FloatingTaskInputView: View {
    @Binding var text: String
    var onSubmit: () -> Void

    @State private var calculatedHeight: CGFloat = FloatingInputMetrics.minHeight
    @State private var isComposingText = false
    @State private var editorHasVisibleContent = false

    private var visibleTextHeight: CGFloat {
        min(
            max(calculatedHeight, FloatingInputMetrics.minHeight),
            FloatingInputMetrics.maxHeight
        )
    }

    private var containerHeight: CGFloat {
        visibleTextHeight + FloatingInputMetrics.verticalPadding * 2
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 与 `AutoSizingTextView` 里 `textContainerInset` 的上边距一致，占位符与首行垂直对齐。
    private var centeredSingleLineTopPadding: CGFloat {
        let intrinsic = calculatedHeight
        let minH = FloatingInputMetrics.minHeight
        let maxH = FloatingInputMetrics.maxHeight
        let visible = min(max(intrinsic, minH), maxH)
        let documentH = max(intrinsic, visible)
        return max(0, (documentH - intrinsic) / 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: FloatingInputMetrics.textButtonSpacing) {
                ZStack(alignment: .topLeading) {
                    AutoSizingTextView(
                        text: $text,
                        calculatedHeight: $calculatedHeight,
                        isComposingText: $isComposingText,
                        editorHasVisibleContent: $editorHasVisibleContent,
                        onSubmit: submit
                    )
                    if !editorHasVisibleContent && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add task (e.g. 'Read docs for 45m')")
                            .font(.system(size: FloatingInputMetrics.fontSize, weight: .regular))
                            .foregroundStyle(ChronaTokens.Colors.subtext.opacity(0.55))
                            .allowsHitTesting(false)
                            .padding(.top, centeredSingleLineTopPadding + 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: visibleTextHeight)

                if canSubmit {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.chronaSendSquare)
                }
            }
            .padding(.horizontal, FloatingInputMetrics.horizontalPadding)
            .padding(.vertical, FloatingInputMetrics.verticalPadding)
            .frame(height: containerHeight)
            .background {
                RoundedRectangle(cornerRadius: FloatingInputMetrics.cornerRadius, style: .continuous)
                    .fill(ChronaTokens.Colors.bgSoft)
            }
            .overlay {
                RoundedRectangle(cornerRadius: FloatingInputMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(ChronaTokens.Colors.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: FloatingInputMetrics.cornerRadius, style: .continuous))

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
                Text("AI will auto-assign duration and schedule")
                    .font(.system(size: ChronaTokens.Typography.Size.accessory, weight: .regular))
                    .foregroundStyle(ChronaTokens.Colors.subtext)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChronaTokens.Colors.bg)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit()
    }
}
