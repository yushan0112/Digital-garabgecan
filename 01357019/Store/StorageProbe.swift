import Foundation

/// Device-wide storage numbers, which are the only storage figures iOS actually lets an
/// app read. We deliberately do not expose per-app usage, because that API does not exist.
struct StorageSnapshot {
    var totalCapacity: Int64?
    var availableCapacity: Int64?

    var usedCapacity: Int64? {
        guard let totalCapacity, let availableCapacity else { return nil }
        return max(0, totalCapacity - availableCapacity)
    }

    var usedFraction: Double? {
        guard let totalCapacity, totalCapacity > 0, let usedCapacity else { return nil }
        return Double(usedCapacity) / Double(totalCapacity)
    }

    var isReadable: Bool { totalCapacity != nil && availableCapacity != nil }

    static let unreadable = StorageSnapshot(totalCapacity: nil, availableCapacity: nil)
}

enum StorageProbe {
    static func snapshot() -> StorageSnapshot {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            return StorageSnapshot(
                totalCapacity: values.volumeTotalCapacity.map(Int64.init),
                availableCapacity: values.volumeAvailableCapacityForImportantUsage
            )
        } catch {
            return .unreadable
        }
    }
}
