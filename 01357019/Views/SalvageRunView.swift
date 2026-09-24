import SwiftUI

/// 打撈作業 — the salvage run.
///
/// The core loop, and the bridge between the home screen and the results screen: one
/// item at a time, four possible verdicts, and XP for deciding rather than for deleting.
/// Swiping is the fun path; the four buttons underneath are the accessible path and do
/// exactly the same thing.
struct SalvageRunView: View {
    let pile: PileID?

    @Environment(YardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var record: SessionRecord?
    @State private var drag: CGSize = .zero
    @State private var quip: String?
    @State private var detailTarget: DetailTarget?
    @State private var hasStarted = false

    private let threshold: CGFloat = 110

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yardCanvas.ignoresSafeArea()

                if let record {
                    ResultsView(record: record) { dismiss() }
                } else if let run = store.run,
                          let currentID = run.currentItemID,
                          let item = store.item(id: currentID) {
                    runContent(run: run, item: item)
                } else {
                    YardEmptyState(
                        symbolName: "checkmark.seal",
                        title: "這堆沒有待整理的項目",
                        message: "換一堆，或者先去建議頁看看有什麼可以批次處理的。"
                    )
                    .safeAreaInset(edge: .bottom) {
                        Button("關閉") { dismiss() }
                            .buttonStyle(.glass)
                            .padding(.bottom, Space.xl)
                    }
                }
            }
            // The run is presented full screen, so RootView's global toast is covered.
            // A mis-swipe has to be recoverable here too.
            .overlay(alignment: .bottom) {
                if let entry = store.undoEntry, record == nil {
                    UndoToast(
                        message: entry.message,
                        onUndo: { withAnimation(.snappy) { store.undoLast() } },
                        onDismiss: { withAnimation(.snappy) { store.dismissUndo() } }
                    )
                    .id(entry.id)
                    .padding(.bottom, Space.xxxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(record == nil ? "審判庭" : "整理成果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        finish()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("結束打撈")
                }
            }
            .sheet(item: $detailTarget) { target in
                NavigationStack {
                    ItemDetailView(itemID: target.id) { _ in
                        detailTarget = nil
                        drag = .zero
                    }
                }
            }
        }
        .task {
            guard !hasStarted else { return }
            store.startRun(pile: pile, limit: 10)
            hasStarted = true
        }
        .onChange(of: store.run?.isFinished ?? false) { _, isFinished in
            guard isFinished, record == nil else { return }
            finish()
        }
    }

    // MARK: Run

    private func runContent(run: RunSession, item: JunkItem) -> some View {
        VStack(spacing: Space.l) {
            progressHeader(run: run)

            ZStack {
                ForEach(upcoming(run: run).reversed()) { entry in
                    card(for: entry.item, depth: entry.id)
                        .zIndex(Double(-entry.id))
                }

                card(for: item, depth: 0)
                    .offset(x: drag.width, y: drag.height)
                    .rotationEffect(.degrees(Double(drag.width) / 22))
                    .overlay(alignment: .top) { dragHint }
                    .gesture(dragGesture(for: item))
                    .onTapGesture { detailTarget = DetailTarget(id: item.id) }
                    .zIndex(1)
            }
            .frame(maxHeight: .infinity)

            if let quip {
                Text(quip)
                    .font(.yardCallout)
                    .foregroundStyle(Color.yardInkMuted)
                    .transition(.opacity)
            }

            verdictButtons(for: item)
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.l)
    }

    private func progressHeader(run: RunSession) -> some View {
        VStack(spacing: Space.s) {
            HStack {
                Text(pile?.title ?? "整座垃圾場")
                    .yardTagCase()
                    .foregroundStyle(Color.yardInkMuted)
                Spacer()
                Text(run.progressText)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInk)
            }
            HStack(spacing: 3) {
                ForEach(0..<run.itemIDs.count, id: \.self) { index in
                    Capsule()
                        .fill(index < run.cursor ? Color.yardRecycle : Color.yardSurfaceAlt)
                        .frame(height: 5)
                }
            }
            HStack {
                Label("+\(run.xpEarned) XP", systemImage: "bolt.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.yardAmber)
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("進度 \(run.progressText)，已獲得 \(run.xpEarned) 經驗值")
    }

    // MARK: Card

    private func card(for item: JunkItem, depth: Int) -> some View {
        let score = store.score(for: item)

        return VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                LevelBadge(level: score.level)
                Spacer()
                ScoreChip(score: score)
            }

            ItemThumbnail(item: item, size: 150, showsVerdict: false)
                .frame(maxWidth: .infinity)

            Text(item.name)
                .font(.yardHeadline)
                .foregroundStyle(Color.yardInk)
                .lineLimit(2)
                .truncationMode(.middle)

            VStack(spacing: Space.xs) {
                FactRow(label: "類型", value: item.kind.title)
                FactRow(label: "大小", value: YardFormat.bytes(item.byteSize))
                FactRow(label: "建立", value: YardFormat.relativeDays(item.createdAt))
            }

            if let top = score.factors.first(where: \.isPenalty) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text("主要問題：\(top.label)")
                        .font(.caption)
                }
                .foregroundStyle(Color.yardTerracotta)
            }

