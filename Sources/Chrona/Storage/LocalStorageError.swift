import Foundation

/// Chrona 本地存储层专用错误类型。
/// 包装底层系统错误，提供清晰的语义信息便于上层处理和调试。
enum LocalStorageError: Error, LocalizedError {

    /// 无法定位 Application Support 目录。
    case appSupportDirectoryNotFound

    /// 创建 Chrona 数据目录失败。
    case directoryCreationFailed(underlying: Error)

    /// 从磁盘读取文件失败。
    case fileReadFailed(filename: String, underlying: Error)

    /// 将数据写入磁盘失败。
    case fileWriteFailed(filename: String, underlying: Error)

    /// JSON 解码失败。
    case decodingFailed(filename: String, underlying: Error)

    /// JSON 编码失败。
    case encodingFailed(filename: String, underlying: Error)

    /// 删除文件失败。
    case fileDeletionFailed(filename: String, underlying: Error)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .appSupportDirectoryNotFound:
            return "无法定位 Application Support 目录"
        case .directoryCreationFailed(let underlying):
            return "创建 Chrona 数据目录失败: \(underlying.localizedDescription)"
        case .fileReadFailed(let filename, let underlying):
            return "读取 \(filename) 失败: \(underlying.localizedDescription)"
        case .fileWriteFailed(let filename, let underlying):
            return "写入 \(filename) 失败: \(underlying.localizedDescription)"
        case .decodingFailed(let filename, let underlying):
            return "解码 \(filename) 失败: \(underlying.localizedDescription)"
        case .encodingFailed(let filename, let underlying):
            return "编码 \(filename) 失败: \(underlying.localizedDescription)"
        case .fileDeletionFailed(let filename, let underlying):
            return "删除 \(filename) 失败: \(underlying.localizedDescription)"
        }
    }
}
