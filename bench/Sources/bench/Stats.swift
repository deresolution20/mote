import Foundation

extension Array where Element == Double {
    var median: Double {
        guard !isEmpty else { return 0 }
        let s = sorted()
        let mid = count / 2
        return count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    var p90: Double {
        guard !isEmpty else { return 0 }
        let s = sorted()
        let rank = Int((Double(count - 1) * 0.9).rounded())
        return s[rank]
    }

    var mean: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}

func fmt(_ seconds: Double) -> String { String(format: "%.3f s", seconds) }
func fmtPct(_ fraction: Double) -> String { String(format: "%.1f%%", fraction * 100) }
