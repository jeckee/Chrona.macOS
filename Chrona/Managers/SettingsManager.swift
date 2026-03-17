import Foundation
import SwiftUI

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @AppStorage("workingBlocks") private var workingBlocksData: Data = Data()
    @AppStorage("notifyLeadMinutes") var notifyLeadMinutes: Int = 5
    @AppStorage("autoSummaryEnabled") var autoSummaryEnabled: Bool = true
    @AppStorage("autoSummaryTime") var autoSummaryTime: String = "20:00"
    @AppStorage("qwenAPIKey") var qwenAPIKey: String = ""

    @Published var workingBlocks: [WorkingBlock] = []

    private init() {
        loadWorkingBlocks()
        if workingBlocks.isEmpty {
            // 默认工作时间段
            workingBlocks = [
                WorkingBlock(start: "09:00", end: "12:00"),
                WorkingBlock(start: "14:00", end: "18:00")
            ]
            saveWorkingBlocks()
        }
    }

    // MARK: - Working Blocks
    func loadWorkingBlocks() {
        if let blocks = try? JSONDecoder().decode([WorkingBlock].self, from: workingBlocksData) {
            workingBlocks = blocks
        }
    }

    func saveWorkingBlocks() {
        if let data = try? JSONEncoder().encode(workingBlocks) {
            workingBlocksData = data
        }
    }

    // MARK: - API Key
    var hasAPIKey: Bool {
        !qwenAPIKey.isEmpty
    }
}

// MARK: - Working Block Model
struct WorkingBlock: Identifiable, Codable {
    let id: UUID
    var start: String // HH:mm
    var end: String   // HH:mm

    init(id: UUID = UUID(), start: String, end: String) {
        self.id = id
        self.start = start
        self.end = end
    }

    func toDateRange(on date: Date) -> (start: Date, end: Date)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        guard let startTime = formatter.date(from: start),
              let endTime = formatter.date(from: end) else {
            return nil
        }

        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        guard let startDate = calendar.date(bySettingHour: startComponents.hour!, minute: startComponents.minute!, second: 0, of: date),
              let endDate = calendar.date(bySettingHour: endComponents.hour!, minute: endComponents.minute!, second: 0, of: date) else {
            return nil
        }

        return (startDate, endDate)
    }
}
