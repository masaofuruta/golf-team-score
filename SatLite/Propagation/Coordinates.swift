import Foundation

/// 座標変換ユーティリティ（ECI ⇄ 測地座標）。
enum Coordinates {

    private static let earthRadiusKm = 6378.137      // WGS-84 赤道半径
    private static let flattening = 1.0 / 298.257223563
    private static let twoPi = 2.0 * Double.pi

    /// 指定日時のグリニッジ平均恒星時 [rad]。
    static func gmst(for date: Date) -> Double {
        // ユリウス日
        let jd = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let t = (jd - 2451545.0) / 36525.0
        var gmstSec = 67310.54841
            + (876600.0 * 3600.0 + 8640184.812866) * t
            + 0.093104 * t * t
            - 6.2e-6 * t * t * t
        gmstSec = gmstSec.truncatingRemainder(dividingBy: 86400.0)
        if gmstSec < 0 { gmstSec += 86400.0 }
        // 1 秒 = 1/240 度
        var gmst = gmstSec / 240.0 * Double.pi / 180.0
        gmst = gmst.truncatingRemainder(dividingBy: twoPi)
        if gmst < 0 { gmst += twoPi }
        return gmst
    }

    /// 測地座標（緯度・経度 [deg]、高度 [km]）。
    struct Geodetic {
        let latitude: Double
        let longitude: Double
        let altitudeKm: Double
    }

    /// ECI(TEME) 座標 [km] を測地座標へ変換する（扁平地球モデル）。
    static func eciToGeodetic(_ eci: SIMD3<Double>, date: Date) -> Geodetic {
        let theta = gmst(for: date)
        // ECI → ECEF（地球固定系）へ回転
        let x = eci.x * cos(theta) + eci.y * sin(theta)
        let y = -eci.x * sin(theta) + eci.y * cos(theta)
        let z = eci.z

        let lon = atan2(y, x)
        let r = sqrt(x * x + y * y)
        let e2 = flattening * (2.0 - flattening)

        // 緯度の反復計算（Bowring 法）
        var lat = atan2(z, r)
        var c = 0.0
        for _ in 0..<5 {
            let sinLat = sin(lat)
            c = 1.0 / sqrt(1.0 - e2 * sinLat * sinLat)
            lat = atan2(z + earthRadiusKm * c * e2 * sinLat, r)
        }
        let alt = r / cos(lat) - earthRadiusKm * c

        var lonDeg = lon * 180.0 / Double.pi
        // -180..180 に正規化
        if lonDeg > 180 { lonDeg -= 360 }
        if lonDeg < -180 { lonDeg += 360 }

        return Geodetic(latitude: lat * 180.0 / Double.pi,
                        longitude: lonDeg,
                        altitudeKm: alt)
    }
}
