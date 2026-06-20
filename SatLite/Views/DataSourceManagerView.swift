import SwiftUI

/// 情報ソース（TLE 取得先）の追加・削除・有効化を管理する画面。
struct DataSourceManagerView: View {
    @ObservedObject var store: DataSourceStore
    var onDone: () -> Void

    @State private var editing: DataSource?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sources) { source in
                        row(for: source)
                    }
                    .onDelete { store.remove(at: $0) }
                } header: {
                    Text("情報ソース")
                } footer: {
                    Text("TLE（軌道要素）を返す URL を登録します。スイッチで表示の ON/OFF、スワイプで削除できます。CelesTrak などの公開ソースが利用できます。")
                }

                Section {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("ソースを追加", systemImage: "plus.circle.fill")
                    }
                    Button(role: .destructive) {
                        store.resetToDefaults()
                    } label: {
                        Label("初期ソースに戻す", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("データソース")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDone)
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAdd) {
                DataSourceEditView(source: DataSource(name: "", url: "", colorHex: "#FF9F0A")) { newSource in
                    store.add(newSource)
                }
            }
            .sheet(item: $editing) { source in
                DataSourceEditView(source: source) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private func row(for source: DataSource) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: source.colorHex))
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name.isEmpty ? "(名称未設定)" : source.name)
                    .font(.body)
                Text(source.url)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { _ in store.toggle(source) }
            ))
            .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = source }
    }
}

/// ソースの追加・編集フォーム。
struct DataSourceEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var source: DataSource
    var onSave: (DataSource) -> Void

    private let palette = ["#FF3B30", "#FF9F0A", "#FFD60A", "#34C759",
                           "#0A84FF", "#5E5CE6", "#BF5AF2", "#FF2D55", "#FFFFFF"]

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("例: 気象衛星", text: $source.name)
                }
                Section("TLE データ URL") {
                    TextField("https://...", text: $source.url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("マーカー色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle().stroke(Color.primary,
                                                    lineWidth: source.colorHex == hex ? 3 : 0)
                                )
                                .onTapGesture { source.colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Toggle("表示を有効にする", isOn: $source.isEnabled)
                }
            }
            .navigationTitle(source.name.isEmpty ? "ソースを追加" : "ソースを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(source)
                        dismiss()
                    }
                    .disabled(source.name.trimmingCharacters(in: .whitespaces).isEmpty
                              || source.url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
