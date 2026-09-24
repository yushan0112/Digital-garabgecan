import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AI status

/// Which engine is actually producing the suggestions right now. The suggestions
/// screen prints this verbatim — the user should never have to guess.
enum AnalysisEngine: Equatable {
    case onDeviceModel
    case ruleEngine(reason: String)
    case disabled

    var title: String {
        switch self {
        case .onDeviceModel: "裝置端模型"
        case .ruleEngine: "規則分析"
        case .disabled: "已關閉"
        }
    }

    var explanation: String {
        switch self {
        case .onDeviceModel:
            "建議由裝置端語言模型產生，不會上傳任何資料。"
        case .ruleEngine(let reason):
            "\(reason)目前改用內建規則分析，同樣完全離線。"
        case .disabled:
            "你已在設定中關閉 AI 建議，以下只顯示可直接驗證的中繼資料比對結果。"
        }
    }

    var symbolName: String {
        switch self {
        case .onDeviceModel: "apple.intelligence"
        case .ruleEngine: "function"
        case .disabled: "slash.circle"
        }
    }
}

enum AnalysisEngineProbe {
    static func current(settings: YardSettings) -> AnalysisEngine {
        guard settings.aiSuggestionsEnabled else { return .disabled }
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .onDeviceModel
        case .unavailable(let reason):
            // Honouring the fallback switch: with it off, the screen says "disabled"
            // rather than silently swapping in a different engine.
            return settings.ruleFallbackEnabled ? .ruleEngine(reason: describe(reason)) : .disabled
        }
        #else
        return settings.ruleFallbackEnabled
            ? .ruleEngine(reason: "這個系統版本沒有裝置端模型，")
            : .disabled
        #endif
    }

    #if canImport(FoundationModels)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .appleIntelligenceNotEnabled: "尚未開啟 Apple Intelligence，"
        case .deviceNotEligible: "這台裝置不支援 Apple Intelligence，"
        case .modelNotReady: "模型還在下載中，"
        @unknown default: "裝置端模型目前不可用，"
        }
    }
    #endif
}

// MARK: - Suggestion

enum SuggestionKind: String, CaseIterable, Identifiable {
    case category
    case rename
    case duplicate
    case dormant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category: "建議分類"
        case .rename: "建議重新命名"
        case .duplicate: "疑似重複"
        case .dormant: "可能長期未使用"
        }
    }

    var symbolName: String {
        switch self {
        case .category: "folder.badge.gearshape"
        case .rename: "character.cursor.ibeam"
        case .duplicate: "square.on.square"
        case .dormant: "hourglass"
        }
    }
}

enum SuggestionState: String {
    case pending
    case accepted
    case rejected
}

struct Suggestion: Identifiable {
    var id = UUID()
    var kind: SuggestionKind
    var itemIDs: [UUID]
    var headline: String
    var detail: String
    /// The exact fields the conclusion rests on — rendered as "依據" in the UI.
    var basis: [String]
    var confidence: ButlerAdvice.Confidence
    /// New name or category to apply when accepted.
    var proposedValue: String?
    /// For duplicate groups: the one item worth keeping.
    var keepItemID: UUID?
    var state: SuggestionState = .pending

    var primaryItemID: UUID? { itemIDs.first }
}

// MARK: - Engine

enum SuggestionEngine {

    /// Builds all four suggestion groups from metadata alone. Anything we cannot
    /// support with real data is reported as a shortfall instead of being invented.
    static func build(items: [JunkItem], scoreProvider: (JunkItem) -> JunkScore) -> (suggestions: [Suggestion], dormantDataGaps: Int) {
        var out: [Suggestion] = []
        let candidates = items.filter { !$0.isDecided }

        out.append(contentsOf: categorySuggestions(candidates))
        out.append(contentsOf: renameSuggestions(candidates))
        out.append(contentsOf: duplicateSuggestions(candidates))

        let (dormant, gaps) = dormantSuggestions(candidates, scoreProvider: scoreProvider)
        out.append(contentsOf: dormant)

        return (out, gaps)
    }

    // MARK: Category

    private static let categoryKeywords: [(keys: [String], category: String)] = [
        (["hw", "homework", "作業", "lab", "assignment", "report", "期中", "期末", "final", "midterm", "lecture", "課"], "課堂資料"),
        (["receipt", "invoice", "發票", "收據", "order", "訂單"], "收據與帳單"),
        (["meme", "梗圖", "funny", "迷因"], "迷因收藏"),
        (["cv", "resume", "履歷", "portfolio"], "求職資料"),
        (["ticket", "boarding", "機票", "訂房", "booking"], "行程票券")
    ]

