import Foundation

@MainActor
final class VerifiedDeliveryStore {
    static let shared = VerifiedDeliveryStore()

    private static let storageKey = "mote.verifiedDeliveryMethods.v1"
    private static let maximumRecords = 128

    private let defaults: UserDefaults
    private var records: [DeliverySurfaceKey: DeliveryMethod]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(
               [DeliverySurfaceKey: DeliveryMethod].self,
               from: data
           ) {
            records = decoded
        } else {
            records = [:]
        }
    }

    func preferredMethod(for key: DeliverySurfaceKey) -> DeliveryMethod? {
        records[key]
    }

    func recordVerified(_ method: DeliveryMethod, for key: DeliverySurfaceKey) {
        guard method == .directEvents || method == .clipboard else { return }
        if records[key] == nil,
           records.count >= Self.maximumRecords,
           let oldestArbitraryKey = records.keys.first {
            records.removeValue(forKey: oldestArbitraryKey)
        }
        records[key] = method
        persist()
    }

    func reset() {
        records = [:]
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
