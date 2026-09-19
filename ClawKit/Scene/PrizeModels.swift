import RealityKit
import SwiftUI

/// Marks an entity in the machine as a prize the claw can grab.
struct PrizeComponent: Component {
    let kind: PrizeKind
}

/// Sculpts each prize out of primitives, extruded paths, and extruded text.
/// Every model is built in whatever units are convenient, then scaled to `size`.
enum PrizeModels {
    static let size: Float = 0.052

    static func make(_ kind: PrizeKind) -> Entity {
        let sculpture = sculpt(kind)
        let prize = Entity()
        prize.name = kind.name
        prize.addChild(sculpture)

        // Fit the sculpture into a `size` cube, centered on the prize.
        let bounds = sculpture.visualBounds(relativeTo: prize)
        let scale = size / max(bounds.extents.max(), .ulpOfOne)
        sculpture.scale *= scale
        sculpture.position = -bounds.center * scale

        let extents = sculpture.visualBounds(relativeTo: prize).extents
        prize.components.set(PrizeComponent(kind: kind))
        prize.components.set(CollisionComponent(shapes: [.generateBox(size: extents)]))
        var body = PhysicsBodyComponent(
            massProperties: .init(mass: 0.05),
            material: .generate(staticFriction: 0.9, dynamicFriction: 0.7, restitution: 0.05),
            mode: .dynamic
        )
        body.linearDamping = 0.4
        body.angularDamping = 0.6
        body.isContinuousCollisionDetectionEnabled = true
        prize.components.set(body)
        return prize
    }

    // MARK: Sculptures

