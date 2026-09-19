import RealityKit
import SwiftUI

/// The 3D claw machine: the cabinet, the claw, the lights and the camera.
///
/// The scene is built once and outlives any `RealityView` that shows it, so the machine keeps
/// its state when the layout changes around the fold.
@MainActor
final class MachineScene {
    // Interior of the cabinet, in meters. The floor is at y = 0.
    static let halfWidth: Float = 0.15
    static let halfDepth: Float = 0.1
    static let ceiling: Float = 0.34

    /// The prize chute, in the front-left corner.
    static let chute: (minX: Float, maxX: Float, minZ: Float, maxZ: Float) = (-halfWidth, -0.055, 0.005, halfDepth)
    static var chuteCenter: SIMD2<Float> {
        [(chute.minX + chute.maxX) / 2, (chute.minZ + chute.maxZ) / 2]
    }

    let root = Entity()
    let prizes = Entity()
    let camera = PerspectiveCamera()

    /// Moves along the gantry. The claw hangs below it.
    let carriage = Entity()
    /// The claw's hub. Grabbed prizes become its children.
    let hub = Entity()
    private let cable: ModelEntity
    private var prongs: [Entity] = []

    private static let clay = (
        cabinet: UIColor(red: 0.98, green: 0.55, blue: 0.62, alpha: 1),
        trim: UIColor(red: 1.0, green: 0.84, blue: 0.4, alpha: 1),
        floor: UIColor(red: 0.55, green: 0.8, blue: 0.95, alpha: 1),
        chute: UIColor(red: 0.4, green: 0.35, blue: 0.55, alpha: 1),
        backdrop: UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1),
        claw: UIColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
    )

    init() {
        cable = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.0025), materials: [Plasticine.glossy(.darkGray, metallic: 0.6)])
        root.addChild(prizes)
        buildCabinet()
        buildClaw()
        buildLights()
        root.addChild(camera)
        fitCamera(aspect: 1)
    }

    // MARK: Claw

    /// The claw's position inside the cabinet. `y` is the height of the hub.
    var clawPosition: SIMD3<Float> {
        get { [carriage.position.x, hub.position.y + Self.ceiling, carriage.position.z] }
        set {
            carriage.position = [newValue.x, Self.ceiling, newValue.z]
            hub.position = [0, newValue.y - Self.ceiling, 0]
            let length = Self.ceiling - newValue.y
            cable.scale = [1, max(length, 0.001), 1]
            cable.position = [0, -length / 2, 0]
        }
    }

    /// Opens the prongs from 0 (closed) to 1 (open).
    func setClawOpening(_ opening: Float) {
        let angle = 0.15 + 0.5 * opening
        for (index, prong) in prongs.enumerated() {
            let around = Float(index) / Float(prongs.count) * 2 * .pi
            prong.orientation = simd_quatf(angle: around, axis: [0, 1, 0]) * simd_quatf(angle: angle, axis: [1, 0, 0])
        }
    }

    // MARK: Camera

    /// Frames the whole cabinet for a view with the given aspect ratio (width / height).
    func fitCamera(aspect: Float) {
        let verticalFOV: Float = 35
        camera.camera.fieldOfViewInDegrees = verticalFOV
        let halfHeight: Float = 0.25, halfWidth: Float = 0.215
        let tanV = tan(verticalFOV / 2 * .pi / 180)
        let distance = max(halfHeight / tanV, halfWidth / (tanV * max(aspect, 0.1))) + Self.halfDepth + 0.04
        let target: SIMD3<Float> = [0, 0.19, 0]
        let eye = target + simd_normalize(SIMD3<Float>(0, 0.28, 1)) * distance
        camera.look(at: target, from: eye, relativeTo: nil)
    }

    // MARK: Building

    private func buildCabinet() {
        let w = Self.halfWidth, d = Self.halfDepth, c = Self.chute
        let wall: Float = 0.02
        let cabinet = Plasticine.material(Self.clay.cabinet)
        let trim = Plasticine.material(Self.clay.trim)

        // Floor with a hole for the chute.
        addBlock(size: [c.maxX - c.minX, wall, c.minZ + d], at: [(c.minX + c.maxX) / 2, -wall / 2, (c.minZ - d) / 2], material: Plasticine.material(Self.clay.floor))
        addBlock(size: [w - c.maxX, wall, 2 * d], at: [(w + c.maxX) / 2, -wall / 2, 0], material: Plasticine.material(Self.clay.floor))
        // A low rim around the chute, so prizes don't roll in on their own.
        addBlock(size: [0.008, 0.03, c.maxZ - c.minZ], at: [c.maxX, 0.015, (c.minZ + c.maxZ) / 2], material: trim)
        addBlock(size: [c.maxX - c.minX, 0.03, 0.008], at: [(c.minX + c.maxX) / 2, 0.015, c.minZ], material: trim)
        // The bin under the chute catches won prizes out of sight. Dark walls make the hole read as a hole.
        let shaft = Plasticine.material(Self.clay.chute.darker)
        addBlock(size: [2 * w, wall, 2 * d], at: [0, -0.12, 0], material: Plasticine.material(Self.clay.chute))
        addBlock(size: [c.maxX - c.minX, 0.1, 0.004], at: [(c.minX + c.maxX) / 2, -0.06, c.minZ], material: shaft)
        addBlock(size: [0.004, 0.1, c.maxZ - c.minZ], at: [c.maxX, -0.06, (c.minZ + c.maxZ) / 2], material: shaft)
        addBlock(size: [c.maxX - c.minX, 0.1, 0.004], at: [(c.minX + c.maxX) / 2, -0.06, c.maxZ], material: shaft, collides: false)
        addBlock(size: [0.004, 0.1, c.maxZ - c.minZ], at: [c.minX, -0.06, (c.minZ + c.maxZ) / 2], material: shaft, collides: false)

        // Walls: back, sides, and an invisible front glass.
        addBlock(size: [2 * w + 2 * wall, Self.ceiling + 0.16, wall], at: [0, Self.ceiling / 2 - 0.06, -d - wall / 2], material: Plasticine.material(Self.clay.cabinet.lighter))
        for side in [Float(-1), 1] {
            addBlock(size: [wall, Self.ceiling + 0.16, 2 * d + 2 * wall], at: [side * (w + wall / 2), Self.ceiling / 2 - 0.06, 0], material: cabinet)
        }
        addBlock(size: [2 * w, Self.ceiling + 0.1, 0.004], at: [0, Self.ceiling / 2, d + 0.002], material: cabinet, visible: false)
        addBlock(size: [2 * w, 0.004, 2 * d], at: [0, Self.ceiling + 0.03, 0], material: cabinet, visible: false)

        // The front base panel hides the bin.
        addBlock(size: [2 * w + 2 * wall, 0.14, 0.03], at: [0, -0.07, d + 0.015], material: cabinet)
        addBlock(size: [c.maxX - c.minX - 0.012, 0.05, 0.034], at: [(c.minX + c.maxX) / 2, -0.05, d + 0.015], material: Plasticine.material(Self.clay.chute))
        // Roof with a marquee.
        addBlock(size: [2 * w + 0.06, 0.05, 2 * d + 0.06], at: [0, Self.ceiling + 0.065, 0], material: cabinet)
        addBlock(size: [2 * w + 0.07, 0.012, 2 * d + 0.07], at: [0, Self.ceiling + 0.04, 0], material: trim)
        addMarquee(at: [0, Self.ceiling + 0.065, d + 0.035])

        // The gantry rail the claw rides on.
        addBlock(size: [2 * w, 0.01, 0.01], at: [0, Self.ceiling + 0.012, 0], material: Plasticine.glossy(Self.clay.claw, metallic: 0.5), collides: false)

        // A warm backdrop behind the cabinet.
        let backdrop = ModelEntity(mesh: .generatePlane(width: 4, height: 3), materials: [UnlitMaterial(color: Self.clay.backdrop)])
        backdrop.position = [0, 0.3, -0.6]
        root.addChild(backdrop)
        let table = ModelEntity(mesh: .generatePlane(width: 4, depth: 3), materials: [Plasticine.material(Self.clay.backdrop.darker.lighter)])
        table.position = [0, -0.14, 0]
        root.addChild(table)
    }

    private func addMarquee(at position: SIMD3<Float>) {
        let font = UIFont.systemFont(ofSize: 1, weight: .black)
        var title = AttributedString("CLAWKIT")
        title.uiKit.font = UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 1)
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: 0.25)
        options.chamferRadius = 0.05
        options.chamferMode = .both
        guard let mesh = try? MeshResource(extruding: title, extrusionOptions: options) else { return }
        let text = ModelEntity(mesh: mesh, materials: [Plasticine.material(.white)])
        let bounds = text.visualBounds(relativeTo: nil)
        let scale = 0.036 / bounds.extents.y
        text.scale = .init(repeating: scale)
        text.position = position - bounds.center * scale
        root.addChild(text)
    }

    private func buildClaw() {
        root.addChild(carriage)
        let block = ModelEntity(mesh: .generateBox(width: 0.04, height: 0.02, depth: 0.03, cornerRadius: 0.006), materials: [Plasticine.material(Self.clay.trim)])
        carriage.addChild(block)
        carriage.addChild(cable)
        carriage.addChild(hub)

        let chrome = Plasticine.glossy(Self.clay.claw, metallic: 0.8)
        let knob = ModelEntity(mesh: .generateSphere(radius: 0.014), materials: [Plasticine.material(Self.clay.cabinet)])
        knob.scale = [1, 0.8, 1]
        hub.addChild(knob)
        for _ in 0..<3 {
            let prong = Entity()
            let finger = ModelEntity(mesh: .generateBox(width: 0.006, height: 0.05, depth: 0.006, cornerRadius: 0.003), materials: [chrome])
            finger.position = [0, -0.025, 0.01]
            let tip = ModelEntity(mesh: .generateBox(width: 0.006, height: 0.018, depth: 0.006, cornerRadius: 0.003), materials: [chrome])
            tip.position = [0, -0.052, 0.005]
            tip.orientation = simd_quatf(angle: -0.9, axis: [1, 0, 0])
            prong.addChild(finger)
            prong.addChild(tip)
            hub.addChild(prong)
            prongs.append(prong)
        }
        // The hub pushes prizes around, but the prongs pass through them.
        hub.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.012)]))
        hub.components.set(PhysicsBodyComponent(massProperties: .default, material: nil, mode: .kinematic))
        setClawOpening(1)
    }

    private func buildLights() {
        let key = DirectionalLight()
        key.light.intensity = 3500
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.5, depthBias: 2)
        key.look(at: .zero, from: [0.4, 1.0, 0.8], relativeTo: nil)
        root.addChild(key)

        let fill = PointLight()
        fill.light.intensity = 3000
        fill.light.color = UIColor(red: 1, green: 0.9, blue: 0.95, alpha: 1)
        fill.light.attenuationRadius = 3
        fill.position = [-0.3, 0.3, 0.5]
        root.addChild(fill)
    }

    @discardableResult
    private func addBlock(size: SIMD3<Float>, at position: SIMD3<Float>, material: RealityKit.Material, visible: Bool = true, collides: Bool = true) -> Entity {
        let block: Entity
        if visible {
            let cornerRadius = min(size.min() / 2, 0.006)
            block = ModelEntity(mesh: .generateBox(size: size, cornerRadius: cornerRadius), materials: [material])
        } else {
            block = Entity()
        }
        block.position = position
        if collides {
            block.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
            block.components.set(PhysicsBodyComponent(
                massProperties: .default,
                material: .generate(staticFriction: 0.8, dynamicFriction: 0.6, restitution: 0.05),
                mode: .static
            ))
        }
        root.addChild(block)
        return block
    }
}
