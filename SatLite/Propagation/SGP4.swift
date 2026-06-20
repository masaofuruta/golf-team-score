import Foundation

/// SGP4（近地球）軌道伝播モデル。
///
/// 古典的な Spacetrack Report #3（Hoots & Roehrich）の SGP4 を移植したもの。
/// 低・中軌道（周期 < 約225分）の衛星に対応する。深宇宙（SDP4）は対象外。
struct SGP4 {

    // MARK: - 物理定数（WGS-72 系）
    private static let ck2 = 5.413080e-4        // 0.5 * J2 * AE^2
    private static let ck4 = 0.62098875e-6      // -0.375 * J4 * AE^4
    private static let e6a = 1.0e-6
    private static let qoms2t = 1.88027916e-9
    private static let s = 1.01222928
    private static let tothrd = 2.0 / 3.0
    private static let xj3 = -2.53881e-6
    private static let xke = 0.743669161e-1     // sqrt(GM) in (er^1.5/min)
    private static let xkmper = 6378.135        // 地球赤道半径 [km]
    private static let ae = 1.0
    private static let minPerDay = 1440.0
    private static let twoPi = 2.0 * Double.pi
    private static let deg2rad = Double.pi / 180.0

    // MARK: - 元期での前計算結果
    private let tle: TLE
    private let epoch: Date

    private let xnodp, aodp, eo, xincl, cosio, sinio, x3thm1, x1mth2, x7thm1: Double
    private let xmdot, omgdot, xnodot: Double
    private let xnodcf, t2cof, xlcof, aycof, x1m5th: Double
    private let c1, c4, c5, omgcof, xmcof, eta, sinmo, delmo: Double
    private let d2, d3, d4, t3cof, t4cof, t5cof: Double
    private let xmo, omegao, xnodeo, bstar, s4: Double
    private let isimp: Bool

