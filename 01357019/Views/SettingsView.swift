import SwiftUI

/// ⑥ 設定頁
///
/// Also where the app is honest in writing: a plain-language list of what it can and
/// cannot see, and destructive actions behind explicit confirmation.
struct SettingsView: View {
    @Environment(YardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showClearDecisions = false
    @State private var showEmptyCapsule = false
    @State private var showResetAll = false
    @State private var exportText: String?

    var body: some View {
        NavigationStack {
            Form {
                butlerSection
                aiSection
                dataSourceSection
                privacySection
                importExportSection
                dangerSection
                aboutSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: store.settings.butlerTone) { store.save() }
            .onChange(of: store.settings.narrationEnabled) { store.save() }
            .onChange(of: store.settings.hapticsEnabled) { store.save() }
            .onChange(of: store.settings.aiSuggestionsEnabled) { store.save() }
            .onChange(of: store.settings.ruleFallbackEnabled) { store.save() }
            .confirmationDialog("清除所有判決紀錄？", isPresented: $showClearDecisions, titleVisibility: .visible) {
                Button("清除判決與歷史", role: .destructive) { store.clearDecisions() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("所有項目會回到待整理狀態，打撈歷史會被刪除。用途標籤、XP 與成就會保留。這個動作無法復原。")
            }
            .confirmationDialog("清空時間膠囊？", isPresented: $showEmptyCapsule, titleVisibility: .visible) {
                Button("把 \(store.sealedItems.count) 件放回垃圾場", role: .destructive) { store.emptyCapsule() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("封存中的項目會立刻回到待整理狀態，不會刪除任何東西。")
            }
            .confirmationDialog("重置整個垃圾場？", isPresented: $showResetAll, titleVisibility: .visible) {
                Button("全部重置", role: .destructive) { store.resetEverything() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("會重新載入示範垃圾場，並清掉 XP、等級、成就、歷史與所有標籤。這個動作無法復原。")
            }
            .sheet(isPresented: Binding(get: { exportText != nil }, set: { if !$0 { exportText = nil } })) {
                exportSheet
            }
        }
    }

    // MARK: Butler

    private var butlerSection: some View {
        Section {
            Picker("語氣", selection: Binding(
                get: { store.settings.butlerTone },
                set: { store.settings.butlerTone = $0 }
            )) {
                ForEach(ButlerTone.allCases) { tone in
                    Text(tone.title).tag(tone)
                }
            }

            Text(store.settings.butlerTone.blurb)
                .font(.caption)
                .foregroundStyle(Color.yardInkMuted)

            Toggle("顯示旁白與吐槽", isOn: Binding(
                get: { store.settings.narrationEnabled },
                set: { store.settings.narrationEnabled = $0 }
            ))

            Toggle("觸覺回饋", isOn: Binding(
                get: { store.settings.hapticsEnabled },
                set: { store.settings.hapticsEnabled = $0 }
            ))
        } header: {
            Text("賈維鏽")
        } footer: {
            Text("語氣只影響文案，不影響任何評分或建議。")
        }
    }

    // MARK: AI

    private var aiSection: some View {
        Section {
            Toggle("啟用 AI 整理建議", isOn: Binding(
                get: { store.settings.aiSuggestionsEnabled },
                set: { store.settings.aiSuggestionsEnabled = $0 }
            ))

            Toggle("模型不可用時改用規則分析", isOn: Binding(
                get: { store.settings.ruleFallbackEnabled },
                set: { store.settings.ruleFallbackEnabled = $0 }
            ))
            .disabled(!store.settings.aiSuggestionsEnabled)

            HStack {
                Text("目前狀態")
                Spacer()
                Text(store.analysisEngine.title)
                    .foregroundStyle(Color.yardInkMuted)
            }

            Text(store.analysisEngine.explanation)
                .font(.caption)
                .foregroundStyle(Color.yardInkMuted)
        } header: {
            Text("AI 功能")
        } footer: {
            Text("使用的是裝置端模型。沒有網路請求，沒有伺服器，也沒有帳號。")
        }
    }

    // MARK: Data sources

    private var dataSourceSection: some View {
        Section {
            HStack {
                Label("示範垃圾場", systemImage: "cube.box")
                Spacer()
                Text("\(store.demoItems.count) 件")
                    .foregroundStyle(Color.yardInkMuted)
            }

            HStack {
                Label("相片圖庫", systemImage: "photo.on.rectangle")
                Spacer()
                Text(store.photoAccess.title)
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
            }

            HStack {
                Label("已匯入的照片項目", systemImage: "square.stack.3d.down.right")
                Spacer()
                Text("\(store.photoBackedItems.count) 件")
                    .foregroundStyle(Color.yardInkMuted)
            }

            Button {
                Task { await store.importFromPhotos() }
            } label: {
                HStack {
                    Label("匯入我的截圖", systemImage: "square.and.arrow.down")
                    Spacer()
                    if store.importState == .working {
                        ProgressView()
                    }
                }
            }
            .disabled(store.importState == .working || store.photoAccess == .denied || store.photoAccess == .restricted)

            if store.photoAccess == .limited {
                Button {
                    PhotoLibraryService.shared.presentLimitedLibraryPicker()
                } label: {
                    Label("管理可存取的照片", systemImage: "photo.badge.checkmark")
                }
            }

            if store.photoAccess == .denied || store.photoAccess == .restricted {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("到「設定」開啟照片權限", systemImage: "gear")
                }
            }

            importStatusRow

            if !store.demoItems.isEmpty && !store.photoBackedItems.isEmpty {
                Button("移除示範資料，只留我自己的照片", role: .destructive) {
                    store.removeDemoItems()
                }
            }

            HStack {
                Label("資料夾匯入", systemImage: "folder.badge.plus")
                Spacer()
                Text("P2 尚未啟用")
                    .font(.caption)
                    .foregroundStyle(Color.yardInkMuted)
            }
        } header: {
            Text("資料來源")
        } footer: {
            Text("匯入只讀取截圖的檔名、大小、日期與尺寸，照片本身不會離開這台裝置。若圖庫裡沒有截圖（例如模擬器），會改以一般照片示範。")
        }
    }

    @ViewBuilder
    private var importStatusRow: some View {
        switch store.importState {
        case .idle, .working:
            EmptyView()
        case .finished(let summary):
            VStack(alignment: .leading, spacing: 2) {
                Text("匯入完成：新增 \(summary.imported) 件（其中截圖 \(summary.screenshots) 件），跳過已存在 \(summary.skipped) 件。")
                Text("合計 \(YardFormat.bytes(summary.bytes))")
                    .foregroundStyle(Color.yardInkMuted)
            }
            .font(.caption)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(Color.yardDanger)
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            NavigationLink {
                privacyDetail
            } label: {
                Label("隱私說明", systemImage: "hand.raised")
            }

            NavigationLink {
                limitationDetail
            } label: {
                Label("這個 App 讀不到什麼", systemImage: "eye.slash")
            }
        } header: {
            Text("隱私")
        }
    }

    private var privacyDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ForEach(Self.privacyPoints, id: \.title) { point in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Label(point.title, systemImage: point.symbol)
                            .font(.headline)
                            .foregroundStyle(Color.yardInk)
                        Text(point.body)
                            .font(.yardCallout)
                            .foregroundStyle(Color.yardInkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.yardCanvas)
        .navigationTitle("隱私說明")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var limitationDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ButlerBubble(text: ButlerScript.limitationNote)

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionHeader(title: "讀得到")
                    ForEach(["檔名與副檔名", "檔案大小（若系統提供）", "建立日期（若系統提供）", "項目類型", "項目之間的中繼資料相似度"], id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .font(.yardCallout)
                            .foregroundStyle(Color.yardRecycle)
                    }
                }
                .junkCard()

                VStack(alignment: .leading, spacing: Space.m) {
                    SectionHeader(title: "讀不到")
                    ForEach([
                        "檔案的開啟紀錄或使用頻率（iOS 不提供）",
                        "其他 App 的資料與快取（沙盒隔離）",
                        "各個 App 各佔多少儲存空間（無此 API）",
                        "未經你授權的任何資料夾"
                    ], id: \.self) { line in
                        Label(line, systemImage: "xmark.circle.fill")
                            .font(.yardCallout)
                            .foregroundStyle(Color.yardDanger)
                    }
                }
                .junkCard()
            }
            .padding(Space.gutter)
        }
        .background(Color.yardCanvas)
        .navigationTitle("能力範圍")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Import / export

    private var importExportSection: some View {
        Section {
            Button {
                exportText = buildExport()
            } label: {
                Label("匯出整理紀錄（JSON）", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("匯入與匯出")
        } footer: {
            Text("匯出內容只包含中繼資料與判決結果，不含任何檔案本體或影像。")
        }
    }

    private var exportSheet: some View {
        NavigationStack {
            ScrollView {
                Text(exportText ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.gutter)
            }
            .navigationTitle("匯出內容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { exportText = nil }
                }
            }
        }
    }

    // MARK: Danger

    private var dangerSection: some View {
        Section {
            Button("清除判決紀錄", role: .destructive) { showClearDecisions = true }
            Button("清空時間膠囊", role: .destructive) { showEmptyCapsule = true }
                .disabled(store.sealedItems.isEmpty)
            Button("重置整個垃圾場", role: .destructive) { showResetAll = true }
        } header: {
            Text("資料清除")
        } footer: {
            Text("這三個動作都會先向你確認，而且都不會碰到你裝置上的真實檔案。")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本")
                Spacer()
                Text("MVP・P0")
                    .foregroundStyle(Color.yardInkMuted)
            }
            HStack {
                Text("垃圾負載")
                Spacer()
                Text("\(store.junkLoad)")
                    .monospacedDigit()
                    .foregroundStyle(Color.yardInkMuted)
            }
        } header: {
            Text("關於")
        }
    }

    // MARK: Helpers

    private func buildExport() -> String {
        struct ExportRow: Encodable {
            var name: String
            var kind: String
            var bytes: Int64?
            var createdAt: Date?
            var purposeTag: String?
            var verdict: String?
            var score: Int
        }

        let rows = store.items.map { item in
            ExportRow(
                name: item.name,
                kind: item.kind.rawValue,
                bytes: item.byteSize,
                createdAt: item.createdAt,
                purposeTag: item.purposeTag,
                verdict: item.verdict?.rawValue,
                score: store.score(for: item).value
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(rows), let text = String(data: data, encoding: .utf8) else {
            return "匯出失敗。"
        }
        return text
    }

    private static let privacyPoints: [(title: String, symbol: String, body: String)] = [
        ("完全離線", "wifi.slash", "這個 App 沒有任何網路請求。沒有伺服器、沒有帳號、沒有分析追蹤。"),
        ("資料留在裝置上", "iphone", "判決紀錄存在 App 自己的沙盒裡，隨 App 一起被刪除。"),
        ("分析在裝置上進行", "cpu", "垃圾指數是本機規則計算；文案若使用語言模型，也是裝置端模型。"),
        ("刪除永遠經過系統", "trash", "真實檔案的刪除一律由 iOS 的系統對話框確認，照片會進入「最近刪除」，30 天內可以救回。"),
        ("我們不讀內容", "doc.text.magnifyingglass", "MVP 只使用檔名、大小、日期與類型等中繼資料，不讀取檔案內容。")
    ]
}

#Preview {
    SettingsView()
        .environment(YardStore.demo())
}
