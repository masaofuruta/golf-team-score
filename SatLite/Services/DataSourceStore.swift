import Foundation
import Combine

/// 情報ソースの一覧を管理し、`UserDefaults` に永続化する。
final class DataSourceStore: ObservableObject {
    @Published var sources: [DataSource] {
        didSet { save() }
    }

    private let storageKey = "satlite.datasources.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DataSource].self, from: data),
           !decoded.isEmpty {
            self.sources = decoded
        } else {
            self.sources = DataSource.defaults
        }
    }

    var enabledSources: [DataSource] {
        sources.filter { $0.isEnabled }
    }

    func add(_ source: DataSource) {
        sources.append(source)
    }

    func remove(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
    }

    func update(_ source: DataSource) {
        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx] = source
        }
    }

    func toggle(_ source: DataSource) {
        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx].isEnabled.toggle()
        }
    }

    /// 初期ソース構成へ戻す。
    func resetToDefaults() {
        sources = DataSource.defaults
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
