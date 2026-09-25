import Foundation
import MoteCleanup

@MainActor
final class MotePreferences: ObservableObject {
    @Published var outputFormat: OutputFormat { didSet { save(outputFormat.rawValue, for: .outputFormat) } }
    @Published var captureMode: CaptureMode { didSet { save(captureMode.rawValue, for: .captureMode) } }
    @Published var hotkeyConfiguration: HotkeyConfiguration { didSet { saveHotkeyConfiguration() } }
    @Published var autoInsert: Bool { didSet { save(autoInsert, for: .autoInsert) } }
    @Published var modelDownloadsApproved: Bool { didSet { save(modelDownloadsApproved, for: .modelDownloadsApproved) } }
    @Published var cleanupEnabled: Bool { didSet { save(cleanupEnabled, for: .cleanupEnabled) } }
    @Published var hudEnabled: Bool { didSet { save(hudEnabled, for: .hudEnabled) } }
    @Published var deliveryMode: DeliveryMode { didSet { save(deliveryMode.rawValue, for: .deliveryMode) } }
    @Published var preserveCodeAndBackticks: Bool { didSet { save(preserveCodeAndBackticks, for: .preserveCodeAndBackticks) } }
    @Published var selectedMicrophoneDeviceID: UInt32? { didSet { saveSelectedMicrophoneDeviceID() } }

    private let defaults: UserDefaults

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: MoteV1Migration.legacyBundleIdentifier)
    ) {
        self.defaults = defaults
        MoteV1Migration.migratePreferences(current: defaults, legacy: legacyDefaults)
        outputFormat = OutputFormat(rawValue: defaults.string(forKey: Key.outputFormat.rawValue) ?? "") ?? .plain
        captureMode = CaptureMode(rawValue: defaults.string(forKey: Key.captureMode.rawValue) ?? "") ?? .holdToTalk
        hotkeyConfiguration = Self.hotkeyConfiguration(from: defaults) ?? .default
        autoInsert = Self.bool(defaults, key: .autoInsert, fallback: false)
        modelDownloadsApproved = Self.bool(defaults, key: .modelDownloadsApproved, fallback: false)
        cleanupEnabled = Self.bool(defaults, key: .cleanupEnabled, fallback: true)
        hudEnabled = Self.bool(defaults, key: .hudEnabled, fallback: true)
        deliveryMode = Self.deliveryMode(from: defaults)
        preserveCodeAndBackticks = Self.bool(defaults, key: .preserveCodeAndBackticks, fallback: false)
        selectedMicrophoneDeviceID = Self.selectedMicrophoneDeviceID(from: defaults)
        if defaults.object(forKey: Key.deliveryMode.rawValue) == nil {
            defaults.set(deliveryMode.rawValue, forKey: Key.deliveryMode.rawValue)
        }
    }

    private enum Key: String {
        case outputFormat = "mote.outputFormat"
        case captureMode = "mote.captureMode"
        case hotkeyConfiguration = "mote.hotkeyConfiguration"
        case autoInsert = "mote.autoInsert"
        case modelDownloadsApproved = "mote.modelDownloadsApproved"
        case cleanupEnabled = "mote.cleanupEnabled"
        case hudEnabled = "mote.hudEnabled"
        case injectByTyping = "mote.injectByTyping"
        case deliveryMode = "mote.deliveryMode"
        case preserveCodeAndBackticks = "mote.preserveCodeAndBackticks"
        case selectedMicrophoneDeviceID = "mote.selectedMicrophoneDeviceID"
    }

    private static func bool(_ defaults: UserDefaults, key: Key, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key.rawValue) != nil else { return fallback }
        return defaults.bool(forKey: key.rawValue)
    }

    private static func deliveryMode(from defaults: UserDefaults) -> DeliveryMode {
        if let rawValue = defaults.string(forKey: Key.deliveryMode.rawValue),
           let mode = DeliveryMode(rawValue: rawValue) {
            return mode
        }
        guard defaults.object(forKey: Key.injectByTyping.rawValue) != nil else {
            return .automatic
        }
        return defaults.bool(forKey: Key.injectByTyping.rawValue) ? .privacyFirst : .compatibility
    }

    private func save(_ value: Any, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    private static func hotkeyConfiguration(from defaults: UserDefaults) -> HotkeyConfiguration? {
        guard let data = defaults.data(forKey: Key.hotkeyConfiguration.rawValue) else { return nil }
        return try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
    }

    private func saveHotkeyConfiguration() {
        guard let data = try? JSONEncoder().encode(hotkeyConfiguration) else { return }
        defaults.set(data, forKey: Key.hotkeyConfiguration.rawValue)
    }

    private static func selectedMicrophoneDeviceID(from defaults: UserDefaults) -> UInt32? {
        guard let value = defaults.object(forKey: Key.selectedMicrophoneDeviceID.rawValue) as? NSNumber else {
            return nil
        }
        return value.uint32Value
    }

    private func saveSelectedMicrophoneDeviceID() {
        guard let selectedMicrophoneDeviceID else {
            defaults.removeObject(forKey: Key.selectedMicrophoneDeviceID.rawValue)
            return
        }
        defaults.set(selectedMicrophoneDeviceID, forKey: Key.selectedMicrophoneDeviceID.rawValue)
    }
}
