import Foundation

// MARK: - Tone

enum ButlerTone: String, Codable, CaseIterable, Identifiable {
    case witty
    case gentle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .witty: "機智吐槽"
        case .gentle: "溫和"
        }
    }

    var blurb: String {
        switch self {
        case .witty: "賈維鏽會評論你的收藏習慣，但不會太過分。"
        case .gentle: "只給中性的說明，不做評論。"
        }
    }
}

// MARK: - Advice

/// What the butler recommends for one item, plus the fields he used to get there.
/// `basis` is surfaced in the UI so the user can audit the reasoning — and it can only
/// ever contain things iOS actually gives us.
struct ButlerAdvice {
    var suggestedVerdict: Verdict
    var headline: String
    var body: String
    var basis: [String]
    var confidence: Confidence

    enum Confidence: String {
        case high, medium, low

        var title: String {
            switch self {
            case .high: "高信心"
            case .medium: "中信心"
            case .low: "低信心"
            }
        }

        var filledBars: Int {
            switch self {
            case .high: 3
            case .medium: 2
            case .low: 1
            }
        }
    }
}

// MARK: - Script

/// 賈維鏽 — the yard's caretaker. He narrates, he judges your filenames, and he is
/// honest about his own blind spots: iOS gives apps no file-open history, so he may
/// only ever cite name, size, date, type and twin membership.
enum ButlerScript {

    // MARK: Greeting

    static func greeting(load: Int, pendingCount: Int, tone: ButlerTone) -> String {
        switch tone {
        case .gentle:
            if load >= 80 { return "垃圾負載偏高，目前有 \(pendingCount) 件項目待整理。" }
            if load >= 50 { return "還有 \(pendingCount) 件項目沒有處理，慢慢來就好。" }
            if pendingCount == 0 { return "垃圾場目前是空的，全部項目都有結論了。" }
            return "狀況不錯，剩下 \(pendingCount) 件。"
        case .witty:
            if load >= 80 { return "負載 \(load)。我不是在批評，我是在紀錄事實。" }
            if load >= 50 { return "\(pendingCount) 件懸案。你打算留給未來的自己處理？" }
            if pendingCount == 0 { return "空了。我竟然有點無事可做，這很不習慣。" }
            return "剩 \(pendingCount) 件，看得出你最近有在動手。"
        }
    }

    // MARK: Per-item flavor

    /// Optional colour commentary. Returns nil when there is nothing worth saying —
    /// most importantly, a tagged item retires its own snark, because every snark
    /// condition below requires `hasPurposeTag == false`.
    static func snark(for item: JunkItem, tone: ButlerTone) -> String? {
        guard tone == .witty, !item.hasPurposeTag else { return nil }

        if item.twinGroup != nil {
            return "這東西你存了不只一份。收藏癖我理解，但這不是郵票。"
        }
        if item.hasMeaninglessName, item.kind == .screenshot {
            return "「\(item.name)」。當初一定很重要吧。"
        }
        if let days = item.ageInDays, days > 365 {
            return "\(days) 天沒有名字、沒有用途，只有體積。"
        }
        if item.hasMeaninglessName {
            return "檔名是系統給的，意思是你也沒想過它是什麼。"
        }
        if item.kind == .screenshot {
            return "截圖。人類最擅長生產、最不擅長回顧的格式。"
        }
        return nil
    }

    // MARK: Recommendation

