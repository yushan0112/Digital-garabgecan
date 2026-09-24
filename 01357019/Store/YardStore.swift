import SwiftUI

/// The single source of truth for the yard.
///
/// Everything — seeded demo data today, PhotoKit assets in P1, imported folders in P2 —
/// funnels through this one object, so swapping JSON for SwiftData later touches only
/// `load()` and `save()`.
@MainActor
@Observable
final class YardStore {

    // MARK: Persisted state

    var items: [JunkItem] = []
    var settings = YardSettings()
    var xp: Int = 0
    var unlockedBadgeIDs: Set<String> = []
    var history: [SessionRecord] = []
    /// Bytes genuinely reclaimed from the system. Stays at zero for demo data, and the
    /// results screen says so out loud rather than inflating the number.
    var releasedBytes: Int64 = 0
    /// Items the user pushed through the crusher. Counted separately from `releasedBytes`
    /// because crushing demo data removes it from the yard without freeing real storage.
    var crushedCount: Int = 0
    var crushedBytes: Int64 = 0
    /// Purpose tags the user added themselves — seeded tags must not count toward badges.
    var tagsAdded: Int = 0

    // MARK: Runtime state

    var run: RunSession?
    var undoEntry: UndoEntry?
    var storage: StorageSnapshot = .unreadable
    var importState: ImportState = .idle
    var crusherReport: CrusherReport?

    enum ImportState: Equatable {
        case idle
        case working
        case finished(PhotoImportSummary)
        case failed(String)
    }

    /// What actually happened when the crusher ran — surfaced verbatim so the app never
    /// implies it freed space it did not free.
    struct CrusherReport: Equatable {
        var removedLocally: Int
        var deletedFromLibrary: Int
        var releasedBytes: Int64
        var libraryDeletionCancelled: Bool
    }

    private var scoreCache: [UUID: JunkScore] = [:]
    private var medianSize: Int64 = 0

    /// Cached so view bodies never recompute the whole yard's scores.
    private(set) var junkLoad: Int = 0

    struct UndoEntry: Identifiable, Equatable {
        var id = UUID()
        var snapshot: JunkItem
        var xpDelta: Int
        var message: String
    }

    // MARK: Init

    init(seedIfEmpty: Bool = true) {
        load()
        if items.isEmpty && seedIfEmpty {
            items = DemoYard.seed()
        }
        expireCapsules()
        refresh()
        storage = StorageProbe.snapshot()
    }

    /// Preview / test convenience: a yard with no disk involvement.
    static func demo() -> YardStore {
        let store = YardStore(seedIfEmpty: false)
        store.items = DemoYard.seed()
        store.refresh()
        return store
    }

    // MARK: Derived values

    var pendingItems: [JunkItem] { items.filter { !$0.isDecided } }
    var decidedItems: [JunkItem] { items.filter(\.isDecided) }
    var sealedItems: [JunkItem] { items.filter(\.isSealed).sorted { ($0.sealedUntil ?? .now) < ($1.sealedUntil ?? .now) } }
    var keptItems: [JunkItem] { items.filter { $0.verdict == .keep } }
    var removedItems: [JunkItem] { items.filter { $0.verdict == .remove } }

    var level: YardLevel { YardLevel(xp: xp) }

    /// Bytes sitting in items the user marked for removal — reclaimable, not reclaimed.
    var markedBytes: Int64 { removedItems.compactMap(\.byteSize).reduce(0, +) }

    var trackedBytes: Int64 { items.compactMap(\.byteSize).reduce(0, +) }

    var loadLevel: ScoreLevel { ScoreLevel(score: junkLoad) }

    func score(for item: JunkItem) -> JunkScore {
        scoreCache[item.id] ?? JunkScoring.score(for: item, medianSize: medianSize)
    }

    func item(id: UUID) -> JunkItem? { items.first { $0.id == id } }

    var analysisEngine: AnalysisEngine { AnalysisEngineProbe.current(settings: settings) }

