import SwiftUI

/// ② 垃圾場探索頁
///
/// Two ways to look at a pile: a heap (irregular, physical, the default) and a grid
/// (orderly, for comparing). Neither is a plain list, which is the point.
struct ExploreView: View {
    @Environment(YardStore.self) private var store

    enum ViewMode: String, CaseIterable, Identifiable {
        case heap, grid
        var id: String { rawValue }
        var title: String { self == .heap ? "堆積" : "網格" }
        var symbolName: String { self == .heap ? "square.3.layers.3d" : "square.grid.2x2" }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case score, size, date, name
        var id: String { rawValue }
        var title: String {
            switch self {
            case .score: "垃圾指數"
            case .size: "檔案大小"
            case .date: "建立日期"
            case .name: "檔名"
            }
        }
    }

    enum StatusFilter: String, CaseIterable, Identifiable {
        case pending, decided, sealed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pending: "待整理"
            case .decided: "已判決"
            case .sealed: "封存中"
            }
        }
    }

    @State private var selectedPile: PileID?
    @State private var mode: ViewMode = .heap
    @State private var sort: SortOrder = .score
    @State private var status: StatusFilter = .pending
    @State private var kindFilter: JunkKind?
    @State private var runRequest: RunRequest?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    pileCarousel
                    controls
                    content
                }
                .padding(.bottom, Space.xxxl)
            }
            .background(Color.yardCanvas)
            .navigationTitle("探索")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        runRequest = RunRequest(pile: selectedPile)
                    } label: {
                        Label("打撈這堆", systemImage: "scanner")
                    }
                    .disabled(store.items(in: selectedPile).isEmpty)
                }
            }
            .navigationDestination(for: UUID.self) { id in
                ItemDetailView(itemID: id)
            }
            .fullScreenCover(item: $runRequest) { request in
                SalvageRunView(pile: request.pile)
            }
        }
    }

    // MARK: Piles

    private var pileCarousel: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(title: "廢料堆", subtitle: "一件雜物可以同時屬於好幾堆")
                .padding(.horizontal, Space.gutter)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.m) {
                    allPileTile
                    ForEach(PileID.allCases) { pile in
                        Button {
                            withAnimation(.snappy) {
                                selectedPile = selectedPile == pile ? nil : pile
                            }
                        } label: {
                            PileTile(
                                pile: pile,
                                count: store.pendingCount(in: pile),
                                averageScore: store.averageScore(in: pile),
                                isSelected: selectedPile == pile
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.vertical, Space.xs)
            }
            .scrollClipDisabled()

            if let selectedPile {
                Text(selectedPile.blurb)
                    .font(.yardCallout)
                    .foregroundStyle(Color.yardInkMuted)
                    .padding(.horizontal, Space.gutter)
            }
        }
    }

    private var allPileTile: some View {
        Button {
            withAnimation(.snappy) { selectedPile = nil }
        } label: {
            VStack(alignment: .leading, spacing: Space.s) {
                JunkGlyph(symbolName: "tray.full.fill", tint: .yardInkMuted, size: 38)
                Text("全部")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.yardInk)
                Text("\(store.pendingItems.count) 件")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
                LevelBadge(level: store.loadLevel, compact: true)
            }
            .frame(width: 132, alignment: .leading)
            .padding(Space.m)
            .background(
                selectedPile == nil ? Color.yardInkMuted.opacity(0.12) : Color.yardSurface,
                in: .rect(cornerRadius: Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(
                        selectedPile == nil ? Color.yardInkMuted.opacity(0.5) : Color.yardHairline,
                        lineWidth: selectedPile == nil ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack {
                Picker("檢視方式", selection: $mode) {
                    ForEach(ViewMode.allCases) { item in
                        Label(item.title, systemImage: item.symbolName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Spacer()

                Menu {
                    Picker("排序", selection: $sort) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                } label: {
                    Label(sort.title, systemImage: "arrow.up.arrow.down")
                        .font(.caption.weight(.medium))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(StatusFilter.allCases) { filter in
                        FilterChip(
                            title: filter.title,
                            isOn: status == filter,
                            tint: .yardRecycle
                        ) {
                            status = filter
                        }
                    }

                    Divider().frame(height: 20)

                    ForEach(JunkKind.allCases) { kind in
                        FilterChip(
                            title: kind.title,
                            isOn: kindFilter == kind,
                            tint: kind.tint
                        ) {
                            kindFilter = kindFilter == kind ? nil : kind
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
        .padding(.horizontal, Space.gutter)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        let items = filteredItems

        if items.isEmpty {
            YardEmptyState(
                symbolName: selectedPile?.symbolName ?? "tray",
                title: "這裡沒有東西",
                message: "換個廢料堆或放寬篩選條件看看。"
            )
        } else {
            switch mode {
            case .heap:
                heapLayout(items)
            case .grid:
                gridLayout(items)
            }
        }
    }

    private func heapLayout(_ items: [JunkItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100), spacing: Space.l)],
            alignment: .leading,
            spacing: Space.xl
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink(value: item.id) {
                    HeapTile(item: item, score: store.score(for: item), index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.top, Space.s)
    }

    private func gridLayout(_ items: [JunkItem]) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: Space.m)],
            spacing: Space.m
        ) {
            ForEach(items) { item in
                NavigationLink(value: item.id) {
                    ItemTile(item: item, score: store.score(for: item))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Space.gutter)
    }

    // MARK: Filtering

    private var filteredItems: [JunkItem] {
        var items = store.items(in: selectedPile, includeDecided: true)

        switch status {
        case .pending: items = items.filter { !$0.isDecided }
        case .decided: items = items.filter(\.isDecided)
        case .sealed: items = items.filter(\.isSealed)
        }

        if let kindFilter {
            items = items.filter { $0.kind == kindFilter }
        }

        switch sort {
        case .score:
            items.sort { store.score(for: $0).value > store.score(for: $1).value }
        case .size:
            items.sort { ($0.byteSize ?? 0) > ($1.byteSize ?? 0) }
        case .date:
            items.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .name:
            items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        return items
    }
}

// MARK: - Filter chip

struct FilterChip: View {
    var title: String
    var isOn: Bool
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isOn ? tint : Color.yardInkMuted)
                .padding(.horizontal, Space.m)
                .padding(.vertical, Space.s)
                .background(isOn ? tint.opacity(0.16) : Color.yardSurfaceAlt, in: .capsule)
                .overlay {
                    Capsule().strokeBorder(isOn ? tint.opacity(0.5) : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ExploreView()
        .environment(YardStore.demo())
}
