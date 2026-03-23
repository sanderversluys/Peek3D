import Cocoa
import QuickLookUI
import SceneKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var containerView: NSView!
    private var scnView: SCNView!

    override func loadView() {
        containerView = NSView()
        self.view = containerView
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        // For very large 3MF files, show the embedded thumbnail instead
        if url.pathExtension.lowercased() == "3mf",
           let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           fileSize > 30_000_000,
           let thumbData = ThreeMFParser.extractThumbnail(from: url),
           let image = NSImage(data: thumbData) {
            DispatchQueue.main.async {
                let imageView = NSImageView(image: image)
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.frame = self.containerView.bounds
                imageView.autoresizingMask = [.width, .height]
                self.containerView.addSubview(imageView)
                handler(nil)
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scene = try ModelLoader.loadModel(from: url)
                DispatchQueue.main.async {
                    self.scnView = SCNView(frame: self.containerView.bounds)
                    self.scnView.autoresizingMask = [.width, .height]
                    self.containerView.addSubview(self.scnView)
                    SceneConfigurator.configure(self.scnView, with: scene)
                    SceneConfigurator.addRotation(to: scene)
                    self.scnView.isPlaying = true
                    handler(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    handler(error)
                }
            }
        }
    }
}
