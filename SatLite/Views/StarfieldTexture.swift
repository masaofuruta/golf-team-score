import UIKit

/// 背景用の簡易星空テクスチャを生成する。
enum StarfieldTexture {
    static func make(size: CGFloat = 1024, starCount: Int = 600) -> UIImage {
        let canvas = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvas))
            var generator = SystemRandomNumberGenerator()
            for _ in 0..<starCount {
                let x = CGFloat.random(in: 0..<size, using: &generator)
                let y = CGFloat.random(in: 0..<size, using: &generator)
                let r = CGFloat.random(in: 0.3...1.4, using: &generator)
                let brightness = CGFloat.random(in: 0.4...1.0, using: &generator)
                UIColor(white: brightness, alpha: 1).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
    }
}
