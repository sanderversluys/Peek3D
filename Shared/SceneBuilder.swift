import SceneKit
import simd

enum SceneBuilder {

    static func buildScene(from model: ThreeMFModel) -> SCNScene {
        let scene = SCNScene()

        if !model.buildItems.isEmpty {
            for item in model.buildItems {
                if let node = buildNode(
                    objectId: item.objectId,
                    objects: model.objects,
                    visited: []
                ) {
                    if let transform = item.transform {
                        node.simdTransform = transform
                    }
                    scene.rootNode.addChildNode(node)
                }
            }
        } else {
            // No build items — render all objects that have meshes
            for obj in model.objects.values {
                if let node = buildNodeFromObject(obj, objects: model.objects, visited: []) {
                    scene.rootNode.addChildNode(node)
                }
            }
        }

        return scene
    }

    // MARK: - Private

    private static func buildNode(
        objectId: String,
        objects: [String: ThreeMFObject],
        visited: Set<String>
    ) -> SCNNode? {
        guard !visited.contains(objectId),
              let object = objects[objectId] else { return nil }
        return buildNodeFromObject(object, objects: objects, visited: visited)
    }

    private static func buildNodeFromObject(
        _ object: ThreeMFObject,
        objects: [String: ThreeMFObject],
        visited: Set<String>
    ) -> SCNNode? {
        var visited = visited
        visited.insert(object.id)

        let node = SCNNode()

        if let mesh = object.mesh {
            node.geometry = buildGeometry(from: mesh)
        }

        for component in object.components {
            if let childNode = buildNode(
                objectId: component.objectId,
                objects: objects,
                visited: visited
            ) {
                if let transform = component.transform {
                    childNode.simdTransform = transform
                }
                node.addChildNode(childNode)
            }
        }

        return node
    }

    /// Max triangles before we skip smooth normals and use stride-based decimation
    private static let normalThreshold = 500_000
    private static let maxTriangles = 2_000_000

    private static func buildGeometry(from mesh: ThreeMFMesh) -> SCNGeometry {
        var vertices = mesh.vertices
        var triangles = mesh.triangles
        let vertexCount = vertices.count

        // Decimate very large meshes by taking every Nth triangle
        if triangles.count > maxTriangles {
            let stride = (triangles.count + maxTriangles - 1) / maxTriangles
            triangles = (0..<triangles.count).compactMap { $0 % stride == 0 ? triangles[$0] : nil }
        }

        // Compute per-vertex normals (skip for very large meshes — use flat shading)
        let useSmooth = triangles.count <= normalThreshold
        var normals = [SIMD3<Float>](repeating: SIMD3(0, 1, 0), count: vertexCount)
        if useSmooth {
            normals = [SIMD3<Float>](repeating: .zero, count: vertexCount)
            for (i0, i1, i2) in triangles {
                guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }
                let p0 = vertices[i0]
                let p1 = vertices[i1]
                let p2 = vertices[i2]
                let faceNormal = cross(p1 - p0, p2 - p0)
                let len = length(faceNormal)
                guard len > 1e-10 else { continue }
                let n = faceNormal / len
                normals[i0] += n
                normals[i1] += n
                normals[i2] += n
            }
            normals = normals.map { length($0) > 1e-10 ? normalize($0) : SIMD3(0, 1, 0) }
        }

        // Geometry sources
        let scnVertices = vertices.map { SCNVector3($0.x, $0.y, $0.z) }
        let scnNormals = normals.map { SCNVector3($0.x, $0.y, $0.z) }
        let vertexSource = SCNGeometrySource(vertices: scnVertices)
        let normalSource = SCNGeometrySource(normals: scnNormals)

        // Index buffer
        var indices: [UInt32] = []
        indices.reserveCapacity(triangles.count * 3)
        for (i0, i1, i2) in triangles {
            guard i0 < vertexCount, i1 < vertexCount, i2 < vertexCount else { continue }
            indices.append(UInt32(i0))
            indices.append(UInt32(i1))
            indices.append(UInt32(i2))
        }
        let indexData = Data(
            bytes: indices,
            count: indices.count * MemoryLayout<UInt32>.size
        )
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: indices.count / 3,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])

        // Default material — light gray PBR
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(white: 0.85, alpha: 1.0)
        material.metalness.contents = 0.1
        material.roughness.contents = 0.6
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true
        geometry.materials = [material]

        return geometry
    }
}
