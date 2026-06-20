import SwiftUI
import SceneKit
import UIKit

/// SceneKit による 3D 地球儀。ドラッグで回転・ピンチでズームできる。
/// 衛星は緯度・経度・高度から配置され、毎フレーム更新される。
struct EarthSceneView: UIViewRepresentable {

    var positions: [SatellitePosition]
    var colorProvider: (String) -> String
    @Binding var selectedID: String?

    /// 表示スケール: 地球半径を 1.0 とする。
    private let earthDisplayRadius: Float = 1.0
    private let earthRadiusKm: Float = 6371.0
    /// テクスチャの経度合わせ用オフセット（環境により微調整可能）。
    private let textureLongitudeOffset: Float = .pi

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = makeScene(context: context)
        scnView.allowsCameraControl = true          // ドラッグ回転・ピンチズーム
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling2X
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        context.coordinator.scnView = scnView
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.sync(positions: positions,
                                 colorProvider: colorProvider,
                                 selectedID: selectedID)
    }

    // MARK: - シーン構築

    private func makeScene(context: Context) -> SCNScene {
        let scene = SCNScene()

        // 全体を束ねるワールドノード
        let worldNode = SCNNode()
        worldNode.name = "world"
        scene.rootNode.addChildNode(worldNode)
        context.coordinator.worldNode = worldNode

        // 地球
        let sphere = SCNSphere(radius: CGFloat(earthDisplayRadius))
        sphere.segmentCount = 96
        let material = sphere.firstMaterial!
        material.diffuse.contents = EarthTexture.make()
        material.diffuse.wrapS = .repeat
        material.specular.contents = UIColor(white: 0.2, alpha: 1)
        material.shininess = 0.05
        material.locksAmbientWithDiffuse = true
        let earthNode = SCNNode(geometry: sphere)
        earthNode.name = "earth"
        earthNode.eulerAngles.y = textureLongitudeOffset
        worldNode.addChildNode(earthNode)

        // 大気のうっすらした輪郭
        let atmosphere = SCNSphere(radius: CGFloat(earthDisplayRadius * 1.02))
        atmosphere.segmentCount = 64
        let atmMat = atmosphere.firstMaterial!
        atmMat.diffuse.contents = UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.12)
        atmMat.transparencyMode = .singleLayer
        atmMat.isDoubleSided = true
        atmMat.lightingModel = .constant
        worldNode.addChildNode(SCNNode(geometry: atmosphere))

        // 衛星を入れるコンテナ
        let satContainer = SCNNode()
        satContainer.name = "satellites"
        worldNode.addChildNode(satContainer)
        context.coordinator.satContainer = satContainer

        // 照明
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 1100
        sun.position = SCNVector3(5, 3, 5)
        sun.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 250
        scene.rootNode.addChildNode(ambient)

        // カメラ
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera!.fieldOfView = 45
        camera.position = SCNVector3(0, 0, 4.5)
        scene.rootNode.addChildNode(camera)

        // 星空
        scene.background.contents = StarfieldTexture.make()

        return scene
    }

    /// 緯度経度・高度を表示座標へ変換する。
    func displayPosition(lat: Double, lon: Double, altKm: Double) -> SCNVector3 {
        let latR = Float(lat) * .pi / 180
        let lonR = Float(lon) * .pi / 180
        let r = earthDisplayRadius * (1.0 + Float(altKm) / earthRadiusKm)
        let x = r * cos(latR) * sin(lonR)
        let y = r * sin(latR)
        let z = r * cos(latR) * cos(lonR)
        return SCNVector3(x, y, z)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        let parent: EarthSceneView
        weak var scnView: SCNView?
        weak var worldNode: SCNNode?
        weak var satContainer: SCNNode?
        private var nodes: [String: SCNNode] = [:]

        init(_ parent: EarthSceneView) { self.parent = parent }

        func sync(positions: [SatellitePosition],
                  colorProvider: (String) -> String,
                  selectedID: String?) {
            guard let container = satContainer else { return }

            let incoming = Set(positions.map { $0.id })

            // 消えた衛星を除去
            for (id, node) in nodes where !incoming.contains(id) {
                node.removeFromParentNode()
                nodes[id] = nil
            }

            for pos in positions {
                let target = parent.displayPosition(lat: pos.latitude,
                                                    lon: pos.longitude,
                                                    altKm: pos.altitudeKm)
                let isSelected = pos.id == selectedID
                if let node = nodes[pos.id] {
                    node.position = target
                    applyStyle(node, color: colorProvider(pos.sourceName), selected: isSelected)
                } else {
                    let node = makeSatelliteNode(color: colorProvider(pos.sourceName),
                                                 selected: isSelected)
                    node.name = pos.id
                    node.position = target
                    container.addChildNode(node)
                    nodes[pos.id] = node
                }
            }
        }

        private func makeSatelliteNode(color: String, selected: Bool) -> SCNNode {
            let dot = SCNSphere(radius: 0.012)
            dot.segmentCount = 8
            let node = SCNNode(geometry: dot)
            applyStyle(node, color: color, selected: selected)
            return node
        }

        private func applyStyle(_ node: SCNNode, color: String, selected: Bool) {
            guard let geometry = node.geometry as? SCNSphere,
                  let material = geometry.firstMaterial else { return }
            let uiColor = UIColor(hex: color)
            material.diffuse.contents = uiColor
            material.emission.contents = uiColor
            material.lightingModel = .constant
            let scale: Float = selected ? 2.2 : 1.0
            node.scale = SCNVector3(scale, scale, scale)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let point = gesture.location(in: scnView)
            let hits = scnView.hitTest(point, options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue])
            for hit in hits {
                if let name = hit.node.name, nodes[name] != nil {
                    parent.selectedID = name
                    return
                }
            }
        }
    }
}
