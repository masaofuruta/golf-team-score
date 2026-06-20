import UIKit

/// 地球の等距円筒（equirectangular）テクスチャを生成する。
///
/// バンドルに `earth_day`（実写テクスチャ）があればそれを使用し、
/// 無ければ海洋色＋緯度経度グリッド＋極冠＋大陸シルエットを手続き的に描画する。
enum EarthTexture {

    static func make(width: Int = 2048, height: Int = 1024) -> UIImage {
        if let bundled = UIImage(named: "earth_day") {
            return bundled
        }
        return generate(width: width, height: height)
    }

    private static func generate(width: Int, height: Int) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // 海洋（上下グラデーション）
            let ocean = [UIColor(hex: "#0a3d62").cgColor,
                         UIColor(hex: "#1e6091").cgColor,
                         UIColor(hex: "#0a3d62").cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: ocean as CFArray,
                                      locations: [0, 0.5, 1])!
            cg.drawLinearGradient(gradient,
                                  start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: 0, y: size.height),
                                  options: [])

            // 大陸シルエット（おおまかな矩形/楕円で示すヒント）
            let land = UIColor(hex: "#3b7a57")
            land.setFill()
            for blob in continents {
                let rect = CGRect(x: blob.lonMin.lonToX(width),
                                  y: blob.latMax.latToY(height),
                                  width: (blob.lonMax - blob.lonMin) / 360.0 * Double(width),
                                  height: (blob.latMax - blob.latMin) / 180.0 * Double(height))
                let path = UIBezierPath(ovalIn: rect)
                path.fill()
            }

            // 極冠
            UIColor.white.withAlphaComponent(0.9).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: width, height: height / 22))
            cg.fill(CGRect(x: 0, y: height - height / 22, width: width, height: height / 22))

            // 緯度経度グリッド（30度ごと）
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.18).cgColor)
            cg.setLineWidth(1)
            for lon in stride(from: -180.0, through: 180.0, by: 30.0) {
                let x = lon.lonToX(width)
                cg.move(to: CGPoint(x: x, y: 0))
                cg.addLine(to: CGPoint(x: x, y: Double(height)))
            }
            for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
                let y = lat.latToY(height)
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: Double(width), y: y))
            }
            cg.strokePath()

            // 赤道・本初子午線を強調
            cg.setStrokeColor(UIColor(hex: "#FFD60A").withAlphaComponent(0.45).cgColor)
            cg.setLineWidth(2)
            let eqY = 0.0.latToY(height)
            cg.move(to: CGPoint(x: 0, y: eqY)); cg.addLine(to: CGPoint(x: Double(width), y: eqY))
            let pmX = 0.0.lonToX(width)
            cg.move(to: CGPoint(x: pmX, y: 0)); cg.addLine(to: CGPoint(x: pmX, y: Double(height)))
            cg.strokePath()
        }
    }

    private struct Blob { let latMin, latMax, lonMin, lonMax: Double }
    private static let continents: [Blob] = [
        Blob(latMin: 5,  latMax: 70,  lonMin: -10, lonMax: 60),   // ユーラシア西
        Blob(latMin: 10, latMax: 65,  lonMin: 55,  lonMax: 140),  // ユーラシア東
        Blob(latMin: -35, latMax: 35, lonMin: -18, lonMax: 52),   // アフリカ
        Blob(latMin: 10, latMax: 70,  lonMin: -160, lonMax: -55), // 北米
        Blob(latMin: -55, latMax: 12, lonMin: -82, lonMax: -34),  // 南米
        Blob(latMin: -40, latMax: -10, lonMin: 112, lonMax: 154)  // オーストラリア
    ]
}

private extension Double {
    func lonToX(_ width: Int) -> Double { (self + 180.0) / 360.0 * Double(width) }
    func latToY(_ height: Int) -> Double { (90.0 - self) / 180.0 * Double(height) }
}
