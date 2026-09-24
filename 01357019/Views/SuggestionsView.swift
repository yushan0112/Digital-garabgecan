import SwiftUI

/// ④ AI 整理建議頁
///
/// No chat box anywhere. Suggestions arrive as reviewable cards, each carrying its own
/// basis and confidence, and each individually acceptable, rejectable or editable.
struct SuggestionsView: View {
    @Environment(YardStore.self) private var store

    @State private var suggestions: [Suggestion] = []
    @State private var dataGaps = 0
    @State private var editing: Suggestion?
    @State private var editedValue = ""
    @State private var showApplyConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    engineBanner

                    ForEach(SuggestionKind.allCases) { kind in
                        section(for: kind)
                    }

                    disclaimer
                }
                .padding(.horizontal, Space.gutter)
                .padding(.bottom, Space.xxxl)
            }
            .background(Color.yardCanvas)
            .navigationTitle("整理建議")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        rebuild()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("重新分析")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
            .safeAreaInset(edge: .bottom) {
                applyBar
            }
            .sheet(item: $editing) { suggestion in
                editSheet(for: suggestion)
            }
            .confirmationDialog(
                "要套用 \(acceptedCount) 項建議嗎？",
                isPresented: $showApplyConfirmation,
                titleVisibility: .visible
            ) {
                Button("套用", role: .destructive) { applyAccepted() }
                Button("取消", role: .cancel) {}
            } message: {
                Text(applyExplanation)
            }
            .task {
                if suggestions.isEmpty { rebuild() }
            }
        }
    }

    // MARK: Engine banner

    private var engineBanner: some View {
        let engine = store.analysisEngine
        return HStack(alignment: .top, spacing: Space.m) {
            Image(systemName: engine.symbolName)
                .font(.title3)
                .foregroundStyle(engine == .onDeviceModel ? Color.yardRecycle : Color.yardInkMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text("分析引擎：\(engine.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.yardInk)
                Text(engine.explanation)
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .junkCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Section

    @ViewBuilder
    private func section(for kind: SuggestionKind) -> some View {
        let group = suggestions.filter { $0.kind == kind }

        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: kind.title, subtitle: subtitle(for: kind, count: group.count)) {
                Image(systemName: kind.symbolName)
                    .foregroundStyle(Color.yardInkMuted)
            }

            if kind == .dormant && dataGaps > 0 {
                HStack(spacing: Space.s) {
                    Image(systemName: "info.circle")
                    Text("另有 \(dataGaps) 件沒有建立日期，資料不足，無法判斷是否長期未使用。")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(Color.yardInkMuted)
                .padding(Space.m)
                .background(Color.yardSurfaceAlt, in: .rect(cornerRadius: Radius.chip))
            }

            if group.isEmpty {
                Text("目前沒有這類建議。")
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
            } else {
                ForEach(group.prefix(6)) { suggestion in
                    SuggestionCardView(
                        suggestion: suggestion,
                        items: suggestion.itemIDs.compactMap { store.item(id: $0) },
                        keepItemID: suggestion.keepItemID,
                        onAccept: { setState(.accepted, for: suggestion) },
                        onReject: { setState(.rejected, for: suggestion) },
                        onEdit: {
                            editedValue = suggestion.proposedValue ?? ""
                            editing = suggestion
                        }
                    )
                }
            }
        }
    }

    private func subtitle(for kind: SuggestionKind, count: Int) -> String {
        switch kind {
        case .category: "依檔名關鍵字與類型推測，共 \(count) 項"
        case .rename: "把系統自動命名換成看得懂的名字，共 \(count) 項"
        case .duplicate: "中繼資料高度相似的群組，共 \(count) 組"
        case .dormant: "只在有可靠日期時才提出，共 \(count) 項"
        }
    }

    // MARK: Apply bar

    @ViewBuilder
    private var applyBar: some View {
        if acceptedCount > 0 {
            Button {
                showApplyConfirmation = true
            } label: {
                Label("套用 \(acceptedCount) 項建議", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.xs)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.yardRecycle)
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.m)
        }
    }

    private var disclaimer: some View {
        Text("所有建議都在裝置上產生，不會上傳任何檔案或中繼資料。建議可能有誤，最終決定權在你。")
            .font(.caption2)
            .foregroundStyle(Color.yardInkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.s)
    }

    // MARK: Edit sheet

    private func editSheet(for suggestion: Suggestion) -> some View {
        NavigationStack {
            Form {
                Section("修改建議內容") {
                    TextField("內容", text: $editedValue, axis: .vertical)
                }
                Section("原本的建議") {
                    Text(suggestion.proposedValue ?? suggestion.headline)
                        .font(.caption)
                        .foregroundStyle(Color.yardInkMuted)
                }
            }
            .navigationTitle(suggestion.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { editing = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("接受修改") {
                        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
                        suggestions[index].proposedValue = editedValue
                        suggestions[index].headline = editedValue
                        suggestions[index].state = .accepted
                        editing = nil
                    }
                    .disabled(editedValue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: State

    private var acceptedCount: Int {
        suggestions.filter { $0.state == .accepted }.count
    }

    private var applyExplanation: String {
        let duplicates = suggestions.filter { $0.state == .accepted && $0.kind == .duplicate }
        let removals = duplicates.reduce(0) { $0 + max(0, $1.itemIDs.count - 1) }
        if removals > 0 {
            return "其中 \(removals) 件會被標記移除（不會立刻刪除，會先進壓碎機，可以復原）。其餘只會改標籤或檔名。"
        }
        return "這些建議只會改動用途標籤或檔名，不會移除任何項目。"
    }

    private func setState(_ state: SuggestionState, for suggestion: Suggestion) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        withAnimation(.snappy) {
            suggestions[index].state = suggestions[index].state == state ? .pending : state
        }
        if store.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func applyAccepted() {
        for suggestion in suggestions where suggestion.state == .accepted {
            store.apply(suggestion)
        }
        rebuild()
    }

    private func rebuild() {
        let result = store.buildSuggestions()
        suggestions = result.suggestions
        dataGaps = result.dormantDataGaps
    }
}

// MARK: - Suggestion card

struct SuggestionCardView: View {
    var suggestion: Suggestion
    var items: [JunkItem]
    var keepItemID: UUID?
    var onAccept: () -> Void
    var onReject: () -> Void
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .top, spacing: Space.m) {
                if suggestion.kind == .duplicate {
                    twinStrip
                } else if let item = items.first {
                    ItemThumbnail(item: item, size: 56, showsVerdict: false)
                }

                VStack(alignment: .leading, spacing: Space.xs) {
                    if let item = items.first, suggestion.kind != .duplicate {
                        Text(item.name)
                            .font(.caption2)
                            .foregroundStyle(Color.yardInkMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(suggestion.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.yardInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(suggestion.detail)
                        .font(.caption)
                        .foregroundStyle(Color.yardInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack {
                ConfidenceMeter(confidence: suggestion.confidence)
                Spacer()
                BasisDisclosure(basis: suggestion.basis)
            }

            HStack(spacing: Space.s) {
                actionButton(
                    title: "接受",
                    symbol: "checkmark",
                    tint: .yardRecycle,
                    isActive: suggestion.state == .accepted,
                    action: onAccept
                )
                actionButton(
                    title: "拒絕",
                    symbol: "xmark",
                    tint: .yardInkMuted,
                    isActive: suggestion.state == .rejected,
                    action: onReject
                )
                if suggestion.proposedValue != nil {
                    actionButton(
                        title: "修改",
                        symbol: "pencil",
                        tint: .yardTerracotta,
                        isActive: false,
                        action: onEdit
                    )
                }
            }
        }
        .junkCard()
        .overlay {
            if suggestion.state == .rejected {
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(Color.yardCanvas.opacity(0.45))
                    .allowsHitTesting(false)
            }
        }
    }

    /// Duplicate groups show every member side by side with the keeper marked, so the
    /// user can see what they are agreeing to.
    private var twinStrip: some View {
        HStack(spacing: Space.xs) {
            ForEach(items.prefix(3)) { item in
                ZStack(alignment: .bottom) {
                    ItemThumbnail(item: item, size: 52, showsVerdict: false)
                        .opacity(item.id == keepItemID ? 1 : 0.5)
                    Image(systemName: item.id == keepItemID ? "star.fill" : "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(item.id == keepItemID ? Color.yardRecycle : Color.yardDanger, in: .circle)
                        .offset(y: 5)
                }
            }
        }
    }

    private func actionButton(
        title: String,
        symbol: String,
        tint: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isActive ? .white : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s)
                .background(isActive ? tint : tint.opacity(0.14), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    SuggestionsView()
        .environment(YardStore.demo())
}
