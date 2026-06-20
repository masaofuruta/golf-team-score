# SatLite 🛰️

地球の周りを回る人工衛星の飛行位置を、3次元の地球儀上にリアルタイム表示する iPhone（iOS）アプリです。

## 主な機能

- **3次元の地球儀** — SceneKit で描画。**ドラッグで自由に回転**、ピンチでズームできます。
- **衛星のリアルタイム追跡** — TLE（軌道要素）から **SGP4 軌道伝播モデル**で現在位置を毎秒計算し、地球儀上に色分けして表示します。
- **飛行高度の表示** — 各衛星の**高度 (km)**・対地速度 (km/s)・緯度・経度を一覧および詳細カードで確認できます。衛星をタップすると詳細が表示されます。
- **情報ソースの追加・削除が簡単** — TLE を返す URL を「データソース」として登録/編集/削除/ON・OFF できます。設定は端末に永続化されます。

## 画面構成

| 画面 | 内容 |
|------|------|
| メイン | 3D 地球儀＋追跡中の衛星。下部のボタンで「衛星一覧」「データソース」へ。衛星タップで高度などの詳細カードを表示。 |
| 衛星一覧 | 高度順に並ぶ衛星リスト。検索可能。タップで 3D 上の該当衛星を選択。 |
| データソース | TLE 取得元の管理。追加・編集・削除・有効/無効の切り替え、初期化。 |

## データソースについて

初期状態では [CelesTrak](https://celestrak.org/) の公開 TLE を利用します。

| ソース | 内容 | 初期状態 |
|--------|------|---------|
| 宇宙ステーション | ISS など | 有効 |
| Starlink | Starlink 衛星群 | 有効 |
| GPS 衛星 | 測位衛星 | 無効 |
| 気象衛星 | 気象観測衛星 | 無効 |
| 科学衛星 | 科学観測衛星 | 無効 |

**任意の TLE 提供 URL を追加できます。** 例（CelesTrak のグループ）:

```
https://celestrak.org/NORAD/elements/gp.php?GROUP=<グループ名>&FORMAT=tle
```

`active`, `weather`, `noaa`, `galileo`, `glo-ops`, `geo`, `cubesat` などのグループが利用可能です。
N2YO や Space-Track など、TLE 形式（3 行: 名前 + 2 行要素、または 2 行のみ）を返す URL であれば登録できます。

## ビルド方法

1. **Xcode 15 以降**で `SatLite.xcodeproj` を開きます。
2. 署名チームを自分のものに設定（`SatLite` ターゲット → Signing & Capabilities）。
3. 実機または iOS 16 以降のシミュレータを選んで ▶︎ で実行します。

> 衛星データの取得にネットワーク接続が必要です。

## アーキテクチャ

```
SatLite/
├─ SatLiteApp.swift            アプリのエントリポイント
├─ ContentView.swift           メイン画面（地球儀＋UI）
├─ Models/
│   ├─ SatelliteModels.swift   TLE / 衛星位置のデータ構造
│   └─ DataSource.swift        情報ソース定義（初期ソース含む）
├─ Propagation/
│   ├─ TLEParser.swift         TLE テキストのパース
│   ├─ SGP4.swift              SGP4 軌道伝播モデル（近地球）
│   └─ Coordinates.swift       ECI → 緯度経度・高度 変換（GMST/扁平地球）
├─ Services/
│   ├─ DataSourceStore.swift   ソースの永続化（UserDefaults）
│   ├─ TLELoader.swift         TLE のダウンロード
│   └─ SatelliteEngine.swift   取得・伝播・毎秒更新の中核
├─ Views/
│   ├─ EarthSceneView.swift    SceneKit 地球儀（ドラッグ回転・衛星配置）
│   ├─ EarthTexture.swift      地球テクスチャ生成
│   ├─ StarfieldTexture.swift  背景の星空
│   ├─ ColorUtils.swift        色ユーティリティ
│   ├─ DataSourceManagerView.swift  ソース管理画面
│   └─ SatelliteListView.swift      衛星一覧画面
└─ Resources/
    ├─ Assets.xcassets
    └─ Info.plist
```

### 軌道計算について

- 位置計算は **SGP4（近地球モデル / Spacetrack Report #3）** を Swift に移植したものです。低・中軌道（周期 < 約 225 分）の衛星に対応します。深宇宙（SDP4 が必要な高軌道）の衛星は計算対象外として自動的に除外されます。
- ECI(TEME) 座標を GMST（グリニッジ平均恒星時）と扁平地球モデルで測地座標（緯度・経度・高度）へ変換しています。

### 地球テクスチャ

標準では海洋・緯度経度グリッド・極冠・大陸シルエットを手続き的に描画します。
より写実的にしたい場合は、等距円筒図法の地球画像を `earth_day` という名前で
`Assets.xcassets` に追加すると自動的に使用されます（衛星の地理的位置合わせには
`EarthSceneView.textureLongitudeOffset` の微調整が必要な場合があります）。

## ライセンス / データ出典

- 衛星軌道データ: CelesTrak（初期設定）。利用は各データ提供元の規約に従ってください。
