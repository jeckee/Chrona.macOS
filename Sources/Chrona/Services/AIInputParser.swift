import Foundation

enum AIInputParser {
    struct Parsed {
        var title: String
        var estimatedMinutes: Int
    }

    /// Lightweight “AI” style parsing for one-line task input.
    static func parse(_ raw: String) -> Parsed? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var title = trimmed
        var minutes = 30

        if let m = firstMatch(#"(\d+)\s*h(?:ours?)?(?:\s+(\d+)\s*m(?:in)?)?"#, in: trimmed, options: .caseInsensitive) {
            if let h = Int(m.strings[1]) {
                var total = h * 60
                if m.strings.count > 2, let mm = Int(m.strings[2]) {
                    total += mm
                }
                minutes = max(5, total)
                title = remove(m.fullRange, from: trimmed)
            }
        } else if let m = firstMatch(#"(\d+)\s*m(?:in)?(?:utes?)?"#, in: trimmed, options: .caseInsensitive) {
            if let mm = Int(m.strings[1]) {
                minutes = max(5, mm)
                title = remove(m.fullRange, from: trimmed)
            }
        }

        title = title
            .replacingOccurrences(of: #"\bfor\b"#, with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",.;"))

        if title.isEmpty { title = "New task" }
        return Parsed(title: title, estimatedMinutes: minutes)
    }

    private struct RegexMatch {
        let fullRange: Range<String.Index>
        let strings: [String]
    }

    private static func firstMatch(_ pattern: String, in text: String, options: NSRegularExpression.Options) -> RegexMatch? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let m = re.firstMatch(in: text, options: [], range: range) else { return nil }
        var strings: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            if r.location == NSNotFound {
                strings.append("")
            } else {
                strings.append(ns.substring(with: r))
            }
        }
        guard let swiftRange = Range(m.range, in: text) else { return nil }
        return RegexMatch(fullRange: swiftRange, strings: strings)
    }

    private static func remove(_ range: Range<String.Index>, from text: String) -> String {
        var t = text
        t.removeSubrange(range)
        return t
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
