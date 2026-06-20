import SwiftUI

/// 衛星の一覧。高度・速度・緯度経度を表示し、選択で 3D 上の衛星と連動する。
struct SatelliteListView: View {
    let positions: [SatellitePosition]
    let colorProvider: (String) -> String
    @Binding var selectedID: String?
    var onDone: () -> Void

    @State private var query = ""

    private var filtered: [SatellitePosition] {
        let base = query.isEmpty
            ? positions
            : positions.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return base.sorted { $0.altitudeKm < $1.altitudeKm }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { sat in
                Button {
                    selectedID = sat.id
                    onDone()
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: colorProvider(sat.sourceName)))
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sat.name).font(.subheadline).foregroundStyle(.primary)
                            Text(sat.sourceName).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(sat.altitudeKm)) km")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.primary)
                            Text(String(format: "%.1f km/s", sat.speedKmS))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "衛星名で検索")
            .navigationTitle("衛星一覧 (\(positions.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: onDone)
                }
            }
        }
    }
}