            Spacer(minLength: 0)

            Text("點一下卡片可以進鑑識台調查")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity)
        .frame(height: 430)
        .background(Color.yardSurface, in: .rect(cornerRadius: Radius.hero))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.hero)
                .strokeBorder(Color.yardHairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(depth == 0 ? 0.10 : 0.04), radius: 14, y: 6)
        .scaleEffect(1 - CGFloat(depth) * 0.04)
        .offset(y: CGFloat(depth) * 14)
        .opacity(depth == 0 ? 1 : 0.55)
        .allowsHitTesting(depth == 0)
    }

    /// The two cards peeking out behind the current one, so the pile has depth.
    private func upcoming(run: RunSession) -> [UpcomingCard] {
        (1...2).compactMap { offset in
            let index = run.cursor + offset
            guard index < run.itemIDs.count, let item = store.item(id: run.itemIDs[index]) else { return nil }
            return UpcomingCard(id: offset, item: item)
        }
    }

    // MARK: Drag

    @ViewBuilder
    private var dragHint: some View {
        if let verdict = pendingVerdict {
            HStack(spacing: Space.s) {
                Image(systemName: verdict.symbolName)
                Text(verdict.title)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            .background(verdict.tint, in: .capsule)
            .padding(.top, Space.l)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var pendingVerdict: Verdict? {
        if drag.height < -threshold { return .archive }
        if drag.width > threshold { return .keep }
        if drag.width < -threshold { return .remove }
        return nil
    }

    private func dragGesture(for item: JunkItem) -> some Gesture {
        DragGesture()
            .onChanged { value in drag = value.translation }
            .onEnded { _ in
                if let verdict = pendingVerdict {
                    commit(verdict, for: item)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { drag = .zero }
                }
            }
    }

    // MARK: Verdict buttons

    private func verdictButtons(for item: JunkItem) -> some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                ForEach(Verdict.allCases) { verdict in
                    VerdictButton(verdict: verdict) { commit(verdict, for: item) }
                }
            }
            Text("左滑移除・右滑保留・上滑封存 30 天")
                .font(.caption2)
                .foregroundStyle(Color.yardInkMuted)
        }
    }

    // MARK: Actions

    private func commit(_ verdict: Verdict, for item: JunkItem) {
        if store.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: verdict.isDestructive ? .heavy : .rigid).impactOccurred()
        }

        let fly = CGSize(
            width: verdict == .keep ? 520 : (verdict == .remove ? -520 : 0),
            height: verdict == .archive ? -640 : 0
        )

        if reduceMotion {
            drag = .zero
        } else {
            withAnimation(.easeOut(duration: 0.22)) { drag = fly }
        }

        quip = store.settings.narrationEnabled
            ? ButlerScript.verdictQuip(verdict, item: item, tone: store.settings.butlerTone)
            : nil

        // Let the card fly off before the next one slides in.
        let delay: Duration = reduceMotion ? .zero : .milliseconds(180)
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            store.decide(verdict, for: item.id)
            drag = .zero
        }
    }

    private func finish() {
        record = store.finishRun()
        if record == nil { dismiss() }
    }
}

// MARK: - Small identifiable wrappers

/// `sheet(item:)` needs an `Identifiable`, and a bare `UUID` is not one.
struct DetailTarget: Identifiable {
    let id: UUID
}

/// One of the cards stacked behind the current item; `id` doubles as its depth.
private struct UpcomingCard: Identifiable {
    let id: Int
    let item: JunkItem
}

#Preview {
    SalvageRunView(pile: nil)
        .environment(YardStore.demo())
}
