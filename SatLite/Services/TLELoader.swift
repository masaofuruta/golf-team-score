import Foundation

/// 情報ソースの URL から TLE をダウンロードしてパースする。
enum TLELoader {

    enum LoadError: LocalizedError {
        case invalidURL
        case httpError(Int)
        case empty

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL が不正です。"
            case .httpError(let code): return "サーバーエラー (HTTP \(code))。"
            case .empty: return "TLE データが空でした。"
            }
        }
    }

    /// 1 つのソースから TLE 配列を取得する。
    static func load(from source: DataSource) async throws -> [TLE] {
        guard let url = URL(string: source.url) else { throw LoadError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("SatLite/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LoadError.httpError(http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else {
            throw LoadError.empty
        }
        let tles = TLEParser.parse(text)
        if tles.isEmpty { throw LoadError.empty }
        return tles
    }
}
