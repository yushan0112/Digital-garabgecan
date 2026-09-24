import SwiftUI

/// ⑤ 整理紀錄（回收紀念館）
///
/// The persistent half of the results screen: lifetime progress, achievements, the time
/// capsule, and every past session. Cumulative space is again split into "marked",
/// "crushed" and "actually released" so the numbers stay defensible.
struct RecordView: View {
    @Environment(YardStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    levelCard
                    CrusherCard()
                    totalsCard
                    capsuleLink
                    badgesCard
                    historySection
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxxl)
            }
            .background(Color.yardCanvas)
            .navigationTitle("整理紀錄")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
        }
    }

    // MARK: Level

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                ButlerAvatar(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv.\(store.level.level)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.yardInk)
                    Text(store.level.title)
                        .font(.caption)
                        .foregroundStyle(Color.yardInkMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.xp)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.yardRecycle)
                    Text("總 XP")
                        .yardTagCase()
                        .foregroundStyle(Color.yardInkMuted)
                }
            }
            XPBar(level: store.level)
        }
        .junkCard()
    }

    // MARK: Totals

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "累積成果", subtitle: "三個數字分開算，不混在一起")

            HStack(spacing: Space.m) {
                StatTile(
                    label: "判決次數",
                    value: "\(store.decidedItems.count + store.crushedCount)",
                    footnote: "次",
                    tint: .yardRecycle
                )
                StatTile(
                    label: "已壓碎",
                    value: "\(store.crushedCount)",
                    footnote: YardFormat.bytes(store.crushedBytes),
                    tint: .yardTerracotta
                )
                StatTile(
                    label: "實際釋放",
                    value: YardFormat.bytes(store.releasedBytes),
                    footnote: "經系統確認刪除",
                    tint: .yardAmber
                )
            }

            Text("「已壓碎」是離開這個 App 垃圾場的項目數；只有真正從相片圖庫刪除成功的容量才會算進「實際釋放」。")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Capsule

    @ViewBuilder
    private var capsuleLink: some View {
        NavigationLink {
            TimeCapsuleView()
        } label: {
            HStack(spacing: Space.m) {
                JunkGlyph(symbolName: "archivebox.fill", tint: .yardAmber, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("時間膠囊")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.yardInk)
                    Text(store.sealedItems.isEmpty
                         ? "目前沒有封存中的項目"
                         : "\(store.sealedItems.count) 件封存中")
                        .font(.caption2)
                        .foregroundStyle(Color.yardInkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.yardInkMuted)
            }
            .junkCard(padding: Space.m)
        }
        .buttonStyle(.plain)
    }

    // MARK: Badges

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(
                title: "成就",
                subtitle: "\(store.unlockedBadgeIDs.count) / \(BadgeCatalog.all.count) 已解鎖"
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Space.m) {
                    ForEach(BadgeCatalog.all) { badge in
                        BadgeChip(badge: badge, isUnlocked: store.unlockedBadgeIDs.contains(badge.id))
                    }
                }
                .padding(.vertical, Space.xs)
            }
            .scrollClipDisabled()
        }
        .junkCard()
    }

    // MARK: History

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "整理紀錄")

            if store.history.isEmpty {
                Text("還沒有任何一輪打撈紀錄。回垃圾場開一輪吧。")
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
            } else {
                VStack(spacing: Space.s) {
                    ForEach(store.history) { record in
                        historyRow(record)
                        if record.id != store.history.last?.id { Divider() }
                    }
                }
                .junkCard()
            }
        }
    }

    private func historyRow(_ record: SessionRecord) -> some View {
        HStack(spacing: Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(YardFormat.dateTime(record.date))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInk)
                Text("保留 \(record.keptCount)・封存 \(record.archivedCount)・移除 \(record.removedCount)・跳過 \(record.skippedCount)")
                    .font(.caption2)
                    .foregroundStyle(Color.yardInkMuted)
            }
            Spacer(minLength: Space.s)
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(record.xpEarned) XP")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.yardAmber)
                Text("\(record.loadBefore) → \(record.loadAfter)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Crusher

/// The crusher's permanent entry point.
///
/// Verdicts made outside a salvage run (in Explore or on the detail page) would
/// otherwise have nowhere to be finalised, so this card is the one place that always
/// shows what is pending and what finalising it will really do.
struct CrusherCard: View {
    @Environment(YardStore.self) private var store

    @State private var showConfirmation = false
    @State private var isWorking = false

    var body: some View {
        let pending = store.removedItems
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(
                title: "壓碎機",
                subtitle: pending.isEmpty ? "沒有待處理的項目" : "\(pending.count) 件已標記移除，尚未處理"
            )

            if !pending.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(pending.prefix(12)) { item in
                            VStack(spacing: Space.xs) {
                                ItemThumbnail(item: item, size: 56, showsVerdict: false)
                                Text(YardFormat.bytes(item.byteSize))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.yardInkMuted)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()

                FactRow(label: "可回收容量", value: YardFormat.bytes(store.markedBytes))

                Button {
                    showConfirmation = true
                } label: {
                    HStack(spacing: Space.s) {
                        if isWorking {
                            ProgressView().controlSize(.small)
                            Text("處理中…")
                        } else {
                            Image(systemName: "trash.fill")
                            Text("處理壓碎機")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.yardDanger)
                .disabled(isWorking)
            }

            if let report = store.crusherReport {
                Divider()
                VStack(alignment: .leading, spacing: Space.xs) {
                    if report.deletedFromLibrary > 0 {
                        Text("已從相片圖庫刪除 \(report.deletedFromLibrary) 件，釋放 \(YardFormat.bytes(report.releasedBytes))。照片會在系統「最近刪除」保留 30 天。")
                    }
                    if report.removedLocally > 0 {
                        Text("\(report.removedLocally) 件示範資料已離開垃圾場，未釋放真實空間。")
                    }
                    if report.libraryDeletionCancelled {
                        Text("你在系統對話框取消了照片刪除，那些項目仍留在壓碎機裡。")
                            .foregroundStyle(Color.yardTerracotta)
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .junkCard()
        .confirmationDialog(
            "要處理 \(pending.count) 件嗎？",
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button("處理", role: .destructive) {
                Task {
                    isWorking = true
                    await store.emptyCrusher()
                    isWorking = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(explanation(for: pending))
        }
    }

    private func explanation(for pending: [JunkItem]) -> String {
        let assets = pending.filter { $0.assetIdentifier != nil }.count
        var lines: [String] = []
        if assets > 0 {
            lines.append("其中 \(assets) 件是相片圖庫的照片。iOS 會再向你確認一次，刪除後進入「最近刪除」，30 天內都能救回。")
        }
        if pending.count - assets > 0 {
            lines.append("其餘 \(pending.count - assets) 件是示範資料，只會離開這個 App，不影響任何真實檔案。")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Time capsule

/// 時間膠囊. The answer to "I daren't delete this": seal it for 30 days, and let the
/// app ask again once the anxiety has expired.
struct TimeCapsuleView: View {
    @Environment(YardStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ButlerBubble(text: store.sealedItems.isEmpty
                             ? "膠囊是空的。你最近的決定都很果斷。"
                             : "封存不是逃避，是延後判決。30 天後我會再問你一次。")

                if store.sealedItems.isEmpty {
                    YardEmptyState(
                        symbolName: "archivebox",
                        title: "膠囊裡沒有東西",
                        message: "在打撈作業裡上滑，就可以把不敢刪的項目封存 30 天。",
                        tint: .yardAmber
                    )
                } else {
                    VStack(spacing: Space.m) {
                        ForEach(store.sealedItems) { item in
                            capsuleRow(item)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxxl)
        }
        .background(Color.yardCanvas)
        .navigationTitle("時間膠囊")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func capsuleRow(_ item: JunkItem) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            NavigationLink(value: item.id) {
                ItemRow(
                    item: item,
                    score: store.score(for: item),
                    trailingText: item.daysRemainingSealed.map { "剩 \($0) 天" }
                )
            }
            .buttonStyle(.plain)

            if let days = item.daysRemainingSealed {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.yardSurfaceAlt)
                        Capsule()
                            .fill(Color.yardAmber)
                            .frame(width: max(6, geo.size.width * (1 - Double(days) / 30)))
                    }
                }
                .frame(height: 6)
            }

            HStack(spacing: Space.s) {
                Button("提前取出") {
                    store.releaseFromCapsule(item.id)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.yardRecycle)

                Spacer()

                Text("到期後會自動回到垃圾場")
                    .font(.caption2)
                    .foregroundStyle(Color.yardInkMuted)
            }
        }
        .junkCard(padding: Space.m)
    }
}

#Preview {
    RecordView()
        .environment(YardStore.demo())
}
