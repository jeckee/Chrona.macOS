import Foundation

/// 本地存储服务协议，定义 Chrona 所有本地数据的读写接口。
/// 业务层通过此协议访问存储，不直接耦合文件系统实现。
protocol LocalStorageServiceProtocol {

    // MARK: - Tasks

    func loadTasks() throws -> [ChronaTask]
    func saveTasks(_ tasks: [ChronaTask]) throws

    // MARK: - Schedule Blocks

    func loadScheduleBlocks() throws -> [ScheduleBlock]
    func saveScheduleBlocks(_ blocks: [ScheduleBlock]) throws

    // MARK: - Settings

    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws

    // MARK: - Maintenance

    /// 清除所有本地数据文件，用于开发期重置。
    func clearAllData() throws
}