    private static func sculpt(_ kind: PrizeKind) -> Entity {
        let color = kind.uiColor
        switch kind {
        case .star:
            return extruded(starPath(points: 5, inner: 0.45), color: color)
        case .heart:
            return extruded(heartPath, color: color)
        case .braces:
            return text("{ }", color: color)
        case .warning:
            let sign = extruded(roundedTriangle, color: color)
            sign.addChild(text("!", color: .darkGray, depth: 0.2), at: [0, -0.06, 0.2], height: 0.5)
            return sign
        case .gear:
            let gear = extruded(gearPath, color: color)
            gear.addChild(ball(0.2, color: color.darker), at: [0, 0, 0.18])
            return gear
        case .bug:
            return bug
        case .hammer:
            return hammer
        case .spinner:
            return spinner
        case .stateCube:
            let cube = ModelEntity(mesh: .generateBox(size: 1, cornerRadius: 0.22), materials: [Plasticine.material(color)])
            cube.addChild(text("@", color: .white, depth: 0.25), at: [0, 0, 0.5], height: 0.7)
            return cube
        case .bird:
            return bird
        case .simulator:
            return phone(color: color)
        case .buildSucceeded:
            let badge = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 0.5), materials: [Plasticine.material(color)])
            badge.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let root = Entity()
            root.addChild(badge)
            root.addChild(extruded(checkPath, color: .white, depth: 0.15), at: [0, 0, 0.15], height: 0.55)
            return root
        case .approved:
            let seal = extruded(starPath(points: 14, inner: 0.86), color: color, chamfer: 0.06)
            seal.addChild(extruded(checkPath, color: .white, depth: 0.15), at: [0, 0, 0.15], height: 0.5)
            return seal
        case .duo:
            return duo
        }
    }

    private static var bug: Entity {
        let red = PrizeKind.bug.uiColor
        let root = Entity()
        let shell = ball(0.5, color: red)
        shell.scale = [1, 0.62, 1.2]
        root.addChild(shell)
        root.addChild(ball(0.26, color: .black), at: [0, 0.02, 0.58])
        for eye in [Float(-0.1), 0.1] {
            root.addChild(ball(0.07, color: .white), at: [eye, 0.14, 0.78])
        }
        for (x, z) in [(-0.22, 0.2), (0.22, 0.2), (-0.26, -0.18), (0.26, -0.18), (0, -0.42)] as [(Float, Float)] {
            let dot = ball(0.09, color: .black)
            dot.scale = [1, 0.5, 1]
            root.addChild(dot, at: [x, 0.28, z])
        }
        let seam = ModelEntity(mesh: .generateBox(width: 0.03, height: 0.05, depth: 1.1, cornerRadius: 0.015), materials: [Plasticine.material(.black)])
        root.addChild(seam, at: [0, 0.29, -0.02])
        return root
    }

    private static var hammer: Entity {
        let root = Entity()
        let handle = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.09), materials: [Plasticine.material(UIColor(red: 0.75, green: 0.5, blue: 0.3, alpha: 1))])
        root.addChild(handle, at: [0, -0.1, 0])
        let head = ModelEntity(mesh: .generateBox(width: 0.7, height: 0.26, depth: 0.26, cornerRadius: 0.08), materials: [Plasticine.material(PrizeKind.hammer.uiColor)])
        root.addChild(head, at: [0.05, 0.45, 0])
        return root
    }

    private static var spinner: Entity {
        let root = Entity()
        let count = 8
        for index in 0..<count {
            let angle = Float(index) / Float(count) * 2 * .pi
            let shade = 0.35 + 0.6 * CGFloat(index) / CGFloat(count)
            let bar = ModelEntity(
                mesh: .generateBox(width: 0.14, height: 0.4, depth: 0.14, cornerRadius: 0.07),
                materials: [Plasticine.material(UIColor(white: shade, alpha: 1))]
            )
            bar.position = [sin(angle) * 0.45, cos(angle) * 0.45, 0]
            bar.orientation = simd_quatf(angle: -angle, axis: [0, 0, 1])
            root.addChild(bar)
        }
        // Holds the bars together, so the spinner is a single rigid body.
        let hub = ModelEntity(mesh: .generateCylinder(height: 0.08, radius: 0.5), materials: [Plasticine.material(UIColor(white: 0.9, alpha: 1))])
        hub.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        root.addChild(hub, at: [0, 0, -0.06])
        return root
    }

    private static var bird: Entity {
        let color = PrizeKind.bird.uiColor
        let root = Entity()
        let body = ball(0.5, color: color)
        body.scale = [1.2, 0.95, 0.95]
        root.addChild(body)
        root.addChild(ball(0.34, color: color), at: [0.5, 0.38, 0])
        let beak = ModelEntity(mesh: .generateCone(height: 0.3, radius: 0.12), materials: [Plasticine.material(UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))])
        beak.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
        root.addChild(beak, at: [0.92, 0.36, 0])
        for side in [Float(-1), 1] {
            root.addChild(ball(0.07, color: .black), at: [0.66, 0.5, side * 0.24])
            let wing = ball(0.3, color: color.darker)
            wing.scale = [1.2, 0.7, 0.35]
            wing.orientation = simd_quatf(angle: 0.35, axis: [0, 0, 1])
            root.addChild(wing, at: [-0.1, 0.05, side * 0.45])
        }
        let tail = ModelEntity(mesh: .generateCone(height: 0.45, radius: 0.2), materials: [Plasticine.material(color.darker)])
        tail.orientation = simd_quatf(angle: .pi / 2 + 0.5, axis: [0, 0, 1])
        root.addChild(tail, at: [-0.68, 0.18, 0])
        return root
    }

    private static func phone(color: UIColor) -> Entity {
        let body = ModelEntity(mesh: .generateBox(width: 0.55, height: 1, depth: 0.12, cornerRadius: 0.1), materials: [Plasticine.material(color)])
        let screen = ModelEntity(mesh: .generateBox(width: 0.46, height: 0.88, depth: 0.04, cornerRadius: 0.06), materials: [Plasticine.material(UIColor(red: 0.45, green: 0.75, blue: 1, alpha: 1), roughness: 0.5)])
        body.addChild(screen, at: [0, 0, 0.05])
        let island = ModelEntity(mesh: .generateBox(width: 0.14, height: 0.05, depth: 0.03, cornerRadius: 0.025), materials: [Plasticine.material(.black)])
        body.addChild(island, at: [0, 0.37, 0.075])
        return body
    }

    /// An iPhone Duo, half-folded like a tiny laptop.
    private static var duo: Entity {
        let color = PrizeKind.duo.uiColor
        let screenColor = UIColor(red: 1, green: 0.55, blue: 0.7, alpha: 1)
        func half() -> ModelEntity {
            let slab = ModelEntity(mesh: .generateBox(width: 0.8, height: 0.06, depth: 0.55, cornerRadius: 0.03), materials: [Plasticine.material(color)])
            let screen = ModelEntity(mesh: .generateBox(width: 0.72, height: 0.02, depth: 0.47, cornerRadius: 0.02), materials: [Plasticine.material(screenColor, roughness: 0.5)])
            slab.addChild(screen, at: [0, 0.03, 0])
            return slab
        }
        let root = Entity()
        root.addChild(half(), at: [0, 0, 0.275])
        let hinge = Entity()
        let top = half()
        top.position = [0, 0, -0.275]
        hinge.addChild(top)
        hinge.orientation = simd_quatf(angle: .pi * 0.62, axis: [1, 0, 0])
        root.addChild(hinge)
        return root
    }

    // MARK: Building Blocks

    private static func ball(_ radius: Float, color: UIColor) -> ModelEntity {
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [Plasticine.material(color)])
    }

    private static func extruded(_ path: Path, color: UIColor, depth: Float = 0.3, chamfer: Float = 0.1) -> ModelEntity {
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: depth)
        options.chamferRadius = chamfer
        options.chamferMode = .both
        let mesh = (try? MeshResource(extruding: path, extrusionOptions: options)) ?? .generateSphere(radius: 0.5)
        return ModelEntity(mesh: mesh, materials: [Plasticine.material(color)])
    }

    private static func text(_ string: String, color: UIColor, depth: Float = 0.3) -> ModelEntity {
        let font = UIFont.systemFont(ofSize: 1, weight: .black)
        var attributed = AttributedString(string)
        attributed.uiKit.font = UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: 1)
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: depth)
        options.chamferRadius = 0.04
        options.chamferMode = .both
        let mesh = (try? MeshResource(extruding: attributed, extrusionOptions: options)) ?? .generateSphere(radius: 0.5)
        return ModelEntity(mesh: mesh, materials: [Plasticine.material(color)])
    }

    // MARK: Paths

    private static func starPath(points: Int, inner: CGFloat) -> Path {
        Path { path in
            for index in 0..<(points * 2) {
                let angle = CGFloat(index) / CGFloat(points * 2) * 2 * .pi
                let radius: CGFloat = index.isMultiple(of: 2) ? 0.5 : 0.5 * inner
                let point = CGPoint(x: sin(angle) * radius, y: cos(angle) * radius)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private static var heartPath: Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: -0.45))
            path.addCurve(to: CGPoint(x: -0.5, y: 0.12), control1: CGPoint(x: -0.2, y: -0.28), control2: CGPoint(x: -0.5, y: -0.12))
            path.addCurve(to: CGPoint(x: 0, y: 0.28), control1: CGPoint(x: -0.5, y: 0.48), control2: CGPoint(x: -0.08, y: 0.5))
            path.addCurve(to: CGPoint(x: 0.5, y: 0.12), control1: CGPoint(x: 0.08, y: 0.5), control2: CGPoint(x: 0.5, y: 0.48))
            path.addCurve(to: CGPoint(x: 0, y: -0.45), control1: CGPoint(x: 0.5, y: -0.12), control2: CGPoint(x: 0.2, y: -0.28))
            path.closeSubpath()
        }
    }

    private static var roundedTriangle: Path {
        let corners = [CGPoint(x: 0, y: 0.5), CGPoint(x: 0.55, y: -0.45), CGPoint(x: -0.55, y: -0.45)]
        return Path { path in
            path.move(to: CGPoint(x: (corners[0].x + corners[2].x) / 2, y: (corners[0].y + corners[2].y) / 2))
            for index in 0..<3 {
                path.addArc(tangent1End: corners[index], tangent2End: corners[(index + 1) % 3], radius: 0.12)
            }
            path.closeSubpath()
        }
    }

    private static var gearPath: Path {
        Path { path in
            let teeth = 8
            let steps = teeth * 4
            for index in 0..<steps {
                let angle = CGFloat(index) / CGFloat(steps) * 2 * .pi
                let radius: CGFloat = (index % 4) < 2 ? 0.5 : 0.38
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                index == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private static var checkPath: Path {
        Path { path in
            path.move(to: CGPoint(x: -0.3, y: 0))
            path.addLine(to: CGPoint(x: -0.08, y: -0.22))
            path.addLine(to: CGPoint(x: 0.32, y: 0.22))
        }
        .strokedPath(StrokeStyle(lineWidth: 0.16, lineCap: .round, lineJoin: .round))
    }
}

private extension Entity {
    /// Adds a child at a position, optionally scaled so its height matches `height`.
    func addChild(_ child: Entity, at position: SIMD3<Float>, height: Float? = nil) {
        if let height {
            let bounds = child.visualBounds(relativeTo: nil)
            let scale = height / max(bounds.extents.y, .ulpOfOne)
            child.scale = [scale, scale, 1]
            child.position = position - bounds.center * [scale, scale, 0]
        } else {
            child.position = position
        }
        addChild(child)
    }
}
