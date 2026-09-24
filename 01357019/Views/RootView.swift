import SwiftUI

/// A request to open a salvage run. Wrapped in a type because "no pile" (the whole yard)
/// is a valid target, so a plain optional binding would be ambiguous.
struct RunRequest: Identifiable, Hashable {
    var id = UUID()
    var pile: PileID?
}

struct RootView: View {
    @Environment(YardStore.self) private var store

    /// Named `YardTab` rather than `Tab` so it does not shadow SwiftUI's `Tab` view.
    enum YardTab: Hashable {
        case yard, explore, suggest, record
    }

    @State private var selection: YardTab = .yard

    var body: some View {
        TabView(selection: $selection) {
            Tab("垃圾場", systemImage: "trash.square.fill", value: YardTab.yard) {
                YardHomeView()
            }
            Tab("探索", systemImage: "square.grid.2x2", value: YardTab.explore) {
                ExploreView()
            }
            Tab("建議", systemImage: "wand.and.sparkles", value: YardTab.suggest) {
                SuggestionsView()
            }
            Tab("紀錄", systemImage: "chart.bar.fill", value: YardTab.record) {
                RecordView()
            }
        }
        .tint(Color.yardRecycle)
        // The undo affordance is global: a mis-swipe anywhere is recoverable for 5 seconds.
        .overlay(alignment: .bottom) {
            if let entry = store.undoEntry {
                UndoToast(
                    message: entry.message,
                    onUndo: { withAnimation(.snappy) { store.undoLast() } },
                    onDismiss: { withAnimation(.snappy) { store.dismissUndo() } }
                )
                .id(entry.id)
                .padding(.bottom, 68)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { store.refreshStorage() }
    }
}

#Preview {
    RootView()
        .environment(YardStore.demo())
}
