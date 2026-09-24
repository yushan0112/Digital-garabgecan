import SwiftUI

/// ⑤ 整理成果頁
///
/// The one screen where it would be easiest to lie. It therefore reports "marked for
/// removal" and "actually released" as two separate lines, and never adds them together.
struct ResultsView: View {
    @Environment(YardStore.self) private var store

    let record: SessionRecord
    var onClose: () -> Void

    @State private var showCrusherConfirmation = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.l) {
                hero
                verdictSummary
                spaceReport
                keptItems
                badgeShelf
                progressCard
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxxl)
        }
        .background(Color.yardCanvas)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: Space.m) {
                // The width has to be set on the label: a button style hugs its content,
                // so a frame on the Button itself just pads the hit area.
                Button(action: onClose) {
                    Text("回垃圾場").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if record.removedCount > 0 {
                    Button {
                        showCrusherConfirmation = true
                    } label: {
                        Text("處理壓碎機").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.yardDanger)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.m)
        }
        .confirmationDialog(
            "要清空壓碎機嗎？",
            isPresented: $showCrusherConfirmation,
            titleVisibility: .visible
        ) {
            Button("確認處理 \(store.removedItems.count) 件", role: .destructive) {
                // Photo deletion is async: iOS presents its own confirmation next.
                Task { await store.emptyCrusher() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(crusherExplanation)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: Space.m) {
            Text("本次判決")
                .yardTagCase()
                .foregroundStyle(Color.yardInkMuted)

            Text("\(record.decidedCount) 件")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.yardInk)

            HStack(spacing: Space.m) {
                loadPill(value: record.loadBefore, label: "整理前")
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.yardInkMuted)
                loadPill(value: appeared ? record.loadAfter : record.loadBefore, label: "整理後")
            }

            ButlerBubble(
                text: ButlerScript.sessionSummary(
                    decided: record.decidedCount,
                    removed: record.removedCount,
                    tone: store.settings.butlerTone
                )
            )
        }
        .frame(maxWidth: .infinity)
        .junkCard()
    }

    private func loadPill(value: Int, label: String) -> some View {
        VStack(spacing: Space.xs) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
            Text("\(value)")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(ScoreLevel(score: value).tint)
        }
        .frame(width: 84)
        .padding(.vertical, Space.s)
        .background(ScoreLevel(score: value).tint.opacity(0.12), in: .rect(cornerRadius: Radius.chip))
    }

    // MARK: Verdicts

    private var verdictSummary: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "判決明細")
            HStack(spacing: Space.s) {
                summaryTile(.keep, count: record.keptCount)
                summaryTile(.archive, count: record.archivedCount)
                summaryTile(.remove, count: record.removedCount)
                summaryTile(.skip, count: record.skippedCount)
            }
        }
    }

    private func summaryTile(_ verdict: Verdict, count: Int) -> some View {
        VStack(spacing: Space.xs) {
            Image(systemName: verdict.symbolName)
                .font(.system(size: 15, weight: .semibold))
            Text("\(count)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(verdict.title)
                .font(.yardTag)
        }
        .foregroundStyle(verdict.tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .background(verdict.tint.opacity(0.12), in: .rect(cornerRadius: Radius.tile))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verdict.title) \(count) 件")
    }

    // MARK: Space

    private var spaceReport: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "空間", subtitle: "標記移除不等於已經釋放")

            VStack(spacing: Space.s) {
                FactRow(label: "已標記移除", value: YardFormat.bytes(record.markedBytes))
                Divider()
                FactRow(label: "實際釋放", value: YardFormat.bytes(record.releasedBytes))
                Divider()
                FactRow(label: "累積已壓碎", value: "\(store.crushedCount) 件・\(YardFormat.bytes(store.crushedBytes))")
            }

            Text(record.releasedBytes == 0
                 ? "這一輪沒有釋放任何真實空間：示範垃圾場的項目不是真的檔案，而相片圖庫的項目要等系統刪除確認後才算釋放。"
                 : "已釋放的空間來自系統確認刪除的項目。")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let report = store.crusherReport {
                Divider()
                VStack(alignment: .leading, spacing: Space.xs) {
                    Label("壓碎機結果", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.yardRecycle)
                    Text(crusherReportText(report))
                        .font(.caption2)
                        .foregroundStyle(Color.yardInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .junkCard()
    }

    // MARK: Kept

    @ViewBuilder
    private var keptItems: some View {
        let kept = store.keptItems.suffix(10).reversed().map { $0 }
        if !kept.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "你決定保留的項目", subtitle: "這些不會再出現在打撈作業裡")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        ForEach(kept) { item in
                            VStack(spacing: Space.xs) {
                                ItemThumbnail(item: item, size: 72, showsVerdict: false)
                                Text(item.name)
                                    .font(.caption2)
                                    .foregroundStyle(Color.yardInkMuted)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(width: 72)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Badges

    @ViewBuilder
    private var badgeShelf: some View {
        let newBadges = record.newBadgeIDs.compactMap { BadgeCatalog.badge(id: $0) }
        if !newBadges.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "新解鎖的成就")
                HStack(spacing: Space.m) {
                    ForEach(newBadges) { badge in
                        BadgeChip(badge: badge, isUnlocked: true)
                            .scaleEffect(appeared ? 1 : 0.6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
                    }
                    Spacer(minLength: 0)
                }
            }
            .junkCard()
        }
    }

    // MARK: Progress

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "進度", subtitle: "XP 來自「做出決定」，不是來自刪除")
            Label("本次 +\(record.xpEarned) XP", systemImage: "bolt.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.yardAmber)
            XPBar(level: store.level)
        }
        .junkCard()
    }

    private func crusherReportText(_ report: YardStore.CrusherReport) -> String {
        var lines: [String] = []
        if report.deletedFromLibrary > 0 {
            lines.append("已從相片圖庫刪除 \(report.deletedFromLibrary) 件，釋放 \(YardFormat.bytes(report.releasedBytes))，仍在系統「最近刪除」中 30 天。")
        }
        if report.removedLocally > 0 {
            lines.append("\(report.removedLocally) 件示範資料已離開垃圾場（不是真實檔案，未釋放空間）。")
        }
        if report.libraryDeletionCancelled {
            lines.append("你在系統對話框取消了照片刪除，那些項目仍留在壓碎機裡。")
        }
        return lines.joined(separator: "\n")
    }

    private var crusherExplanation: String {
        let realAssets = store.removedItems.filter { $0.assetIdentifier != nil }.count
        if realAssets > 0 {
            return "其中 \(realAssets) 件來自相片圖庫，系統會再向你確認一次，刪除後會進入「最近刪除」，30 天內可以救回。其餘是示範資料，只會從這個 App 的垃圾場移除。"
        }
        return "這些都是示範垃圾場的項目，只會從這個 App 的垃圾場移除，不會刪除你裝置上任何真實檔案，也不會釋放真實空間。"
    }
}

#Preview {
    ResultsView(
        record: SessionRecord(
            keptCount: 4,
            archivedCount: 2,
            removedCount: 3,
            skippedCount: 1,
            markedBytes: 440_401_920,
            releasedBytes: 0,
            xpEarned: 115,
            loadBefore: 78,
            loadAfter: 54,
            newBadgeIDs: ["first-verdict", "ten-verdicts"]
        ),
        onClose: {}
    )
    .environment(YardStore.demo())
}
