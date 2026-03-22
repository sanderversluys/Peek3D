import SceneKit

enum SceneConfigurator {

    /// Configure an SCNView for interactive preview (orbit, pan, zoom).
    static func configure(_ scnView: SCNView, with scene: SCNScene) {
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .windowBackgroundColor

        addCameraAndLights(to: scene)

        if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
            scnView.pointOfView = cameraNode
        }
    }

    /// Configure a scene for off-screen thumbnail rendering (no SCNView needed).
    static func configureForThumbnail(_ scene: SCNScene) {
        addCameraAndLights(to: scene)
    }

    // MARK: - Private

    static func addCameraAndLights(to scene: SCNScene) {
        let (center, radius) = boundingSphere(of: scene.rootNode)

        // Camera
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.automaticallyAdjustsZRange = true
        cameraNode.camera = camera

        let distance = Float(radius * 2.5)
        cameraNode.simdPosition = center + SIMD3<Float>(
            distance * 0.5,
            distance * 0.5,
            distance
        )
        cameraNode.look(at: SCNVector3(center.x, center.y, center.z))
        scene.rootNode.addChildNode(cameraNode)

        // Key light
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light!.type = .directional
        keyLight.light!.intensity = 800
        keyLight.light!.castsShadow = true
        keyLight.simdPosition = center + SIMD3<Float>(
            Float(radius),
            Float(radius) * 2,
            Float(radius) * 2
        )
        keyLight.look(at: SCNVector3(center.x, center.y, center.z))
        scene.rootNode.addChildNode(keyLight)

        // Fill light
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light!.type = .directional
        fillLight.light!.intensity = 300
        fillLight.simdPosition = center + SIMD3<Float>(
            -Float(radius),
            0,
            -Float(radius)
        )
        fillLight.look(at: SCNVector3(center.x, center.y, center.z))
        scene.rootNode.addChildNode(fillLight)

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.intensity = 400
        ambientLight.light!.color = NSColor.white
        scene.rootNode.addChildNode(ambientLight)
    }

    private static func boundingSphere(of node: SCNNode) -> (center: SIMD3<Float>, radius: Float) {
        let (minVec, maxVec) = node.boundingBox
        let mn = SIMD3<Float>(Float(minVec.x), Float(minVec.y), Float(minVec.z))
        let mx = SIMD3<Float>(Float(maxVec.x), Float(maxVec.y), Float(maxVec.z))
        let center = (mn + mx) / 2
        let radius = length(mx - mn) / 2
        return (center, max(radius, 0.001))
    }
}
