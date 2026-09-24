import SwiftUI

// MARK: - Level

enum ScoreLevel: String, Codable, CaseIterable, Identifiable {
    case recyclable
    case review
    case junk
    case hazard

    var id: String { rawValue }

    init(score: Int) {
        switch score {
        case ..<25: self = .recyclable
        case 25..<50: self = .review
        case 50..<75: self = .junk
        default: self = .hazard
        }
    }

    var title: String {
        switch self {
        case .recyclable: "可回收"
        case .review: "待審"
        case .junk: "廢料"
        case .hazard: "危害級"
        }
    }

    var tint: Color {
        switch self {
        case .recyclable: .yardRecycle
        case .review: .yardInkMuted
        case .junk: .yardTerracotta
        case .hazard: .yardAmber
        }
    }

    /// Level is always conveyed by symbol + text as well as color, so the badge stays
    /// readable for color-blind users and in VoiceOver.
    var symbolName: String {
        switch self {
        case .recyclable: "leaf.fill"
        case .review: "magnifyingglass"
        case .junk: "exclamationmark.triangle.fill"
        case .hazard: "flame.fill"
        }
    }
}

// MARK: - Factors

/// One line in the score breakdown. `detail` is what makes the number defensible —
/// the detail page shows it verbatim so the app never says "trust me".
struct ScoreFactor: Identifiable, Hashable {
    var id = UUID()
    var label: String
    var points: Int
    var detail: String

    var isPenalty: Bool { points > 0 }
}

struct JunkScore {
    var value: Int
    var factors: [ScoreFactor]

    var level: ScoreLevel { ScoreLevel(score: value) }
}

// MARK: - Engine

/// A deliberately transparent, rule-based scorer. No model, no randomness — the same
/// item always produces the same explainable number.
enum JunkScoring {
    static let ageFreeDays = 180

    static func score(for item: JunkItem, medianSize: Int64) -> JunkScore {
        var factors: [ScoreFactor] = []

        if let days = item.ageInDays, days > ageFreeDays {
            // Reaches the 30-point ceiling at roughly 15 months, so a yard full of
            // year-old clutter reads as genuinely bad rather than mildly untidy.
            let points = min(30, (days - ageFreeDays) / 9)
            if points > 0 {
                factors.append(ScoreFactor(
                    label: "年紀太大",
                    points: points,
                    detail: "建立於 \(days) 天前，超過 \(ageFreeDays) 天的項目開始累積分數。"
                ))
            }
        }

        if item.twinGroup != nil {
            factors.append(ScoreFactor(
                label: "有雙胞胎",
                points: 25,
                detail: "偵測到同一組內還有其他極為相似的項目。"
            ))
        }

        if item.kind == .screenshot {
            factors.append(ScoreFactor(
                label: "是截圖",
                points: 18,
                detail: "截圖的用途壽命通常只有幾天。"
            ))
        }

        if item.hasMeaninglessName {
            factors.append(ScoreFactor(
                label: "檔名沒有意義",
                points: 18,
                detail: "「\(item.name)」看不出內容，日後幾乎不可能靠搜尋找到。"
            ))
        }

        if let size = item.byteSize, medianSize > 0, size > medianSize {
            let ratio = Double(size) / Double(medianSize)
            let points = min(10, Int((ratio - 1) * 6))
            if points > 0 {
                factors.append(ScoreFactor(
                    label: "體積偏大",
                    points: points,
                    detail: "\(YardFormat.bytes(size))，約為同類項目中位數的 \(String(format: "%.1f", ratio)) 倍。"
                ))
            }
        }

        if !item.hasPurposeTag {
            factors.append(ScoreFactor(
                label: "沒有用途標籤",
                points: 15,
                detail: "你從沒說明它是幹嘛用的。標記用途可以直接扣掉這筆分數。"
            ))
        } else {
            factors.append(ScoreFactor(
                label: "已標記用途",
                points: -40,
                detail: "你說它是「\(item.purposeTag ?? "")」，這是最強的保護。"
            ))
        }

        if item.verdict == .keep {
            factors.append(ScoreFactor(
                label: "你已決定保留",
                points: -40,
                detail: "已保留的項目不會再被送進打撈作業。"
            ))
        }

        let total = factors.reduce(0) { $0 + $1.points }
        let clamped = min(100, max(0, total))
        // Heaviest factors first: the breakdown should lead with the real reason.
        let ordered = factors.sorted { abs($0.points) > abs($1.points) }
        return JunkScore(value: clamped, factors: ordered)
    }
}
