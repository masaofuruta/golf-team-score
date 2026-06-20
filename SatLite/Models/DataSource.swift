import Foundation

/// 衛星 TLE を取得するための情報ソース。
/// ユーザーが自由に追加・削除・有効/無効を切り替えられる。
struct DataSource: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var name: String            // 表示名（例: "ISS / 宇宙ステーション"）
    var url: String             // TLE を返す URL
    var isEnabled: Bool = true
    var colorHex: String        // 3D 表示でのマーカー色

    /// 同梱のデフォルトソース（CelesTrak の公開 TLE）。
    static let defaults: [DataSource] = [
        DataSource(name: "宇宙ステーション (ISS など)",
                   url: "https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=tle",
                   colorHex: "#FF3B30"),
        DataSource(name: "Starlink",
                   url: "https://celestrak.org/NORAD/elements/gp.php?GROUP=starlink&FORMAT=tle",
                   colorHex: "#34C759"),
        DataSource(name: "GPS 衛星",
                   url: "https://celestrak.org/NORAD/elements/gp.php?GROUP=gps-ops&FORMAT=tle",
                   isEnabled: false,
                   colorHex: "#0A84FF"),
        DataSource(name: "気象衛星",
                   url: "https://celestrak.org/NORAD/elements/gp.php?GROUP=weather&FORMAT=tle",
                   isEnabled: false,
                   colorHex: "#FFD60A"),
        DataSource(name: "科学衛星",
                   url: "https://celestrak.org/NORAD/elements/gp.php?GROUP=science&FORMAT=tle",
                   isEnabled: false,
                   colorHex: "#BF5AF2")
    ]
}
