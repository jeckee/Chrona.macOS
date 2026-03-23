import Foundation

/// 管理 Chrona 的本地文件存储目录和路径（Application Support/Chrona/）。
/// 所有文件路径获取逻辑集中于此，其他模块不应自行拼接路径。
enum AppFileManager {

    static let directoryName = "Chrona"

    // MARK: - File Names

    static let tasksFileName = "tasks.json"
    static let scheduleBlocksFileName = "schedule_blocks.json"
    static let settingsFileName = "settings.json"

    // MARK: - Directory

    /// Application Support/Chrona/ 目录 URL。
    /// 若系统无法提供 Application Support 路径则抛出错误。
    static func appSupportDirectory() throws -> URL {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw LocalStorageError.appSupportDirectoryNotFound
        }
        return base.appendingPathComponent(directoryName)
    }

    /// 确保 Application Support/Chrona/ 目录存在，不存在则创建。
    @discardableResult
    static func ensureDirectoryExists() throws -> URL {
        let dir = try appSupportDirectory()
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true
                )
            } catch {
                throw LocalStorageError.directoryCreationFailed(underlying: error)
            }
        }
        return dir
    }

    /// 获取指定文件名在 Chrona 存储目录下的完整路径。
    static func fileURL(for filename: String) throws -> URL {
        try appSupportDirectory().appendingPathComponent(filename)
    }

    /// 所有受管理的 JSON 文件名列表。
    static var allFileNames: [String] {
        [tasksFileName, scheduleBlocksFileName, settingsFileName]
    }
}