    // MARK: Piles

    /// An item can live in several piles at once — that is the honest model, since a
    /// screenshot can also be a duplicate. Pile counts therefore overlap by design.
    func piles(for item: JunkItem) -> [PileID] {
        var out: [PileID] = []
        if item.kind == .screenshot { out.append(.screenshots) }
        if item.twinGroup != nil { out.append(.twins) }
        if let days = item.ageInDays, days > JunkScoring.ageFreeDays { out.append(.relics) }
        if let size = item.byteSize, size > 40 * 1_048_576 { out.append(.giants) }
        if item.hasMeaninglessName { out.append(.nameless) }
        return out
    }

    func items(in pile: PileID?, includeDecided: Bool = false) -> [JunkItem] {
        items.filter { item in
            guard includeDecided || !item.isDecided else { return false }
            guard let pile else { return true }
            return piles(for: item).contains(pile)
        }
    }

    func pendingCount(in pile: PileID) -> Int { items(in: pile).count }

    func averageScore(in pile: PileID) -> Int {
        let scores = items(in: pile).map { score(for: $0).value }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / scores.count
    }

    var recentDiscoveries: [JunkItem] {
        pendingItems.sorted { $0.discoveredAt > $1.discoveredAt }.prefix(8).map { $0 }
    }

    // MARK: Daily tasks

    var dailyTasks: [DailyTask] {
        let screenshotTarget = min(10, max(1, items(in: .screenshots, includeDecided: true).count))
        let screenshotDone = items(in: .screenshots, includeDecided: true).filter(\.isDecided).count

        let twinTarget = min(6, max(1, items(in: .twins, includeDecided: true).count))
        let twinDone = items(in: .twins, includeDecided: true).filter(\.isDecided).count

        return [
            DailyTask(
                id: "clear-screenshots",
                title: "清理截圖山",
                subtitle: "最容易割出空間的一堆",
                symbolName: PileID.screenshots.symbolName,
                tint: .yardTerracotta,
                pile: .screenshots,
                target: screenshotTarget,
                completed: min(screenshotDone, screenshotTarget)
            ),
            DailyTask(
                id: "resolve-twins",
                title: "解決雙胞胎",
                subtitle: "同一份東西留一份就好",
                symbolName: PileID.twins.symbolName,
                tint: .yardRecycle,
                pile: .twins,
                target: twinTarget,
                completed: min(twinDone, twinTarget)
            ),
            DailyTask(
                id: "tag-purposes",
                title: "標記 5 件用途",
                subtitle: "標過用途的項目不會再被嘴",
                symbolName: "tag.fill",
                tint: .yardAmber,
                pile: nil,
                target: 5,
                completed: min(tagsAdded, 5)
            )
        ]
    }

    // MARK: Mutations

    @discardableResult
    func decide(_ verdict: Verdict, for id: UUID) -> [Badge] {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return [] }
        let snapshot = items[index]

        items[index].verdict = verdict
        items[index].decidedAt = .now
        items[index].sealedUntil = verdict == .archive
            ? Calendar.current.date(byAdding: .day, value: 30, to: .now)
            : nil

        xp += verdict.xpReward

        undoEntry = UndoEntry(
            snapshot: snapshot,
            xpDelta: verdict.xpReward,
            message: "已\(verdict.title)「\(snapshot.name)」"
        )

        refresh()
        let unlocked = unlockBadges()

        // Badges earned mid-run are collected on the session so the results screen can
        // present them, rather than being lost at the moment they unlock.
        if var session = run, session.itemIDs.contains(id) {
            session.decisions[id] = verdict
            session.xpEarned += verdict.xpReward
            session.newBadgeIDs.append(contentsOf: unlocked.map(\.id))
            if session.currentItemID == id { session.cursor += 1 }
            run = session
        }

