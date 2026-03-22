import AppKit
import SwiftUI

@MainActor
final class NoteEditingController: ObservableObject {
    weak var textView: NSTextView?

    func wrapSelectionWithBoldMarkers() {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        let s = tv.string as NSString
        let sel = range.length > 0 ? s.substring(with: range) : ""
        let replacement = "**" + (sel.isEmpty ? "text" : sel) + "**"
        tv.insertText(replacement, replacementRange: range)
        if sel.isEmpty {
            let newPos = range.location + 2
            tv.setSelectedRange(NSRange(location: newPos, length: 4))
        }
        tv.didChangeText()
    }

    func insertBulletAtCurrentLine() {
        guard let tv = textView else { return }
        let s = tv.string as NSString
        let range = tv.selectedRange()
        var lineStart = 0
        var idx = 0
        while idx < range.location && idx < s.length {
            if s.character(at: idx) == UInt16(UnicodeScalar("\n").value) {
                lineStart = idx + 1
            }
            idx += 1
        }
        tv.insertText("- ", replacementRange: NSRange(location: lineStart, length: 0))
        tv.didChangeText()
    }
}
