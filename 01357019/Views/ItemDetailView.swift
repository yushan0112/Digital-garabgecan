import SwiftUI

/// ③ 數位雜物詳細頁（鑑識台）
///
/// The knowledge core of the app: facts we actually have, a fully itemised score, the
/// butler's recommendation with its basis, and the purpose tag that defuses the score.
struct ItemDetailView: View {
    @Environment(YardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID
    /// Set when presented as a sheet from inside a salvage run.
    var onVerdict: ((Verdict) -> Void)?

    @State private var draftTag: String = ""
    @State private var showRemoveConfirmation = false
    @FocusState private var tagFieldFocused: Bool

    private let quickTags = ["課堂資料", "收據與帳單", "重要文件", "回憶備份", "迷因收藏", "以後再看"]

    var body: some View {
        Group {
            if let item = store.item(id: itemID) {
                content(for: item)
            } else {
                YardEmptyState(
                    symbolName: "questionmark.square.dashed",
                    title: "這件雜物不在了",
                    message: "它可能已經被送進壓碎機。"
                )
            }
        }
        .background(Color.yardCanvas)
        .navigationTitle("鑑識台")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Content

    private func content(for item: JunkItem) -> some View {
        let score = store.score(for: item)
        let advice = store.advice(for: item)

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                PreviewHero(item: item, score: score)

                header(for: item)
                factCard(for: item)
                scoreCard(score: score)
                adviceCard(advice: advice, item: item)
                purposeCard(for: item)

                if item.isDecided {
                    decidedNotice(for: item)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.xxxl)
        }
        .safeAreaInset(edge: .bottom) {
            verdictBar(for: item)
        }
        .onAppear { draftTag = item.purposeTag ?? "" }
        .confirmationDialog(
            "要把「\(item.name)」送進壓碎機嗎？",
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("標記移除", role: .destructive) {
                apply(.remove, to: item)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(removalExplanation(for: item))
        }
    }

    // MARK: Header

    private func header(for item: JunkItem) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(item.name)
                .font(.yardTitle)
                .foregroundStyle(Color.yardInk)
                .fixedSize(horizontal: false, vertical: true)

            let piles = store.piles(for: item)
            if !piles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(piles) { pile in
                            Label(pile.title, systemImage: pile.symbolName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(pile.tint)
                                .padding(.horizontal, Space.s)
                                .padding(.vertical, Space.xs)
                                .background(pile.tint.opacity(0.14), in: .capsule)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Facts

    private func factCard(for item: JunkItem) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "我們知道的事", subtitle: "缺少的欄位就寫「未提供」")
            VStack(spacing: Space.s) {
                FactRow(label: "檔名", value: item.name)
                Divider()
                FactRow(label: "類型", value: item.kind.title)
                Divider()
                FactRow(label: "大小", value: YardFormat.bytes(item.byteSize))
                Divider()
                FactRow(label: "建立日期", value: YardFormat.date(item.createdAt))
                Divider()
                FactRow(label: "距今", value: YardFormat.relativeDays(item.createdAt))
                Divider()
                FactRow(label: "雙胞胎組", value: item.twinGroup ?? "未提供")
                Divider()
                FactRow(label: "用途標籤", value: item.purposeTag ?? "未提供")
            }

            Text("iOS 不提供檔案的開啟紀錄，所以這裡看不到「上次使用時間」。")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
        .junkCard()
    }

    // MARK: Score

    private func scoreCard(score: JunkScore) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("垃圾指數")
                        .yardTagCase()
                        .foregroundStyle(Color.yardInkMuted)
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text("\(score.value)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(Color.yardInk)
                        LevelBadge(level: score.level)
                    }
                }
                Spacer()
            }

