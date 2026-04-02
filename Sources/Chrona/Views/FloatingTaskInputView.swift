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

// MARK: - PlaceholderTextView

/// NSTextView 子类：空内容时在 `textContainerOrigin` 处绘制占位符，
/// 与正文共用同一套文本布局坐标，对齐天然一致。
private final class PlaceholderTextView: NSTextView {
    var placeholderString: String = ""
    var placeholderColor: NSColor = .placeholderTextColor

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        needsDisplay = true
    }

    override func unmarkText() {
        super.unmarkText()
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !hasMarkedText(), !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? .systemFont(ofSize: FloatingInputMetrics.fontSize),
            .foregroundColor: placeholderColor,
        ]
        NSAttributedString(string: placeholderString, attributes: attrs)
            .draw(at: textContainerOrigin)
    }
}

// MARK: - AutoSizingTextView

struct AutoSizingTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    var placeholder: String = ""
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, calculatedHeight: $calculatedHeight, onSubmit: onSubmit)
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

        let tv = PlaceholderTextView()
        tv.delegate = context.coordinator
        tv.placeholderString = placeholder
        tv.placeholderColor = NSColor(ChronaTokens.Colors.subtext.opacity(0.55))
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

        scroll.documentView = tv
        context.coordinator.scrollView = scroll
        context.coordinator.textView = tv
        context.coordinator.recalculateHeightAndLayout()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        guard let tv = scroll.documentView as? PlaceholderTextView else { return }

        tv.placeholderString = placeholder

        if tv.string != text {
            if tv.hasMarkedText() {
                // 保留 NSTextView；textDidChange 会同步 binding。
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
                tv.needsDisplay = true
            }
        }

        context.coordinator.recalculateHeightAndLayout()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var calculatedHeight: Binding<CGFloat>
        var onSubmit: () -> Void
        weak var scrollView: NSScrollView?
        weak var textView: NSTextView?
        private var layoutWidthRetryCount = 0
        private var deferredRecalculateScheduled = false

        init(text: Binding<String>, calculatedHeight: Binding<CGFloat>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.calculatedHeight = calculatedHeight
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
            recalculateHeightAndLayout()
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSEvent.modifierFlags.contains(.shift) { return false }
                onSubmit()
                return true
            }
            return false
        }

        // MARK: Layout

        func recalculateHeightAndLayout() {
            guard let tv = textView, let scroll = scrollView,
                  let lm = tv.layoutManager, let tc = tv.textContainer
            else { return }

            let font = tv.font ?? .systemFont(ofSize: FloatingInputMetrics.fontSize)
            let lineH = ceil(lm.defaultLineHeight(for: font))
            let scrollH = scroll.bounds.height

            // 垂直居中不依赖宽度，即使首帧 width=0 也先把 inset 设好。
            applyCentering(tv: tv, contentH: lineH, scrollH: scrollH)

            let contentW = scroll.contentView.bounds.width
            let boundsW = scroll.bounds.width
            let tvW = tv.bounds.width
            let visibleWidth = max(1, floor(max(max(contentW, boundsW), tvW)))

            guard visibleWidth > 8 else {
                reportHeight(lineH)
                scheduleDeferredRecalculate()
                return
            }
            layoutWidthRetryCount = 0

            tc.containerSize = NSSize(width: visibleWidth, height: CGFloat.greatestFiniteMagnitude)
            lm.ensureLayout(for: tc)

            let rawContent = ceil(lm.usedRect(for: tc).height)
            let intrinsic = max(rawContent, lineH)
            reportHeight(intrinsic)

            applyCentering(tv: tv, contentH: intrinsic, scrollH: scrollH)

            tv.frame = NSRect(x: 0, y: 0, width: visibleWidth, height: max(intrinsic, scrollH))
            if scroll.documentView !== tv { scroll.documentView = tv }

            let len = (tv.string as NSString).length
            let caretAtEnd = tv.selectedRange().location >= len
            if intrinsic > scrollH + 0.5, caretAtEnd {
                tv.scrollRangeToVisible(NSRange(location: len, length: 0))
                DispatchQueue.main.async { [weak tv] in
                    guard let tv else { return }
                    tv.scrollRangeToVisible(NSRange(location: (tv.string as NSString).length, length: 0))
                }
            }
        }

        /// 用 `textContainerInset` 把内容在 scroll view 可视区域内垂直居中。
        /// placeholder 通过 `textContainerOrigin` 自动跟随同一偏移，天然对齐。
        private func applyCentering(tv: NSTextView, contentH: CGFloat, scrollH: CGFloat) {
            guard scrollH > 0 else { return }
            let frameH = max(contentH, scrollH)
            let inset = max(0, ceil((frameH - contentH) / 2))
            tv.textContainerInset = NSSize(width: 0, height: inset)
        }

        private func reportHeight(_ h: CGFloat) {
            guard abs(calculatedHeight.wrappedValue - h) >= 1 else { return }
            let binding = calculatedHeight
            DispatchQueue.main.async { binding.wrappedValue = h }
        }

        private func scheduleDeferredRecalculate() {
            guard layoutWidthRetryCount < 12, !deferredRecalculateScheduled else { return }
            layoutWidthRetryCount += 1
            deferredRecalculateScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.deferredRecalculateScheduled = false
                self.recalculateHeightAndLayout()
            }
        }
    }
}

// MARK: - FloatingTaskInputView

struct FloatingTaskInputView: View {
    @Binding var text: String
    var onSubmit: () -> Void

    @State private var calculatedHeight: CGFloat = FloatingInputMetrics.minHeight

    private var visibleTextHeight: CGFloat {
        min(max(calculatedHeight, FloatingInputMetrics.minHeight), FloatingInputMetrics.maxHeight)
    }

    private var containerHeight: CGFloat {
        visibleTextHeight + FloatingInputMetrics.verticalPadding * 2
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: FloatingInputMetrics.textButtonSpacing) {
                AutoSizingTextView(
                    text: $text,
                    calculatedHeight: $calculatedHeight,
                    placeholder: "Add task (e.g. 'Read docs for 45m')",
                    onSubmit: submit
                )
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
