import Cocoa
import QuickLookUI
import SceneKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var scnView: SCNView!

    override func loadView() {
        scnView = SCNView()
        self.view = scnView
    }

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let scene = try ModelLoader.loadModel(from: url)
                DispatchQueue.main.async {
                    SceneConfigurator.configure(self.scnView, with: scene)
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