            Divider()
            ScoreBreakdownView(score: score)
        }
        .junkCard()
    }

    // MARK: Advice

    private func adviceCard(advice: ButlerAdvice, item: JunkItem) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                SectionHeader(title: "整理建議")
                Spacer()
                ConfidenceMeter(confidence: advice.confidence)
            }

            HStack(spacing: Space.s) {
                Image(systemName: advice.suggestedVerdict.symbolName)
                    .font(.caption.weight(.bold))
                Text(advice.headline)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(advice.suggestedVerdict.tint)

            ButlerBubble(text: advice.body)

            if let snark = store.snark(for: item), snark != advice.body {
                Text(snark)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.yardInkMuted)
            }

            BasisDisclosure(basis: advice.basis)
        }
        .junkCard()
    }

    // MARK: Purpose

    private func purposeCard(for item: JunkItem) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "這個檔案是幹嘛用的？", subtitle: "標記用途會直接扣 40 分，而且賈維鏽會閉嘴")

            HStack(spacing: Space.s) {
                TextField("例如：作業系統期末報告", text: $draftTag)
                    .textFieldStyle(.plain)
                    .focused($tagFieldFocused)
                    .padding(Space.m)
                    .background(Color.yardSurfaceAlt, in: .rect(cornerRadius: Radius.chip))
                    .submitLabel(.done)
                    .onSubmit { saveTag(for: item) }

                Button("儲存") { saveTag(for: item) }
                    .buttonStyle(.glass)
                    .disabled(draftTag.trimmingCharacters(in: .whitespaces) == (item.purposeTag ?? ""))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(quickTags, id: \.self) { tag in
                        FilterChip(title: tag, isOn: draftTag == tag, tint: .yardRecycle) {
                            draftTag = tag
                            saveTag(for: item)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()

            if item.hasPurposeTag {
                Button("清除用途標籤", role: .destructive) {
                    draftTag = ""
                    store.setPurpose(nil, for: item.id)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.yardDanger)
            }
        }
        .junkCard()
    }

    // MARK: Decided notice

    private func decidedNotice(for item: JunkItem) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: item.verdict?.symbolName ?? "checkmark")
                .foregroundStyle(item.verdict?.tint ?? Color.yardInkMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text("目前狀態：已\(item.verdict?.title ?? "")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.yardInk)
                if let days = item.daysRemainingSealed, item.isSealed {
                    Text("封存中，還有 \(days) 天到期")
                        .font(.caption2)
                        .foregroundStyle(Color.yardInkMuted)
                }
            }
            Spacer(minLength: 0)
            Button("重新判決") {
                store.releaseFromCapsule(item.id)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(Color.yardTerracotta)
        }
        .junkCard(padding: Space.m)
    }

    // MARK: Verdict bar

    private func verdictBar(for item: JunkItem) -> some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                ForEach(Verdict.allCases) { verdict in
                    VerdictButton(verdict: verdict, isCompact: true) {
                        if verdict.isDestructive {
                            showRemoveConfirmation = true
                        } else {
                            apply(verdict, to: item)
                        }
                    }
                }
            }
            Text("移除會先進入壓碎機，確認前隨時可以復原。")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.m)
        .padding(.bottom, Space.s)
        .background(.bar)
    }

    // MARK: Actions

    private func apply(_ verdict: Verdict, to item: JunkItem) {
        store.decide(verdict, for: item.id)
        if store.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: verdict.isDestructive ? .heavy : .rigid).impactOccurred()
        }
        if let onVerdict {
            onVerdict(verdict)
        } else {
            dismiss()
        }
    }

    private func saveTag(for item: JunkItem) {
        store.setPurpose(draftTag, for: item.id)
        tagFieldFocused = false
        if store.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func removalExplanation(for item: JunkItem) -> String {
        if item.assetIdentifier != nil {
            return "這是相片圖庫裡的項目。確認清空壓碎機後，系統會再次向你確認，並把它放進「最近刪除」，30 天內都可以救回。"
        }
        return "這是示範垃圾場的項目，不會影響你裝置上任何真實檔案。它會先被標記移除，之後在壓碎機裡一次處理。"
    }
}

#Preview {
    // One store, so the id actually resolves inside the view.
    let store = YardStore.demo()
    NavigationStack {
        ItemDetailView(itemID: store.items[0].id)
    }
    .environment(store)
}