    static func advice(for item: JunkItem, score: JunkScore, tone: ButlerTone) -> ButlerAdvice {
        var basis: [String] = ["類型：\(item.kind.title)"]
        if item.byteSize != nil { basis.append("大小：\(YardFormat.bytes(item.byteSize))") }
        if item.createdAt != nil { basis.append("建立日期：\(YardFormat.date(item.createdAt))") }
        basis.append("檔名樣式：\(item.hasMeaninglessName ? "系統自動命名" : "使用者命名")")
        if item.twinGroup != nil { basis.append("雙胞胎組：\(item.twinGroup ?? "")") }

        // Confidence tracks how much real metadata we actually had.
        let confidence: ButlerAdvice.Confidence
        if item.createdAt != nil && item.byteSize != nil && item.twinGroup != nil {
            confidence = .high
        } else if item.createdAt != nil && item.byteSize != nil {
            confidence = .medium
        } else {
            confidence = .low
        }

        if item.hasPurposeTag {
            return ButlerAdvice(
                suggestedVerdict: .keep,
                headline: "建議保留",
                body: tone == .witty
                    ? "你標了「\(item.purposeTag ?? "")」，那我就沒意見了。"
                    : "此項目已標記用途，建議保留。",
                basis: basis + ["用途標籤：\(item.purposeTag ?? "")"],
                confidence: .high
            )
        }

        switch score.level {
        case .hazard, .junk:
            let reason = score.factors.first(where: { $0.isPenalty })?.label ?? "多項指標偏高"
            let isDuplicate = item.twinGroup != nil
            return ButlerAdvice(
                suggestedVerdict: isDuplicate ? .remove : .archive,
                headline: isDuplicate ? "建議移除" : "建議封存 30 天",
                body: {
                    switch (isDuplicate, tone) {
                    case (true, .witty):
                        "主要問題是「\(reason)」，而且同一份東西你存了不只一份。留最完整的那一份就夠了。"
                    case (true, .gentle):
                        "主要原因是「\(reason)」，且此項目屬於重複群組。建議保留最完整的一份，移除其餘。"
                    case (false, .witty):
                        "主要問題是「\(reason)」。不敢刪就先封起來，30 天後你自然會知道答案。"
                    case (false, .gentle):
                        "主要原因是「\(reason)」。若無法確定，可以先封存 30 天再決定。"
                    }
                }(),
                basis: basis,
                confidence: confidence
            )
        case .review:
            return ButlerAdvice(
                suggestedVerdict: .skip,
                headline: "資訊不足，建議先標記用途",
                body: tone == .witty
                    ? "我只看得到標籤上的字，看不到你腦子裡的事。告訴我它幹嘛用的。"
                    : "目前的中繼資料不足以判斷，建議先標記用途。",
                basis: basis,
                confidence: .low
            )
        case .recyclable:
            return ButlerAdvice(
                suggestedVerdict: .keep,
                headline: "建議保留",
                body: tone == .witty
                    ? "這件沒什麼問題。難得。"
                    : "各項指標正常，建議保留。",
                basis: basis,
                confidence: confidence
            )
        }
    }

    // MARK: Reactions

    static func verdictQuip(_ verdict: Verdict, item: JunkItem, tone: ButlerTone) -> String {
        guard tone == .witty else {
            switch verdict {
            case .keep: return "已標記保留。"
            case .archive: return "已封存，30 天後會再問你一次。"
            case .remove: return "已標記移除。"
            case .skip: return "已跳過，稍後會再出現。"
            }
        }
        switch verdict {
        case .keep: return item.hasPurposeTag ? "合理。" : "留著也行，反正空間是你的。"
        case .archive: return "封起來了。30 天後見，如果你還記得的話。"
        case .remove: return "送去壓碎機。你會沒事的。"
        case .skip: return "拖延也是一種決定。它會回來的。"
        }
    }

    static func sessionSummary(decided: Int, removed: Int, tone: ButlerTone) -> String {
        switch tone {
        case .gentle:
            return "本次共處理 \(decided) 件項目。"
        case .witty:
            if decided == 0 { return "零件。你是來觀光的。" }
            if removed == 0 { return "\(decided) 件都留下了。至少你現在知道它們是什麼。" }
            return "\(decided) 件有結論，其中 \(removed) 件送進壓碎機。這叫進步。"
        }
    }

    /// The character's own explanation of a real platform limit — we surface this in
    /// Settings instead of pretending the app can see more than it can.
    static let limitationNote = """
    我能看到的只有：檔名、類型、大小、建立日期，以及項目之間的相似度。
    iOS 不會告訴任何 App「這個檔案你上次什麼時候開過」，所以我永遠不會拿使用頻率當理由。
    我的每一句建議都附上依據，你可以自己檢查。
    """
}
