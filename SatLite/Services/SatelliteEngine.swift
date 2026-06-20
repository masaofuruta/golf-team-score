import Foundation
import Combine

/// 衛星データの取得・軌道伝播・周期更新を司る中核エンジン。
@MainActor
final class SatelliteEngine: ObservableObject {

    @Published private(set) var positions: [SatellitePosition] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    @Published private(set) var lastUpdated: Date?
    @Published var simulationDate: Date = Date()

    /// 1 ソースあたりの最大衛星数（Starlink 等の大量データを間引く）。
    var maxSatellitesPerSource = 120

    private let store: DataSourceStore

    /// ソースごとの伝播器と表示メタ情報。
    private struct LoadedSatellite {
        let propagator: SGP4
        let tle: TLE
        let sourceName: String
        let colorHex: String
    }
    private var loaded: [LoadedSatellite] = []

    private var timer: Timer?

    init(store: DataSourceStore) {
        self.store = store
    }

    // MARK: - データ取得

    /// 有効な全ソースから TLE を取得し直す。
    func refresh() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        var newLoaded: [LoadedSatellite] = []
        var errors: [String] = []

        for source in store.enabledSources {
            do {
                let tles = try await TLELoader.load(from: source)
                for tle in tles.prefix(maxSatellitesPerSource) {
                    newLoaded.append(LoadedSatellite(propagator: SGP4(tle: tle),
                                                     tle: tle,
                                                     sourceName: source.name,
                                                     colorHex: source.colorHex))
                }
            } catch {
                errors.append("\(source.name): \(error.localizedDescription)")
            }
        }

        loaded = newLoaded
        if !errors.isEmpty {
            lastError = errors.joined(separator: "\n")
        }
        recomputePositions()
    }

    // MARK: - 周期更新

    /// リアルタイム更新を開始する（1 秒ごとに位置を再計算）。
    func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.simulationDate = Date()
                self.recomputePositions()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    /// 現在の `simulationDate` で全衛星位置を再計算する。
    func recomputePositions() {
        let date = simulationDate
        var result: [SatellitePosition] = []
        result.reserveCapacity(loaded.count)

        for sat in loaded {
            let state = sat.propagator.propagate(to: date)
            // 数値が破綻した衛星（深宇宙など非対応）はスキップ
            guard state.position.x.isFinite,
                  state.position.y.isFinite,
                  state.position.z.isFinite else { continue }

            let geo = Coordinates.eciToGeodetic(state.position, date: date)
            guard geo.altitudeKm.isFinite, geo.altitudeKm > -100, geo.altitudeKm < 200_000 else { continue }

            let speed = length(state.velocity)
            result.append(SatellitePosition(id: sat.tle.id,
                                            name: sat.tle.name,
                                            noradID: sat.tle.noradID,
                                            latitude: geo.latitude,
                                            longitude: geo.longitude,
                                            altitudeKm: geo.altitudeKm,
                                            speedKmS: speed,
                                            eciX: state.position.x,
                                            eciY: state.position.y,
                                            eciZ: state.position.z,
                                            sourceName: sat.sourceName))
        }
        positions = result
        lastUpdated = Date()
    }

    /// ソース名 → 色（16進）の対応表。
    func colorHex(for sourceName: String) -> String {
        store.sources.first { $0.name == sourceName }?.colorHex ?? "#FFFFFF"
    }

    private func length(_ v: SIMD3<Double>) -> Double {
        sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    }
}