    init(tle: TLE) {
        self.tle = tle
        self.epoch = tle.epochDate

        // 入力をラジアン・rad/min に変換
        let xnodeo = tle.raan * SGP4.deg2rad
        let omegao = tle.argPerigee * SGP4.deg2rad
        let xmo = tle.meanAnomaly * SGP4.deg2rad
        let xincl = tle.inclination * SGP4.deg2rad
        let eo = tle.eccentricity
        let bstar = tle.bstar
        let xno = tle.meanMotion * SGP4.twoPi / SGP4.minPerDay  // rev/day → rad/min

        // --- 初期化 ---
        let a1 = pow(SGP4.xke / xno, SGP4.tothrd)
        let cosio = cos(xincl)
        let theta2 = cosio * cosio
        let x3thm1 = 3.0 * theta2 - 1.0
        let eosq = eo * eo
        let betao2 = 1.0 - eosq
        let betao = sqrt(betao2)
        let del1 = 1.5 * SGP4.ck2 * x3thm1 / (a1 * a1 * betao * betao2)
        let ao = a1 * (1.0 - del1 * (0.5 * SGP4.tothrd + del1 * (1.0 + 134.0 / 81.0 * del1)))
        let delo = 1.5 * SGP4.ck2 * x3thm1 / (ao * ao * betao * betao2)
        let xnodp = xno / (1.0 + delo)
        let aodp = ao / (1.0 - delo)

        let isimp = (aodp * (1.0 - eo) / SGP4.ae) < (220.0 / SGP4.xkmper + SGP4.ae)

        var s4 = SGP4.s
        var qoms24 = SGP4.qoms2t
        let perige = (aodp * (1.0 - eo) - SGP4.ae) * SGP4.xkmper
        if perige < 156.0 {
            s4 = perige - 78.0
            if perige <= 98.0 { s4 = 20.0 }
            qoms24 = pow((120.0 - s4) * SGP4.ae / SGP4.xkmper, 4.0)
            s4 = s4 / SGP4.xkmper + SGP4.ae
        }

        let pinvsq = 1.0 / (aodp * aodp * betao2 * betao2)
        let tsi = 1.0 / (aodp - s4)
        let eta = aodp * eo * tsi
        let etasq = eta * eta
        let eeta = eo * eta
        let psisq = abs(1.0 - etasq)
        let coef = qoms24 * pow(tsi, 4.0)
        let coef1 = coef / pow(psisq, 3.5)
        let c2 = coef1 * xnodp * (aodp * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq))
            + 0.75 * SGP4.ck2 * tsi / psisq * x3thm1 * (8.0 + 3.0 * etasq * (8.0 + etasq)))
        let c1 = bstar * c2
        let sinio = sin(xincl)
        let a3ovk2 = -SGP4.xj3 / SGP4.ck2 * pow(SGP4.ae, 3.0)
        let c3 = coef * tsi * a3ovk2 * xnodp * SGP4.ae * sinio / eo
        let x1mth2 = 1.0 - theta2
        let c4 = 2.0 * xnodp * coef1 * aodp * betao2 * (eta * (2.0 + 0.5 * etasq)
            + eo * (0.5 + 2.0 * etasq)
            - 2.0 * SGP4.ck2 * tsi / (aodp * psisq) * (-3.0 * x3thm1
                * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta))
                + 0.75 * x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * omegao)))
        let c5 = 2.0 * coef1 * aodp * betao2 * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)
        let theta4 = theta2 * theta2
        let temp1 = 3.0 * SGP4.ck2 * pinvsq * xnodp
        let temp2 = temp1 * SGP4.ck2 * pinvsq
        let temp3 = 1.25 * SGP4.ck4 * pinvsq * pinvsq * xnodp
        let xmdot = xnodp + 0.5 * temp1 * betao * x3thm1
            + 0.0625 * temp2 * betao * (13.0 - 78.0 * theta2 + 137.0 * theta4)
        let x1m5th = 1.0 - 5.0 * theta2
        let omgdot = -0.5 * temp1 * x1m5th + 0.0625 * temp2 * (7.0 - 114.0 * theta2 + 395.0 * theta4)
            + temp3 * (3.0 - 36.0 * theta2 + 49.0 * theta4)
        let xhdot1 = -temp1 * cosio
        let xnodot = xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * theta2)
            + 2.0 * temp3 * (3.0 - 7.0 * theta2)) * cosio
        let omgcof = bstar * c3 * cos(omegao)
        let xmcof = -SGP4.tothrd * coef * bstar * SGP4.ae / eeta
        let xnodcf = 3.5 * betao2 * xhdot1 * c1
        let t2cof = 1.5 * c1
        let xlcof = 0.125 * a3ovk2 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)
        let aycof = 0.25 * a3ovk2 * sinio
        let delmo = pow(1.0 + eta * cos(xmo), 3.0)
        let sinmo = sin(xmo)
        let x7thm1 = 7.0 * theta2 - 1.0

        var d2 = 0.0, d3 = 0.0, d4 = 0.0, t3cof = 0.0, t4cof = 0.0, t5cof = 0.0
        if !isimp {
            let c1sq = c1 * c1
            d2 = 4.0 * aodp * tsi * c1sq
            let temp = d2 * tsi * c1 / 3.0
            d3 = (17.0 * aodp + s4) * temp
            d4 = 0.5 * temp * aodp * tsi * (221.0 * aodp + 31.0 * s4) * c1
            t3cof = d2 + 2.0 * c1sq
            t4cof = 0.25 * (3.0 * d3 + c1 * (12.0 * d2 + 10.0 * c1sq))
            t5cof = 0.2 * (3.0 * d4 + 12.0 * c1 * d3 + 6.0 * d2 * d2 + 15.0 * c1sq * (2.0 * d2 + c1sq))
        }

        // 保存
        self.xnodp = xnodp; self.aodp = aodp; self.eo = eo; self.xincl = xincl
        self.cosio = cosio; self.sinio = sinio
        self.x3thm1 = x3thm1; self.x1mth2 = x1mth2; self.x7thm1 = x7thm1
        self.xmdot = xmdot; self.omgdot = omgdot; self.xnodot = xnodot
        self.xnodcf = xnodcf; self.t2cof = t2cof; self.xlcof = xlcof; self.aycof = aycof
        self.x1m5th = x1m5th
        self.c1 = c1; self.c4 = c4; self.c5 = c5
        self.omgcof = omgcof; self.xmcof = xmcof; self.eta = eta
        self.sinmo = sinmo; self.delmo = delmo
        self.d2 = d2; self.d3 = d3; self.d4 = d4
        self.t3cof = t3cof; self.t4cof = t4cof; self.t5cof = t5cof
        self.xmo = xmo; self.omegao = omegao; self.xnodeo = xnodeo
        self.bstar = bstar; self.s4 = s4; self.isimp = isimp
    }

    /// ECI(TEME) 座標 [km] と速度 [km/s] を返す。
    struct StateVector {
        let position: SIMD3<Double>  // km
        let velocity: SIMD3<Double>  // km/s
    }

    /// 指定時刻での状態ベクトルを計算する。
    func propagate(to date: Date) -> StateVector {
        let tsince = date.timeIntervalSince(epoch) / 60.0  // 分

        let xmdf = xmo + xmdot * tsince
        let omgadf = omegao + omgdot * tsince
        let xnoddf = xnodeo + xnodot * tsince
        var omega = omgadf
        var xmp = xmdf
        let tsq = tsince * tsince
        let xnode = xnoddf + xnodcf * tsq
        var tempa = 1.0 - c1 * tsince
        var tempe = bstar * c4 * tsince
        var templ = t2cof * tsq

        if !isimp {
            let delomg = omgcof * tsince
            let delm = xmcof * (pow(1.0 + eta * cos(xmdf), 3.0) - delmo)
            let temp = delomg + delm
            xmp = xmdf + temp
            omega = omgadf - temp
            let tcube = tsq * tsince
            let tfour = tsince * tcube
            tempa = tempa - d2 * tsq - d3 * tcube - d4 * tfour
            tempe = tempe + bstar * c5 * (sin(xmp) - sinmo)
            templ = templ + t3cof * tcube + tfour * (t4cof + tsince * t5cof)
        }

        let a = aodp * tempa * tempa
        let e = eo - tempe
        let xl = xmp + omega + xnode + xnodp * templ
        let beta = sqrt(1.0 - e * e)
        let xn = SGP4.xke / pow(a, 1.5)

        // 長周期項
        let axn = e * cos(omega)
        let temp = 1.0 / (a * beta * beta)
        let xll = temp * xlcof * axn
        let aynl = temp * aycof
        let xlt = xl + xll
        let ayn = e * sin(omega) + aynl

        // ケプラー方程式
        let capu = fmod(xlt - xnode, SGP4.twoPi)
        var epw = capu
        var sinepw = 0.0, cosepw = 0.0, temp5 = 0.0, temp6 = 0.0
        for _ in 0..<10 {
            sinepw = sin(epw)
            cosepw = cos(epw)
            let temp3 = axn * sinepw
            let temp4 = ayn * cosepw
            temp5 = axn * cosepw
            temp6 = ayn * sinepw
            let epwNew = (capu - temp4 + temp3 - epw) / (1.0 - temp5 - temp6) + epw
            if abs(epwNew - epw) <= SGP4.e6a { epw = epwNew; break }
            epw = epwNew
        }
        sinepw = sin(epw); cosepw = cos(epw)
        let temp3 = axn * sinepw
        let temp4 = ayn * cosepw
        temp5 = axn * cosepw
        temp6 = ayn * sinepw

        // 短周期項
        let ecose = temp5 + temp6
        let esine = temp3 - temp4
        let elsq = axn * axn + ayn * ayn
        let tempPL = 1.0 - elsq
        let pl = a * tempPL
        let r = a * (1.0 - ecose)
        let temp1r = 1.0 / r
        let rdot = SGP4.xke * sqrt(a) * esine * temp1r
        let rfdot = SGP4.xke * sqrt(pl) * temp1r
        let temp2r = a * temp1r
        let betal = sqrt(tempPL)
        let temp3r = 1.0 / (1.0 + betal)
        let cosu = temp2r * (cosepw - axn + ayn * esine * temp3r)
        let sinu = temp2r * (sinepw - ayn - axn * esine * temp3r)
        let u = atan2(sinu, cosu)
        let sin2u = 2.0 * sinu * cosu
        let cos2u = 2.0 * cosu * cosu - 1.0
        let tempS = 1.0 / pl
        let temp1 = SGP4.ck2 * tempS
        let temp2 = temp1 * tempS

        let rk = r * (1.0 - 1.5 * temp2 * betal * x3thm1) + 0.5 * temp1 * x1mth2 * cos2u
        let uk = u - 0.25 * temp2 * x7thm1 * sin2u
        let xnodek = xnode + 1.5 * temp2 * cosio * sin2u
        let xinck = xincl + 1.5 * temp2 * cosio * sinio * cos2u
        let rdotk = rdot - xn * temp1 * x1mth2 * sin2u
        let rfdotk = rfdot + xn * temp1 * (x1mth2 * cos2u + 1.5 * x3thm1)

        // 方向ベクトル
        let sinuk = sin(uk), cosuk = cos(uk)
        let sinik = sin(xinck), cosik = cos(xinck)
        let sinnok = sin(xnodek), cosnok = cos(xnodek)
        let xmx = -sinnok * cosik
        let xmy = cosnok * cosik
        let ux = xmx * sinuk + cosnok * cosuk
        let uy = xmy * sinuk + sinnok * cosuk
        let uz = sinik * sinuk
        let vx = xmx * cosuk - cosnok * sinuk
        let vy = xmy * cosuk - sinnok * sinuk
        let vz = sinik * cosuk

        // 位置 [er] と速度 [er/min] → km, km/s
        let x = rk * ux, y = rk * uy, z = rk * uz
        let xdot = rdotk * ux + rfdotk * vx
        let ydot = rdotk * uy + rfdotk * vy
        let zdot = rdotk * uz + rfdotk * vz

        let posKm = SIMD3<Double>(x, y, z) * SGP4.xkmper
        let velKmS = SIMD3<Double>(xdot, ydot, zdot) * SGP4.xkmper / 60.0
        return StateVector(position: posKm, velocity: velKmS)
    }
}
