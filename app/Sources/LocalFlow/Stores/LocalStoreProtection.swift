import Foundation

enum LocalStoreProtection {
    private static let directoryPermissions = 0o700
    private static let filePermissions = 0o600

    static func prepareDirectory(at directory: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: directoryPermissions]
        )
        try fileManager.setAttributes(
            [.posixPermissions: directoryPermissions],
            ofItemAtPath: directory.path
        )
        try excludeFromBackup(directory)
    }

    static func protectFile(at fileURL: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.setAttributes(
            [.posixPermissions: filePermissions],
            ofItemAtPath: fileURL.path
        )
        try excludeFromBackup(fileURL)
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var protectedURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedURL.setResourceValues(values)
    }
}
