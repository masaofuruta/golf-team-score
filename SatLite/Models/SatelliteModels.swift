import Foundation

/// パースされた TLE（Two-Line Element）。
/// 1行目に衛星名、続く2行に軌道要素が入る一般的なフォーマットを表す。
struct TLE: Identifiable, Hashable, Codable {
    var id: String { "\(noradID)-\(name)" }

    let name: String
    let line1: String
    let line2: String

    // --- Line 1 ---
    let noradID: Int            // 衛星カタログ番号
    let epochYear: Int          // 元期（年）
    let epochDay: Double        // 元期（通日）
    let bstar: Double           // B* 抗力項

    // --- Line 2 ---
    let inclination: Double     // 軌道傾斜角 [deg]
    let raan: Double            // 昇交点赤経 [deg]
    let eccentricity: Double    // 離心率
    let argPerigee: Double      // 近地点引数 [deg]
    let meanAnomaly: Double     // 平均近点角 [deg]
    let meanMotion: Double      // 平均運動 [rev/day]

    /// 元期を `Date` として返す。
    var epochDate: Date {
        let fullYear = epochYear < 57 ? 2000 + epochYear : 1900 + epochYear
        var components = DateComponents()
        components.year = fullYear
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        let cal = Calendar(identifier: .gregorian)
        var utc = cal
        utc.timeZone = TimeZone(identifier: "UTC")!
        let startOfYear = utc.date(from: components)!
        // epochDay は 1 始まりの通日（小数で時刻を含む）
        return startOfYear.addingTimeInterval((epochDay - 1.0) * 86400.0)
    }
}

/// 計算された衛星の瞬間位置。
struct SatellitePosition: Identifiable, Hashable {
    let id: String              // TLE.id を継承
    let name: String
    let noradID: Int

    let latitude: Double        // [deg]
    let longitude: Double       // [deg]
    let altitudeKm: Double      // 地表からの高度 [km]
    let speedKmS: Double        // 対地速度 [km/s]

    /// ECI 座標 [km]（地球中心慣性系）。3D 表示用。
    let eciX: Double
    let eciY: Double
    let eciZ: Double

    /// 由来したデータソース名。
    let sourceName: String
}
