import SwiftUI

struct ContentView: View {
    @StateObject private var store: DataSourceStore
    @StateObject private var engine: SatelliteEngine
    @State private var selectedID: String?
    @State private var showingSources = false
    @State private var showingList = false

    init() {
        let store = DataSourceStore()
        _store = StateObject(wrappedValue: store)
        _engine = StateObject(wrappedValue: SatelliteEngine(store: store))
    }

    private var selectedSatellite: SatellitePosition? {
        guard let id = selectedID else { return nil }
        return engine.positions.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EarthSceneView(positions: engine.positions,
                           colorProvider: { engine.colorHex(for: $0) },
                           selectedID: $selectedID)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let sat = selectedSatellite {
                    detailCard(for: sat)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomBar
            }
            .padding()

            if engine.isLoading {
                ProgressView("衛星データを取得中…")
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await engine.refresh()
            engine.startTicking()
        }
        .onDisappear { engine.stopTicking() }
        .sheet(isPresented: $showingSources) {
            DataSourceManagerView(store: store) {
                showingSources = false
                Task { await engine.refresh() }
            }
        }
        .sheet(isPresented: $showingList) {
            SatelliteListView(positions: engine.positions,
                              colorProvider: { engine.colorHex(for: $0) },
                              selectedID: $selectedID) {
                showingList = false
            }
        }
        .alert("読み込みエラー",
               isPresented: Binding(get: { engine.lastError != nil },
                                    set: { if !$0 { engine.lastError = nil } })) {
            Button("OK", role: .cancel) { engine.lastError = nil }
        } message: {
            Text(engine.lastError ?? "")
        }
    }

    // MARK: - 上部バー

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SatLite")
                    .font(.title2.bold())
                Text("\(engine.positions.count) 機を追跡中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await engine.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - 下部バー

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                showingList = true
            } label: {
                Label("衛星一覧", systemImage: "list.bullet")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            Button {
                showingSources = true
            } label: {
                Label("データソース", systemImage: "antenna.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .font(.subheadline.bold())
        .foregroundStyle(.primary)
    }

    // MARK: - 選択衛星の詳細（高度ほか）

    private func detailCard(for sat: SatellitePosition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: engine.colorHex(for: sat.sourceName)))
                    .frame(width: 12, height: 12)
                Text(sat.name).font(.headline)
                Spacer()
                Button {
                    selectedID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                metric("高度", String(format: "%.0f km", sat.altitudeKm), "arrow.up.to.line")
                metric("速度", String(format: "%.2f km/s", sat.speedKmS), "speedometer")
            }
            HStack(spacing: 16) {
                metric("緯度", String(format: "%.2f°", sat.latitude), "globe.americas")
                metric("経度", String(format: "%.2f°", sat.longitude), "globe")
            }
            Text("ソース: \(sat.sourceName) ・ NORAD #\(sat.noradID)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .animation(.easeInOut, value: sat.id)
    }

    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold().monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
