import QuickLookThumbnailing
import SceneKit
import AppKit

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let url = request.fileURL
        let maxSize = request.maximumSize
        let scale = request.scale

        // 3MF fast path: extract embedded thumbnail PNG
        if url.pathExtension.lowercased() == "3mf",
           let thumbData = ThreeMFParser.extractThumbnail(from: url),
           let image = NSImage(data: thumbData) {
            let reply = QLThumbnailReply(contextSize: maxSize, drawing: { context in
                let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = nsContext
                image.draw(in: CGRect(origin: .zero, size: maxSize))
                NSGraphicsContext.restoreGraphicsState()
                return true
            })
            handler(reply, nil)
            return
        }

        // Fallback: render model via SCNRenderer
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scene = try ModelLoader.loadModel(from: url)
                SceneConfigurator.configureForThumbnail(scene)

                let renderer = SCNRenderer(device: nil, options: nil)
                renderer.scene = scene
                if let cameraNode = scene.rootNode.childNodes.first(where: { $0.camera != nil }) {
                    renderer.pointOfView = cameraNode
                }

                let pixelSize = CGSize(
                    width: maxSize.width * scale,
                    height: maxSize.height * scale
                )
                let snapshot = renderer.snapshot(
                    atTime: 0,
                    with: pixelSize,
                    antialiasingMode: .multisampling4X
                )

                let reply = QLThumbnailReply(contextSize: maxSize, drawing: { context in
                    let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = nsContext
                    snapshot.draw(in: CGRect(origin: .zero, size: maxSize))
                    NSGraphicsContext.restoreGraphicsState()
                    return true
                })
                handler(reply, nil)
            } catch {
                handler(nil, error)
            }
        }
    }
}
