import Foundation

/// 3行（名前 + 2行要素）形式の TLE テキストをパースするユーティリティ。
enum TLEParser {

    /// 複数衛星を含む TLE テキストをパースして配列で返す。
    static func parse(_ text: String) -> [TLE] {
        var result: [TLE] = []
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            // 名前行 → "1 " 始まりと "2 " 始まりの2行を探す
            if line.hasPrefix("1 ") {
                // 名前行が無いケース（2行だけ）
                if index + 1 < lines.count, lines[index + 1].hasPrefix("2 ") {
                    if let tle = parsePair(name: "NORAD \(noradFromLine1(lines[index]))",
                                           line1: lines[index],
                                           line2: lines[index + 1]) {
                        result.append(tle)
                    }
                    index += 2
                    continue
                }
            } else if !line.isEmpty,
                      index + 2 < lines.count,
                      lines[index + 1].hasPrefix("1 "),
                      lines[index + 2].hasPrefix("2 ") {
                if let tle = parsePair(name: line,
                                       line1: lines[index + 1],
                                       line2: lines[index + 2]) {
                    result.append(tle)
                }
                index += 3
                continue
            }
            index += 1
        }
        return result
    }

    private static func noradFromLine1(_ line1: String) -> String {
        guard line1.count >= 7 else { return "?" }
        return substr(line1, 2, 7).trimmingCharacters(in: .whitespaces)
    }

    private static func parsePair(name: String, line1: String, line2: String) -> TLE? {
        guard line1.count >= 63, line2.count >= 63 else { return nil }

        // --- Line 1 ---
        guard let noradID = Int(substr(line1, 2, 7).trimmingCharacters(in: .whitespaces)) else { return nil }
        let epochYear = Int(substr(line1, 18, 20).trimmingCharacters(in: .whitespaces)) ?? 0
        let epochDay = Double(substr(line1, 20, 32).trimmingCharacters(in: .whitespaces)) ?? 0
        let bstar = parseExp(substr(line1, 53, 61))

        // --- Line 2 ---
        let inclination = Double(substr(line2, 8, 16).trimmingCharacters(in: .whitespaces)) ?? 0
        let raan = Double(substr(line2, 17, 25).trimmingCharacters(in: .whitespaces)) ?? 0
        let eccString = "0." + substr(line2, 26, 33).trimmingCharacters(in: .whitespaces)
        let eccentricity = Double(eccString) ?? 0
        let argPerigee = Double(substr(line2, 34, 42).trimmingCharacters(in: .whitespaces)) ?? 0
        let meanAnomaly = Double(substr(line2, 43, 51).trimmingCharacters(in: .whitespaces)) ?? 0
        let meanMotion = Double(substr(line2, 52, 63).trimmingCharacters(in: .whitespaces)) ?? 0

        guard meanMotion > 0 else { return nil }

        return TLE(name: name,
                   line1: line1,
                   line2: line2,
                   noradID: noradID,
                   epochYear: epochYear,
                   epochDay: epochDay,
                   bstar: bstar,
                   inclination: inclination,
                   raan: raan,
                   eccentricity: eccentricity,
                   argPerigee: argPerigee,
                   meanAnomaly: meanAnomaly,
                   meanMotion: meanMotion)
    }

    /// TLE の指数表記（例 " 12345-3" → 0.12345e-3）をパース。
    private static func parseExp(_ field: String) -> Double {
        let f = field.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return 0 }
        var sign = 1.0
        var body = f
        if body.hasPrefix("-") { sign = -1; body.removeFirst() }
        else if body.hasPrefix("+") { body.removeFirst() }
        // 末尾の指数（最後の +/-）で分割
        guard let expIdx = body.lastIndex(where: { $0 == "+" || $0 == "-" }) else {
            return sign * (Double("0." + body) ?? 0)
        }
        let mantissa = String(body[body.startIndex..<expIdx])
        let exp = Int(String(body[expIdx...])) ?? 0
        let value = Double("0." + mantissa) ?? 0
        return sign * value * pow(10.0, Double(exp))
    }

    /// 0 始まりの開始位置と終了位置で部分文字列を取り出す（範囲外は安全にクリップ）。
    private static func substr(_ s: String, _ start: Int, _ end: Int) -> String {
        let chars = Array(s)
        let lo = max(0, min(start, chars.count))
        let hi = max(lo, min(end, chars.count))
        return String(chars[lo..<hi])
    }
}
