import Foundation

enum MoteV1Migration {
    static let legacyBundleIdentifier = "dev.brice.localflow"
    static let legacyApplicationSupportDirectoryName = "Grotdown"
    static let currentApplicationSupportDirectoryName = "Mote"

    private static let preferenceMigrationMarker = "mote.migration.grotdownPreferences.v1"
    private static let preferenceKeyPairs: [(legacy: String, current: String)] = [
        ("grotdown.outputFormat", "mote.outputFormat"),
        ("grotdown.captureMode", "mote.captureMode"),
        ("grotdown.hotkeyConfiguration", "mote.hotkeyConfiguration"),
        ("grotdown.autoInsert", "mote.autoInsert"),
        ("grotdown.modelDownloadsApproved", "mote.modelDownloadsApproved"),
        ("grotdown.cleanupEnabled", "mote.cleanupEnabled"),
        ("grotdown.hudEnabled", "mote.hudEnabled"),
        ("grotdown.injectByTyping", "mote.injectByTyping"),
        ("grotdown.preserveCodeAndBackticks", "mote.preserveCodeAndBackticks"),
        ("grotdown.selectedMicrophoneDeviceID", "mote.selectedMicrophoneDeviceID")
    ]

    static func migratePreferences(current: UserDefaults, legacy: UserDefaults?) {
        guard current.object(forKey: preferenceMigrationMarker) == nil else { return }

        if let legacy {
            for pair in preferenceKeyPairs where current.object(forKey: pair.current) == nil {
                guard let value = legacy.object(forKey: pair.legacy) else { continue }
                current.set(value, forKey: pair.current)
            }
        }

        current.set(true, forKey: preferenceMigrationMarker)
    }

    static func defaultStoreURLs(
        filename: String,
        fileManager: FileManager = .default
    ) -> (current: URL, legacy: URL) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let currentDirectory = applicationSupport
            .appendingPathComponent(currentApplicationSupportDirectoryName, isDirectory: true)
        let legacyDirectory = applicationSupport
            .appendingPathComponent(legacyApplicationSupportDirectoryName, isDirectory: true)
        return (
            currentDirectory.appendingPathComponent(filename),
            legacyDirectory.appendingPathComponent(filename)
        )
    }

    static func copyLegacyFileIfNeeded(
        from legacyURL: URL,
        to currentURL: URL,
        fileManager: FileManager = .default
    ) throws {
        guard !fileManager.fileExists(atPath: currentURL.path) else { return }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: legacyURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        try fileManager.copyItem(at: legacyURL, to: currentURL)
    }
}