        save()
        return unlocked
    }

    func setPurpose(_ tag: String?, for id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let wasTagged = items[index].hasPurposeTag
        let trimmed = (tag ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].purposeTag = trimmed.isEmpty ? nil : trimmed
        if !wasTagged && items[index].hasPurposeTag { tagsAdded += 1 }
        refresh()
        unlockBadges()
        save()
    }

    func rename(_ id: UUID, to newName: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].name = trimmed
        refresh()
        save()
    }

    func undoLast() {
        guard let entry = undoEntry,
              let index = items.firstIndex(where: { $0.id == entry.snapshot.id }) else { return }
        items[index] = entry.snapshot
        xp = max(0, xp - entry.xpDelta)

        if var session = run, session.itemIDs.contains(entry.snapshot.id) {
            session.decisions[entry.snapshot.id] = nil
            session.xpEarned = max(0, session.xpEarned - entry.xpDelta)
            session.cursor = max(0, session.cursor - 1)
            run = session
        }

        undoEntry = nil
        refresh()
        save()
    }

    func dismissUndo() { undoEntry = nil }

    // MARK: Salvage run

    func startRun(pile: PileID?, limit: Int = 10) {
        // Worst offenders first: a run should feel like it is doing real work.
        let queue = items(in: pile)
            .sorted { score(for: $0).value > score(for: $1).value }
            .prefix(limit)
            .map(\.id)
        run = RunSession(itemIDs: Array(queue), loadBefore: junkLoad)
    }

    func skipCurrentInRun() {
        guard let id = run?.currentItemID else { return }
        decide(.skip, for: id)
    }

    /// Closes the run and files the receipt. Returns nil if nothing was decided.
    @discardableResult
    func finishRun() -> SessionRecord? {
        guard let session = run else { return nil }
        run = nil
        guard !session.decisions.isEmpty else { return nil }

        let removedIDs = session.decisions.filter { $0.value == .remove }.map(\.key)
        let marked = removedIDs.compactMap { item(id: $0)?.byteSize }.reduce(0, +)

        var record = SessionRecord(
            date: .now,
            keptCount: session.count(of: .keep),
            archivedCount: session.count(of: .archive),
            removedCount: session.count(of: .remove),
            skippedCount: session.count(of: .skip),
            markedBytes: marked,
            // Demo and un-deleted items release nothing yet; P1 fills this in after the
            // system delete confirmation actually succeeds.
            releasedBytes: 0,
            xpEarned: session.xpEarned,
            loadBefore: session.loadBefore,
            loadAfter: junkLoad
        )
        record.newBadgeIDs = Array(Set(session.newBadgeIDs))
        history.insert(record, at: 0)
        save()
        return record
    }

    func cancelRun() { run = nil }

    // MARK: Suggestions

    func buildSuggestions() -> (suggestions: [Suggestion], dormantDataGaps: Int) {
        SuggestionEngine.build(items: items) { self.score(for: $0) }
    }

    /// Applies an accepted suggestion. Duplicate groups are the only kind that can
    /// remove anything, and the caller must have confirmed first.
    func apply(_ suggestion: Suggestion) {
        switch suggestion.kind {
        case .category:
            if let id = suggestion.primaryItemID, let value = suggestion.proposedValue {
                setPurpose(value, for: id)
            }
        case .rename:
            if let id = suggestion.primaryItemID, let value = suggestion.proposedValue {
                rename(id, to: value)
            }
        case .duplicate:
            for id in suggestion.itemIDs {
                decide(id == suggestion.keepItemID ? .keep : .remove, for: id)
            }
        case .dormant:
            if let id = suggestion.primaryItemID {
                decide(.archive, for: id)
            }
        }
    }

    // MARK: Photo import

    var photoBackedItems: [JunkItem] { items.filter { $0.assetIdentifier != nil } }
    var demoItems: [JunkItem] { items.filter { $0.assetIdentifier == nil } }

    var photoAccess: PhotoAccess { PhotoLibraryService.shared.access }

    /// Asks for permission if needed, then pulls screenshots in as junk items. Items
    /// already imported are skipped by `localIdentifier`, so re-running is safe.
    func importFromPhotos(limit: Int = 200) async {
        importState = .working

        var access = PhotoLibraryService.shared.access
        if access == .notDetermined {
            access = await PhotoLibraryService.shared.requestAccess()
        }
        guard access.canRead else {
            importState = .failed(PhotoImportError.noAccess(access).localizedDescription)
            return
        }

        do {
            let existing = Set(items.compactMap(\.assetIdentifier))
            let result = try await PhotoLibraryService.shared.importItems(
                limit: limit,
                existingIdentifiers: existing
            )
            items.append(contentsOf: result.items)
            refresh()
            save()
            importState = .finished(result.summary)
        } catch {
            importState = .failed(error.localizedDescription)
        }
    }

    /// Demo data is fake, so dropping it is safe and always recoverable via a reset.
    func removeDemoItems() {
        items.removeAll { $0.assetIdentifier == nil }
        run = nil
        undoEntry = nil
        refresh()
        save()
    }

    // MARK: Crusher

    /// Finalises every item marked for removal.
    ///
    /// Photo-library items go through `PHPhotoLibrary`, which shows its own confirmation
    /// and moves the assets to Recently Deleted — only those bytes count as released.
    /// Demo items just leave the yard and release nothing, and the report says so.
    func emptyCrusher() async {
        let doomed = removedItems
        guard !doomed.isEmpty else { return }

        let assetItems = doomed.filter { $0.assetIdentifier != nil }
        var deletedIDs: Set<UUID> = []
        var releasedNow: Int64 = 0
        var cancelled = false

        if !assetItems.isEmpty {
            let identifiers = assetItems.compactMap(\.assetIdentifier)
            let didDelete = (try? await PhotoLibraryService.shared.deleteAssets(withIdentifiers: identifiers)) ?? false
            if didDelete {
                deletedIDs.formUnion(assetItems.map(\.id))
                releasedNow = assetItems.compactMap(\.byteSize).reduce(0, +)
            } else {
                cancelled = true
            }
        }

        // Demo items always leave; asset items only leave if the system really deleted them.
        let localItems = doomed.filter { $0.assetIdentifier == nil }
        let leavingIDs = deletedIDs.union(localItems.map(\.id))

        crushedCount += leavingIDs.count
        crushedBytes += doomed.filter { leavingIDs.contains($0.id) }.compactMap(\.byteSize).reduce(0, +)
        releasedBytes += releasedNow
        items.removeAll { leavingIDs.contains($0.id) }

        crusherReport = CrusherReport(
            removedLocally: localItems.count,
            deletedFromLibrary: deletedIDs.count,
            releasedBytes: releasedNow,
            libraryDeletionCancelled: cancelled
        )

        undoEntry = nil
        refresh()
        save()
    }

    // MARK: Capsule

    /// Sealed items come back to the yard when their 30 days are up — that is the whole
    /// point of the capsule: a second, better-informed decision.
    func expireCapsules() {
        var changed = false
        for index in items.indices {
            guard items[index].verdict == .archive,
                  let until = items[index].sealedUntil,
                  until <= .now else { continue }
            items[index].verdict = nil
            items[index].sealedUntil = nil
            items[index].decidedAt = nil
            items[index].discoveredAt = .now
            changed = true
        }
        if changed { save() }
    }

    func releaseFromCapsule(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].verdict = nil
        items[index].sealedUntil = nil
        items[index].decidedAt = nil
        items[index].discoveredAt = .now
        refresh()
        save()
    }

    // MARK: Data management

    func clearDecisions() {
        for index in items.indices {
            items[index].verdict = nil
            items[index].decidedAt = nil
            items[index].sealedUntil = nil
        }
        history.removeAll()
        run = nil
        undoEntry = nil
        refresh()
        save()
    }

    func emptyCapsule() {
        for index in items.indices where items[index].verdict == .archive {
            items[index].verdict = nil
            items[index].sealedUntil = nil
            items[index].decidedAt = nil
        }
        refresh()
        save()
    }

    func resetEverything() {
        items = DemoYard.seed()
        xp = 0
        tagsAdded = 0
        unlockedBadgeIDs.removeAll()
        history.removeAll()
        releasedBytes = 0
        crushedCount = 0
        crushedBytes = 0
        run = nil
        undoEntry = nil
        refresh()
        save()
    }

    func refreshStorage() { storage = StorageProbe.snapshot() }

    // MARK: Badges

    @discardableResult
    private func unlockBadges() -> [Badge] {
        let decided = decidedItems.count
        let archived = items.filter { $0.verdict == .archive }.count
        let twinGroupsResolved = Dictionary(grouping: items.filter { $0.twinGroup != nil }) { $0.twinGroup ?? "" }
            .contains { _, members in members.allSatisfy(\.isDecided) }

        var earned: Set<String> = []
        if decided >= 1 { earned.insert("first-verdict") }
        if decided >= 10 { earned.insert("ten-verdicts") }
        if decided >= 50 { earned.insert("fifty-verdicts") }
        if archived >= 3 { earned.insert("archivist") }
        if tagsAdded >= 5 { earned.insert("taxonomist") }
        if twinGroupsResolved { earned.insert("twin-slayer") }
        if decided > 0 && junkLoad <= 40 { earned.insert("load-under-40") }

        let new = earned.subtracting(unlockedBadgeIDs)
        unlockedBadgeIDs.formUnion(new)
        return new.compactMap(BadgeCatalog.badge(id:))
    }

    // MARK: Derived cache

    private func refresh() {
        let sizes = items.compactMap(\.byteSize).sorted()
        medianSize = sizes.isEmpty ? 0 : sizes[sizes.count / 2]

        scoreCache = Dictionary(
            uniqueKeysWithValues: items.map { ($0.id, JunkScoring.score(for: $0, medianSize: medianSize)) }
        )

        let pending = pendingItems
        junkLoad = pending.isEmpty
            ? 0
            : pending.map { scoreCache[$0.id]?.value ?? 0 }.reduce(0, +) / pending.count
    }

    // MARK: Persistence

    private struct YardState: Codable {
        var items: [JunkItem]
        var settings: YardSettings
        var xp: Int
        var unlockedBadgeIDs: [String]
        var history: [SessionRecord]
        var releasedBytes: Int64
        var tagsAdded: Int
        var crushedCount: Int?
        var crushedBytes: Int64?
    }

    private static var fileURL: URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let directory = base.appending(path: "DigitalJunkyard", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "yard.json")
    }

    private func load() {
        guard let url = Self.fileURL,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(YardState.self, from: data) else { return }
        items = state.items
        settings = state.settings
        xp = state.xp
        unlockedBadgeIDs = Set(state.unlockedBadgeIDs)
        history = state.history
        releasedBytes = state.releasedBytes
        tagsAdded = state.tagsAdded
        crushedCount = state.crushedCount ?? 0
        crushedBytes = state.crushedBytes ?? 0
    }

    func save() {
        guard let url = Self.fileURL else { return }
        let state = YardState(
            items: items,
            settings: settings,
            xp: xp,
            unlockedBadgeIDs: Array(unlockedBadgeIDs),
            history: history,
            releasedBytes: releasedBytes,
            tagsAdded: tagsAdded,
            crushedCount: crushedCount,
            crushedBytes: crushedBytes
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Butler

    var greeting: String {
        ButlerScript.greeting(load: junkLoad, pendingCount: pendingItems.count, tone: settings.butlerTone)
    }

    func advice(for item: JunkItem) -> ButlerAdvice {
        ButlerScript.advice(for: item, score: score(for: item), tone: settings.butlerTone)
    }

    func snark(for item: JunkItem) -> String? {
        guard settings.narrationEnabled else { return nil }
        return ButlerScript.snark(for: item, tone: settings.butlerTone)
    }
}
