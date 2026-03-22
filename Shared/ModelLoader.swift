import SceneKit.ModelIO

enum ModelLoader {

    enum ModelError: Error, LocalizedError {
        case unsupportedFormat(String)
        case loadFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext): return "Unsupported format: .\(ext)"
            case .loadFailed(let msg): return "Failed to load model: \(msg)"
            }
        }
    }

    static func loadModel(from url: URL) throws -> SCNScene {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "stl", "obj":
            return try loadViaModelIO(url: url)
        case "3mf":
            return try loadThreeMF(url: url)
        default:
            throw ModelError.unsupportedFormat(ext)
        }
    }

    // MARK: - ModelIO (STL, OBJ)

    private static func loadViaModelIO(url: URL) throws -> SCNScene {
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: nil)
        guard asset.count > 0 else {
            throw ModelError.loadFailed("ModelIO returned empty asset for \(url.lastPathComponent)")
        }
        let scene = SCNScene(mdlAsset: asset)

        // Apply default PBR material if none set
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let geometry = node.geometry else { return }
            let needsMaterial = geometry.materials.isEmpty
                || geometry.materials.allSatisfy({ $0.diffuse.contents == nil })
            if needsMaterial {
                let material = SCNMaterial()
                material.diffuse.contents = NSColor(white: 0.85, alpha: 1.0)
                material.metalness.contents = 0.1
                material.roughness.contents = 0.6
                material.lightingModel = .physicallyBased
                material.isDoubleSided = true
                geometry.materials = [material]
            }
        }

        return scene
    }

    // MARK: - 3MF

    private static func loadThreeMF(url: URL) throws -> SCNScene {
        let parser = ThreeMFParser()
        let model = try parser.parse(url: url)
        return SceneBuilder.buildScene(from: model)
    }
}
