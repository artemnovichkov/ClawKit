import RealityKit
import SwiftUI

/// Shows the 3D claw machine and keeps the camera framed for the view's shape.
struct MachineView: View {
    let game: ClawGame

    var body: some View {
        GeometryReader { proxy in
            let aspect = Float(proxy.size.width / max(proxy.size.height, 1))
            RealityView { content in
                content.camera = .virtual
                content.add(game.scene.root)
                game.start(in: content)
            } update: { _ in
                game.scene.fitCamera(aspect: aspect)
            }
        }
    }
}
