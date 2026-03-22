import Foundation
import simd

struct ThreeMFMesh {
    var vertices: [SIMD3<Float>]
    var triangles: [(Int, Int, Int)]
}

struct ThreeMFObject {
    var id: String
    var mesh: ThreeMFMesh?
    var components: [ThreeMFComponent] = []
}

struct ThreeMFComponent {
    var objectId: String
    var transform: simd_float4x4?
    var path: String?
}

struct ThreeMFBuildItem {
    var objectId: String
    var transform: simd_float4x4?
}

struct ThreeMFModel {
    var objects: [String: ThreeMFObject] = [:]
    var buildItems: [ThreeMFBuildItem] = []
}
