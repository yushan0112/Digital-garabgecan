import SwiftUI

// MARK: - Kind

enum JunkKind: String, Codable, CaseIterable, Identifiable {
    case screenshot
    case photo
    case document
    case download
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshot: "截圖"
        case .photo: "照片"
        case .document: "文件"
        case .download: "下載"
        case .unknown: "不明"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshot: "rectangle.dashed"
        case .photo: "photo"
        case .document: "doc.text"
        case .download: "arrow.down.circle"
        case .unknown: "questionmark.square.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .screenshot: .yardTerracotta
        case .photo: .yardRecycle
        case .document: .yardAmber
        case .download: .yardInkMuted
        case .unknown: .yardInkMuted
        }
    }
}

// MARK: - Verdict

enum Verdict: String, Codable, CaseIterable, Identifiable {
    case keep
    case archive
    case remove
    case skip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: "保留"
        case .archive: "封存"
        case .remove: "移除"
        case .skip: "跳過"
        }
    }

    var symbolName: String {
        switch self {
        case .keep: "star.fill"
        case .archive: "archivebox.fill"
        case .remove: "trash.fill"
        case .skip: "arrow.uturn.forward"
        }
    }

    var tint: Color {
        switch self {
        case .keep: .yardRecycle
        case .archive: .yardAmber
        case .remove: .yardDanger
        case .skip: .yardInkMuted
        }
    }

    /// XP rewards the act of deciding, never the act of deleting. "Remove" is
    /// deliberately not the highest score.
    var xpReward: Int {
        switch self {
        case .keep: 10
        case .archive: 15
        case .remove: 10
        case .skip: 2
        }
    }

    var isDestructive: Bool { self == .remove }
}

// MARK: - Pile

enum PileID: String, Codable, CaseIterable, Identifiable {
    case screenshots
    case twins
    case relics
    case giants
    case nameless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshots: "截圖山"
        case .twins: "雙胞胎堆"
        case .relics: "遺跡區"
        case .giants: "巨獸區"
        case .nameless: "無名氏"
        }
    }

    var blurb: String {
        switch self {
        case .screenshots: "當下很重要，三天後沒人記得"
        case .twins: "同一份東西，你存了不只一次"
        case .relics: "超過半年沒有人碰過它們"
        case .giants: "體積最大的那幾隻"
        case .nameless: "檔名完全看不出是什麼"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshots: "photo.stack"
        case .twins: "square.on.square"
        case .relics: "clock.arrow.circlepath"
        case .giants: "shippingbox"
        case .nameless: "questionmark.folder"
        }
    }

    var tint: Color {
        switch self {
        case .screenshots: .yardTerracotta
        case .twins: .yardRecycle
        case .relics: .yardInkMuted
        case .giants: .yardAmber
        case .nameless: .yardTerracotta
        }
    }
}

// MARK: - Item

/// One piece of digital clutter. `assetIdentifier` is unused in the MVP but is the
/// hook PhotoKit ingestion writes into, so the storage layer never has to change shape.
struct JunkItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var kind: JunkKind
    var byteSize: Int64?
    var createdAt: Date?
    var twinGroup: String?
    var purposeTag: String?
    var verdict: Verdict?
    var decidedAt: Date?
    var sealedUntil: Date?
    var assetIdentifier: String?
    /// Index into `JunkItem.swatches`, used to give seeded items a stable stand-in preview.
    var swatch: Int = 0
    var discoveredAt: Date = .now

    var isDecided: Bool { verdict != nil }
    var hasPurposeTag: Bool { !(purposeTag ?? "").isEmpty }
    var isSealed: Bool { verdict == .archive && (sealedUntil ?? .distantPast) > .now }

    var ageInDays: Int? {
        guard let createdAt else { return nil }
        return Calendar.current.dateComponents([.day], from: createdAt, to: .now).day
    }

    var daysRemainingSealed: Int? {
        guard let sealedUntil else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: .now, to: sealedUntil).day ?? 0)
    }

    /// True when the filename carries no human meaning — one of the score factors and
    /// the thing the rename suggestions target.
    var hasMeaninglessName: Bool {
        let stem = (name as NSString).deletingPathExtension.lowercased()
        let prefixes = ["img_", "img-", "image", "photo_", "screenshot", "螢幕快照", "螢幕擷取",
                        "未命名", "untitled", "document", "scan_", "fullsizerender", "dsc_", "download"]
        if prefixes.contains(where: { stem.hasPrefix($0) }) { return true }
        // A stem made only of digits, dashes and spaces tells the user nothing either.
        return !stem.contains(where: \.isLetter)
    }

    /// Stand-in preview colors. Real thumbnails replace these when PhotoKit lands in P1.
    static let swatches: [Color] = [.yardTerracotta, .yardRecycle, .yardAmber, .yardInkMuted, .yardDanger]

    var swatchColor: Color { JunkItem.swatches[swatch % JunkItem.swatches.count] }
}