    private static func categorySuggestions(_ items: [JunkItem]) -> [Suggestion] {
        items.compactMap { item in
            guard !item.hasPurposeTag else { return nil }
            let stem = item.name.lowercased()

            if let match = categoryKeywords.first(where: { $0.keys.contains(where: { stem.contains($0) }) }) {
                return Suggestion(
                    kind: .category,
                    itemIDs: [item.id],
                    headline: "歸到「\(match.category)」",
                    detail: "檔名裡出現了這個分類的關鍵字。",
                    basis: ["檔名：\(item.name)", "類型：\(item.kind.title)"],
                    confidence: .medium,
                    proposedValue: match.category
                )
            }

            // No keyword to stand on — say so rather than guessing a category.
            guard item.kind == .screenshot, item.createdAt != nil else { return nil }
            return Suggestion(
                kind: .category,
                itemIDs: [item.id],
                headline: "歸到「螢幕紀錄・待確認」",
                detail: "只能確定它是截圖，內容無法從中繼資料判斷。",
                basis: ["類型：截圖", "建立日期：\(YardFormat.date(item.createdAt))"],
                confidence: .low,
                proposedValue: "螢幕紀錄・待確認"
            )
        }
    }

    // MARK: Rename

    private static func renameSuggestions(_ items: [JunkItem]) -> [Suggestion] {
        items.compactMap { item in
            guard item.hasMeaninglessName else { return nil }
            let ext = (item.name as NSString).pathExtension
            let datePart: String
            if let created = item.createdAt {
                // Built by hand so a proposed filename never depends on the device locale.
                let parts = Calendar.current.dateComponents([.year, .month, .day], from: created)
                datePart = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            } else {
                datePart = "無日期"
            }
            let tag = item.purposeTag ?? "待分類"
            let proposed = ext.isEmpty
                ? "\(item.kind.title)-\(datePart)-\(tag)"
                : "\(item.kind.title)-\(datePart)-\(tag).\(ext)"

            return Suggestion(
                kind: .rename,
                itemIDs: [item.id],
                headline: proposed,
                detail: "原檔名「\(item.name)」是系統自動命名，改成日期加用途之後才搜尋得到。",
                basis: ["檔名樣式：系統自動命名", "類型：\(item.kind.title)", "建立日期：\(YardFormat.date(item.createdAt))"],
                confidence: item.createdAt == nil ? .low : .high,
                proposedValue: proposed
            )
        }
    }

    // MARK: Duplicates

    private static func duplicateSuggestions(_ items: [JunkItem]) -> [Suggestion] {
        let groups = Dictionary(grouping: items.filter { $0.twinGroup != nil }) { $0.twinGroup ?? "" }

        return groups.compactMap { group, members -> Suggestion? in
            guard members.count > 1 else { return nil }
            // Keep the largest; on a tie, the newest. Both are facts we can defend.
            let keeper = members.max { lhs, rhs in
                let l = (lhs.byteSize ?? 0, lhs.createdAt ?? .distantPast)
                let r = (rhs.byteSize ?? 0, rhs.createdAt ?? .distantPast)
                return l.0 == r.0 ? l.1 < r.1 : l.0 < r.0
            }
            guard let keeper else { return nil }

            let others = members.filter { $0.id != keeper.id }
            let sizes = members.compactMap(\.byteSize)
            let spread: String
            if let minSize = sizes.min(), let maxSize = sizes.max(), minSize > 0 {
                let diff = Double(maxSize - minSize) / Double(minSize) * 100
                spread = String(format: "大小差 %.0f%%", diff)
            } else {
                spread = "大小資料不完整"
            }

            let sameDay: Bool = {
                let days = members.compactMap(\.createdAt)
                guard let first = days.first else { return false }
                return days.allSatisfy { Calendar.current.isDate($0, inSameDayAs: first) }
            }()

            return Suggestion(
                kind: .duplicate,
                itemIDs: members.map(\.id),
                headline: "保留「\(keeper.name)」，移除其他 \(others.count) 份",
                detail: "\(spread)，\(sameDay ? "建立於同一天" : "建立日期不同")。建議留下體積最大的那一份。",
                basis: ["雙胞胎組：\(group)", "組內數量：\(members.count)", spread],
                confidence: sameDay && sizes.count == members.count ? .high : .medium,
                keepItemID: keeper.id
            )
        }
        .sorted { $0.itemIDs.count > $1.itemIDs.count }
    }

    // MARK: Dormant

    /// Only items with a real creation date can appear here. The count of items we had
    /// to skip is returned so the UI can say "N 件資料不足，無法判斷".
    private static func dormantSuggestions(
        _ items: [JunkItem],
        scoreProvider: (JunkItem) -> JunkScore
    ) -> ([Suggestion], Int) {
        var out: [Suggestion] = []
        var gaps = 0

        for item in items {
            guard let created = item.createdAt, let days = item.ageInDays else {
                gaps += 1
                continue
            }
            guard days > 365, !item.hasPurposeTag else { continue }

            out.append(Suggestion(
                kind: .dormant,
                itemIDs: [item.id],
                headline: "封存 30 天觀察",
                detail: "建立於 \(YardFormat.date(created))（\(days) 天前）且從未標記用途。iOS 不提供開啟紀錄，所以這是依日期推測，不是使用行為。",
                basis: ["建立日期：\(YardFormat.date(created))", "目前垃圾指數：\(scoreProvider(item).value)", "用途標籤：無"],
                confidence: .medium,
                proposedValue: nil
            ))
        }

        return (out.sorted { ($0.itemIDs.first?.uuidString ?? "") < ($1.itemIDs.first?.uuidString ?? "") }, gaps)
    }
}
