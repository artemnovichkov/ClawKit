import Foundation
import Observation

/// The prizes you've won so far. Survives relaunches.
@Observable
final class PrizeShelf {
    private(set) var counts: [PrizeKind: Int]

    private static let key = "PrizeShelf.counts"

    init() {
        let data = UserDefaults.standard.data(forKey: Self.key)
        counts = data.flatMap { try? JSONDecoder().decode([PrizeKind: Int].self, from: $0) } ?? [:]
    }

    var total: Int {
        counts.values.reduce(0, +)
    }

    var uniqueCount: Int {
        counts.count { $0.value > 0 }
    }

    func count(of kind: PrizeKind) -> Int {
        counts[kind, default: 0]
    }

    func add(_ kind: PrizeKind) {
        counts[kind, default: 0] += 1
        if let data = try? JSONEncoder().encode(counts) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
