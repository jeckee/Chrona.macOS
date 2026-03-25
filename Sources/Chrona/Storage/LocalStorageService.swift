import Foundation

/// 基于 JSON 文件的本地存储服务实现。
/// 所有读写操作均为同步，调用方可根据需要在后台线程调度。
final class LocalStorageService: LocalStorageServiceProtocol {

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fm: FileManager

    init(fileManager: FileManager = .default) {
        self.fm = fileManager

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = enc

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    // MARK: - Tasks

    func loadTasks() throws -> [ChronaTask] {
        try load(from: AppFileManager.tasksFileName, defaultValue: [])
    }

    func saveTasks(_ tasks: [ChronaTask]) throws {
        try save(tasks, to: AppFileManager.tasksFileName)
    }

    // MARK: - Schedule Blocks

    func loadScheduleBlocks() throws -> [ScheduleBlock] {
        try load(from: AppFileManager.scheduleBlocksFileName, defaultValue: [])
    }

    func saveScheduleBlocks(_ blocks: [ScheduleBlock]) throws {
        try save(blocks, to: AppFileManager.scheduleBlocksFileName)
    }

    // MARK: - Settings

    func loadSettings() throws -> AppSettings {
        try load(from: AppFileManager.settingsFileName, defaultValue: .default)
    }

    func saveSettings(_ settings: AppSettings) throws {
        try save(settings, to: AppFileManager.settingsFileName)
    }

    // MARK: - Daily Summary

    func loadDailySummary(for date: Date) throws -> DailySummary? {
        let normalized = Calendar.current.startOfDay(for: date)
        let summaries: [DailySummary] = try load(
            from: AppFileManager.dailySummariesFileName,
            defaultValue: []
        )
        let matches = summaries.filter { Calendar.current.isDate($0.date, inSameDayAs: normalized) }
        return matches.max { $0.generatedAt < $1.generatedAt }
    }

    func saveDailySummary(_ summary: DailySummary) throws {
        var summaries: [DailySummary] = try load(
            from: AppFileManager.dailySummariesFileName,
            defaultValue: []
        )

        let normalized = Calendar.current.startOfDay(for: summary.date)
        summaries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: normalized) }
        summaries.append(DailySummary(date: normalized, content: summary.content, generatedAt: summary.generatedAt))

        try save(summaries, to: AppFileManager.dailySummariesFileName)
    }

    // MARK: - Maintenance

    func clearAllData() throws {
        for filename in AppFileManager.allFileNames {
            let url = try AppFileManager.fileURL(for: filename)
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                try fm.removeItem(at: url)
            } catch {
                throw LocalStorageError.fileDeletionFailed(
                    filename: filename, underlying: error
                )
            }
        }
    }

    // MARK: - Generic Read / Write

    private func load<T: Decodable>(
        from filename: String,
        defaultValue: T
    ) throws -> T {
        let url = try AppFileManager.fileURL(for: filename)

        guard fm.fileExists(atPath: url.path) else {
            return defaultValue
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw LocalStorageError.fileReadFailed(
                filename: filename, underlying: error
            )
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LocalStorageError.decodingFailed(
                filename: filename, underlying: error
            )
        }
    }

    private func save<T: Encodable>(_ value: T, to filename: String) throws {
        try AppFileManager.ensureDirectoryExists()

        let url = try AppFileManager.fileURL(for: filename)

        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw LocalStorageError.encodingFailed(
                filename: filename, underlying: error
            )
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw LocalStorageError.fileWriteFailed(
                filename: filename, underlying: error
            )
        }
    }
}
