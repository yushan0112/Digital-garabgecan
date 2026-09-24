import SwiftUI

// MARK: - Badges

struct Badge: Identifiable, Hashable {
    var id: String
    var title: String
    var requirement: String
    var symbolName: String
}

enum BadgeCatalog {
    static let all: [Badge] = [
        Badge(id: "first-verdict", title: "第一次判決", requirement: "對任何一件雜物做出決定", symbolName: "hammer.fill"),
        Badge(id: "ten-verdicts", title: "十連判", requirement: "累積 10 次判決", symbolName: "list.number"),
        Badge(id: "archivist", title: "膠囊管理員", requirement: "封存 3 件項目", symbolName: "archivebox.fill"),
        Badge(id: "taxonomist", title: "命名學家", requirement: "標記 5 件項目的用途", symbolName: "tag.fill"),
        Badge(id: "twin-slayer", title: "雙胞胎終結者", requirement: "處理掉一組重複項目", symbolName: "square.on.square.dashed"),
        Badge(id: "fifty-verdicts", title: "垃圾場主人", requirement: "累積 50 次判決", symbolName: "crown.fill"),
        Badge(id: "load-under-40", title: "整潔認證", requirement: "把垃圾負載壓到 40 以下", symbolName: "checkmark.seal.fill")
    ]

    static func badge(id: String) -> Badge? { all.first { $0.id == id } }
}

// MARK: - Level

/// XP → level. Flat 120 XP per level keeps the maths legible on screen.
struct YardLevel {
    static let xpPerLevel = 120

    var xp: Int

    var level: Int { xp / Self.xpPerLevel + 1 }
    var xpIntoLevel: Int { xp % Self.xpPerLevel }
    var progress: Double { Double(xpIntoLevel) / Double(Self.xpPerLevel) }

    var title: String {
        switch level {
        case 1: "見習拾荒者"
        case 2: "資料清運工"
        case 3: "鑑識技師"
        case 4: "分類大師"
        default: "垃圾場場長"
        }
    }
}

// MARK: - Daily task

struct DailyTask: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var symbolName: String
    var tint: Color
    var pile: PileID?
    var target: Int
    var completed: Int

    var progress: Double {
        target == 0 ? 0 : min(1, Double(completed) / Double(target))
    }

    var isDone: Bool { completed >= target }

    var estimateText: String { "\(target) 件・約 \(max(1, target / 5)) 分鐘" }
}

// MARK: - Session

/// A single salvage run. Held in memory only — the durable summary is `SessionRecord`.
struct RunSession {
    var itemIDs: [UUID]
    var cursor: Int = 0
    var decisions: [UUID: Verdict] = [:]
    var xpEarned: Int = 0
    var loadBefore: Int
    var startedAt: Date = .now
    /// Badges unlocked while this run was open, so the results screen can show them.
    var newBadgeIDs: [String] = []

    var isFinished: Bool { cursor >= itemIDs.count }
    var currentItemID: UUID? { isFinished ? nil : itemIDs[cursor] }
    var progressText: String { "\(min(cursor + 1, itemIDs.count)) / \(itemIDs.count)" }

    func count(of verdict: Verdict) -> Int {
        decisions.values.filter { $0 == verdict }.count
    }
}

/// The persisted receipt for one run. Marked vs released bytes are stored separately
/// on purpose: the app must never present "marked for removal" as space reclaimed.
struct SessionRecord: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date = .now
    var keptCount: Int = 0
    var archivedCount: Int = 0
    var removedCount: Int = 0
    var skippedCount: Int = 0
    var markedBytes: Int64 = 0
    var releasedBytes: Int64 = 0
    var xpEarned: Int = 0
    var loadBefore: Int = 0
    var loadAfter: Int = 0
    var newBadgeIDs: [String] = []

    var decidedCount: Int { keptCount + archivedCount + removedCount + skippedCount }
}

// MARK: - Settings

struct YardSettings: Codable {
    var butlerTone: ButlerTone = .witty
    var narrationEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var aiSuggestionsEnabled: Bool = true
    /// When the on-device model is unavailable, fall back to the rule engine rather
    /// than hiding the suggestions screen.
    var ruleFallbackEnabled: Bool = true
}
