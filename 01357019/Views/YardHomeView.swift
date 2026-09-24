import SwiftUI

/// ① 垃圾場｜首頁
///
/// Deliberately not a list. The first screen is a reading (the gauge), a set of piles,
/// and one clear action — the inventory lives behind the Explore tab.
struct YardHomeView: View {
    @Environment(YardStore.self) private var store

    @State private var runRequest: RunRequest?
    @State private var showSettings = false
    @State private var bubbleText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.xl) {
                    ButlerBubble(text: bubbleText ?? store.greeting) { rerollBubble() }

                    JunkLoadGauge(
                        value: store.junkLoad,
                        caption: store.pendingItems.isEmpty
                            ? "沒有待整理的項目"
                            : "\(store.pendingItems.count) 件待整理・平均指數"
                    )
                    .frame(maxWidth: .infinity)

                    statRow

                    Button {
                        runRequest = RunRequest(pile: nil)
                    } label: {
                        Label("進入垃圾場", systemImage: "scanner")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.xs)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Color.yardRecycle)
                    .disabled(store.pendingItems.isEmpty)

                    importCard
                    storageCard
                    tasksSection
                    capsuleCard
                    recentSection
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxxl)
            }
            .background(Color.yardCanvas)
            .navigationTitle("數位垃圾場")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("設定")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $runRequest) { request in
                SalvageRunView(pile: request.pile)
            }
        }
    }

    // MARK: Stats

    private var statRow: some View {
        HStack(spacing: Space.m) {
            StatTile(
                label: "待整理",
                value: "\(store.pendingItems.count)",
                footnote: "件",
                tint: .yardTerracotta
            )
            StatTile(
                label: "已判決",
                value: "\(store.decidedItems.count)",
                footnote: "件",
                tint: .yardRecycle
            )
            StatTile(
                label: "可釋放",
                value: YardFormat.bytes(store.markedBytes),
                footnote: "已標記移除",
                tint: .yardAmber
            )
        }
    }

    // MARK: Import

    /// Only shown until the user has imported something real — after that it would just
    /// be clutter, which would be ironic.
    @ViewBuilder
    private var importCard: some View {
        if store.photoBackedItems.isEmpty {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(
                    title: "把你自己的截圖倒進來",
                    subtitle: "目前場內是示範資料"
                )

                Text("我們只讀截圖的檔名、大小、日期和尺寸，照片不會離開這台裝置。")
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    Task { await store.importFromPhotos() }
                } label: {
                    HStack(spacing: Space.s) {
                        if store.importState == .working {
                            ProgressView().controlSize(.small)
                            Text("匯入中…")
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("匯入我的截圖")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.yardTerracotta)
                .disabled(store.importState == .working)

                if case .failed(let message) = store.importState {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(Color.yardDanger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .junkCard()
        }
    }

    // MARK: Storage

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "儲存空間", subtitle: "只顯示 iOS 真的提供的數字")
            StorageBar(snapshot: store.storage, trackedBytes: store.trackedBytes)
        }
        .junkCard()
    }

    // MARK: Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "今日可執行的任務", subtitle: "每一項都是一輪短打撈")
            ForEach(store.dailyTasks) { task in
                TaskCard(task: task) {
                    runRequest = RunRequest(pile: task.pile)
                }
            }
        }
    }

    // MARK: Capsule

    @ViewBuilder
    private var capsuleCard: some View {
        if !store.sealedItems.isEmpty {
            NavigationLink {
                TimeCapsuleView()
            } label: {
                HStack(spacing: Space.m) {
                    JunkGlyph(symbolName: "archivebox.fill", tint: .yardAmber, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("時間膠囊")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.yardInk)
                        Text("\(store.sealedItems.count) 件封存中，到期會自動回到垃圾場")
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
    }

    // MARK: Recent

    @ViewBuilder
    private var recentSection: some View {
        if store.recentDiscoveries.isEmpty {
            YardEmptyState(
                symbolName: "checkmark.seal",
                title: "垃圾場清空了",
                message: "所有項目都有結論。封存的項目到期後會自己回來。"
            )
        } else {
            VStack(alignment: .leading, spacing: Space.m) {
                SectionHeader(title: "最近發現的數位雜物", subtitle: "指數最新、還沒有結論的項目")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.m) {
                        ForEach(store.recentDiscoveries) { item in
                            NavigationLink(value: item.id) {
                                VStack(alignment: .leading, spacing: Space.s) {
                                    ItemThumbnail(item: item, size: 104)
                                        .overlay(alignment: .topTrailing) {
                                            ScoreChip(score: store.score(for: item))
                                                .padding(Space.xs)
                                        }
                                    Text(item.name)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Color.yardInk)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .frame(width: 104, alignment: .leading)
                                    Text(YardFormat.relativeDays(item.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(Color.yardInkMuted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Space.xs)
                }
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Butler

    /// Tapping the butler makes him pick on a specific item instead of repeating the
    /// greeting — cheap, and it makes the character feel reactive.
    private func rerollBubble() {
        let candidates = store.pendingItems.compactMap { item -> String? in
            store.snark(for: item)
        }
        bubbleText = candidates.randomElement() ?? store.greeting
    }
}

#Preview {
    YardHomeView()
        .environment(YardStore.demo())
}
