import Foundation

enum SummaryPromptBuilder {
    struct SummaryTaskInput: Encodable {
        let taskId: String
        let title: String
        let status: String
        let isScheduled: Bool
        let priority: String
        let estimatedMinutes: Int?
        let conclusion: String

        init(task: ChronaTask) {
            self.taskId = task.id.uuidString
            self.title = task.title
            self.status = task.status.rawValue
            self.isScheduled = task.isScheduled
            self.priority = task.priority.rawValue
            self.estimatedMinutes = task.estimatedMinutes
            self.conclusion = task.conclusion ?? ""
        }
    }

    static func buildPrompt(date: Date, tasks: [ChronaTask]) throws -> String {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let dateText = Self.isoDateOnlyFormatter.string(from: normalizedDate)

        let inputTasks = tasks.map(SummaryTaskInput.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let inputData = try encoder.encode(inputTasks)
        guard let tasksJson = String(data: inputData, encoding: .utf8) else {
            throw TaskSchedulingServiceError.invalidPromptInput
        }

        // Output must be plain text (not JSON/Markdown), with a fixed five-section structure.
        return """
You are a work assistant. Based on the input data, generate a "daily summary" for the specified date. Follow the rules strictly: use only the provided input and do not invent facts or details.

Date: \(dateText)

[OUTPUT STRUCTURE]
Your output must contain exactly these 5 sections in order, each starting with the section title followed by a colon on its own line:

Completed Today:
Not Completed Today:
Key Progress:
Risks / Blockers:
Suggestions for Tomorrow:

[CLASSIFICATION RULES]
• Tasks with status "done" belong to "Completed Today". All others ("todo" / "inProgress" / "paused") belong to "Not Completed Today".
• You may use each task title and status to organize the summary, but do not add facts beyond the input.
• If "conclusion" is an empty string (or missing), still classify by status, but do not infer specific progress or blockers from an empty conclusion.

[KEY CONTENT EXTRACTION]
• "Key Progress": prioritize concrete "what was done / how far it moved" from conclusion. If all conclusions are empty, give brief direction based on titles and statuses of incomplete tasks (without inventing details).
• "Risks / Blockers": summarize issues such as problems, being stuck, pending continuation, or collaboration needs when indicated in conclusion.
• "Suggestions for Tomorrow": propose concise, actionable next steps based on "Not Completed Today" and "Risks / Blockers".

[STYLE RULES]
• Language: English only.
• Keep it concise and clear, in a work-summary style.
• ABSOLUTELY NO Markdown syntax: no #, no **, no *, no `, no ---, no numbered lists (1. 2. 3.).
• Each section should contain 3 to 6 bullet points. Use "• " (bullet dot + space) at the start of each point.
• Do not output JSON, code blocks, or extra explanations.

[INPUT DATA]
\(tasksJson)
"""
    }

    private static let isoDateOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

