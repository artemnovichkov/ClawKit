import Observation
import RealityKit
import SwiftUI

/// The rules of the claw machine. Runs once per frame from RealityKit's update event.
@Observable
final class ClawGame {
    enum Phase: Equatable {
        case idle, dropping, closing, lifting, returning, releasing
    }

    /// A line in the console under the machine.
    struct Message: Equatable {
        enum Tone { case info, success, failure }
        let text: String
        let tone: Tone
        var id = UUID()
    }

    private(set) var phase: Phase = .idle
    private(set) var build = 0
    private(set) var message = Message(text: "Move the claw, then press Run.", tone: .info)
    /// Increments on every win, for haptics.
    private(set) var wins = 0

    /// The joystick direction, each axis in -1...1. `y` points into the machine.
    @ObservationIgnored var stick: SIMD2<Float> = .zero

    @ObservationIgnored let scene = MachineScene()
    @ObservationIgnored let shelf: PrizeShelf
    @ObservationIgnored private var updates: EventSubscription?
    @ObservationIgnored private var clawOpening: Float = 1
    @ObservationIgnored private var phaseTime: Float = 0
    @ObservationIgnored private var grabbed: Entity?
    /// When the grabbed prize slips during the lift, as a fraction of the lift.
    @ObservationIgnored private var slipAt: Float?
    @ObservationIgnored private var lastShake = Date.distantPast
    /// Attract mode: the machine plays by itself. Launch with `-autoplay` to record a demo.
    @ObservationIgnored private let isAutoplaying = ProcessInfo.processInfo.arguments.contains("-autoplay")
    @ObservationIgnored private var autoplayTarget: Entity?

    private static let prizeCount = 14
    private static let bottom: Float = 0.045
    private static let top: Float = 0.27
    private static let speed: Float = 0.13
    private static var home: SIMD3<Float> {
        [MachineScene.chuteCenter.x, top, MachineScene.chuteCenter.y]
    }

    init(shelf: PrizeShelf) {
        self.shelf = shelf
        PrizeComponent.registerComponent()
        scene.clawPosition = Self.home
        for index in 0..<Self.prizeCount {
            spawnPrize(height: 0.05 + Float(index % 7) * 0.035)
        }
    }

    /// Starts the game loop in a `RealityView`.
    func start(in content: RealityViewCameraContent) {
        updates = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.update(deltaTime: Float(min(event.deltaTime, 1.0 / 20)))
        }
    }

    // MARK: Input

    func run() {
        guard phase == .idle else { return }
        build += 1
        enter(.dropping)
    }

    /// Shakes the machine. Called when the device folds or unfolds quickly.
    func shake() {
        guard Date.now.timeIntervalSince(lastShake) > 1.5 else { return }
        lastShake = .now
        for prize in prizeEntities where prize !== grabbed {
            var motion = prize.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            motion.linearVelocity += SIMD3<Float>(.random(in: -0.5...0.5), .random(in: 0.5...1.0), .random(in: -0.5...0.5))
            motion.angularVelocity += SIMD3<Float>.random(in: -8...8)
            prize.components.set(motion)
        }
        say("Clean Build Folder ⇧⌘K", .info)
    }

    // MARK: Loop

    private func update(deltaTime dt: Float) {
        phaseTime += dt
        var claw = scene.clawPosition

        switch phase {
        case .idle:
            if isAutoplaying { autoplay(claw) }
            claw.x += stick.x * Self.speed * dt
            claw.z -= stick.y * Self.speed * dt
            claw = clamped(claw)
            dodge(claw)

        case .dropping:
            claw.y = max(claw.y - 0.16 * dt, Self.bottom)
            if claw.y <= Self.bottom { enter(.closing) }

        case .closing:
            clawOpening = max(clawOpening - 2.5 * dt, 0)
            if clawOpening == 0 {
                grab(at: claw)
                enter(.lifting)
            }

        case .lifting:
            claw.y = min(claw.y + 0.12 * dt, Self.top)
            let progress = (claw.y - Self.bottom) / (Self.top - Self.bottom)
            if let slipAt, progress >= slipAt {
                self.slipAt = nil
                release()
                say("Thread 1: EXC_BAD_ACCESS (code=1, address=0x0)", .failure)
            }
            if claw.y >= Self.top { enter(.returning) }

        case .returning:
            let target = Self.home
            let offset = SIMD2(target.x - claw.x, target.z - claw.z)
            let step = Self.speed * 1.2 * dt
            if simd_length(offset) <= step {
                claw.x = target.x
                claw.z = target.z
                enter(.releasing)
            } else {
                let move = simd_normalize(offset) * step
                claw.x += move.x
                claw.z += move.y
            }

        case .releasing:
            clawOpening = min(clawOpening + 2 * dt, 1)
            if grabbed != nil, clawOpening > 0.4 { release() }
            if phaseTime > 1 { enter(.idle) }
        }

        scene.clawPosition = claw
        scene.setClawOpening(clawOpening)
        collectFallenPrizes()
    }

    private func enter(_ next: Phase) {
        phase = next
        phaseTime = 0
    }

    private func clamped(_ claw: SIMD3<Float>) -> SIMD3<Float> {
        let margin: Float = 0.025
        return [
            min(max(claw.x, -MachineScene.halfWidth + margin), MachineScene.halfWidth - margin),
            claw.y,
            min(max(claw.z, -MachineScene.halfDepth + margin), MachineScene.halfDepth - margin),
        ]
    }

    // MARK: Prizes

    private var prizeEntities: [Entity] {
        Array(scene.prizes.children)
    }

    private func grab(at claw: SIMD3<Float>) {
        let reach: Float = 0.03
        let candidate = prizeEntities
            .map { prize -> (Entity, Float) in
                let position = prize.position(relativeTo: nil)
                return (prize, simd_distance(SIMD2(position.x, position.z), SIMD2(claw.x, claw.z)))
            }
            .filter { $0.1 < reach && $0.0.position(relativeTo: nil).y < claw.y + 0.02 }
            .min { $0.1 < $1.1 }?.0

        guard let prize = candidate, let kind = prize.components[PrizeComponent.self]?.kind else {
            say("Fatal error: Unexpectedly found nil while unwrapping an Optional value", .failure)
            return
        }

        grabbed = prize
        setMode(.kinematic, for: prize)
        prize.setParent(scene.hub, preservingWorldTransform: true)
        prize.move(to: Transform(scale: prize.scale, rotation: prize.orientation, translation: [0, -0.045, 0]), relativeTo: scene.hub, duration: 0.25)
        slipAt = Double.random(in: 0...1) < kind.rarity.gripChance ? nil : Float.random(in: 0.3...0.8)
    }

    private func release() {
        guard let prize = grabbed else { return }
        grabbed = nil
        prize.setParent(scene.prizes, preservingWorldTransform: true)
        prize.stopAllAnimations()
        setMode(.dynamic, for: prize)
        // A nudge wakes the body up, so it falls right away.
        prize.components.set(PhysicsMotionComponent(linearVelocity: [0, -0.1, 0]))
    }

    private func setMode(_ mode: PhysicsBodyMode, for prize: Entity) {
        guard var body = prize.components[PhysicsBodyComponent.self] else { return }
        body.mode = mode
        prize.components.set(body)
        prize.components.remove(PhysicsMotionComponent.self)
    }

    /// Prizes that fell down the chute are won. Prizes that escaped the machine come back.
    private func collectFallenPrizes() {
        for prize in prizeEntities where prize !== grabbed {
            let position = prize.position(relativeTo: nil)
            guard position.y < -0.05 else { continue }
            prize.removeFromParent()
            if let kind = prize.components[PrizeComponent.self]?.kind, isInChute(position) {
                shelf.add(kind)
                wins += 1
                say("Merged to main 🎉 +1 \(kind.name) (\(kind.rarity.title))", .success)
            }
            spawnPrize(height: 0.25)
        }
    }

    private func isInChute(_ position: SIMD3<Float>) -> Bool {
        let chute = MachineScene.chute
        return (chute.minX - 0.02...chute.maxX + 0.02).contains(position.x)
            && (chute.minZ - 0.02...chute.maxZ + 0.02).contains(position.z)
    }

    private func spawnPrize(height: Float) {
        let prize = PrizeModels.make(.random())
        let chute = MachineScene.chute
        var position: SIMD3<Float>
        repeat {
            position = [
                .random(in: -MachineScene.halfWidth + 0.035...MachineScene.halfWidth - 0.035),
                height,
                .random(in: -MachineScene.halfDepth + 0.035...MachineScene.halfDepth - 0.035),
            ]
        } while position.x < chute.maxX + 0.03 && position.z > chute.minZ - 0.03
        prize.position = position
        prize.orientation = simd_quatf(angle: .random(in: 0...(2 * .pi)), axis: simd_normalize(.random(in: -1...1)))
        scene.prizes.addChild(prize)
    }

    /// The bug crawls away from the claw hovering above it. It's a bug, after all.
    private func dodge(_ claw: SIMD3<Float>) {
        for prize in prizeEntities where prize.components[PrizeComponent.self]?.kind == .bug {
            let position = prize.position(relativeTo: nil)
            let away = SIMD2(position.x - claw.x, position.z - claw.z)
            let distance = simd_length(away)
            guard distance < 0.05, distance > 0.001, position.y < 0.05 else { continue }
            let velocity = simd_normalize(away) * 0.06
            var motion = prize.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            motion.linearVelocity = [velocity.x, max(motion.linearVelocity.y, 0), velocity.y]
            prize.components.set(motion)
        }
    }

    /// Steers the stick toward a random prize, then presses Run.
    private func autoplay(_ claw: SIMD3<Float>) {
        guard phaseTime > 1.2 else { stick = .zero; return }
        if autoplayTarget?.parent !== scene.prizes {
            autoplayTarget = prizeEntities.filter { !isInChute($0.position(relativeTo: nil)) }.randomElement()
        }
        guard let target = autoplayTarget?.position(relativeTo: nil) else { return }
        let offset = SIMD2(target.x - claw.x, claw.z - target.z)
        if simd_length(offset) < 0.004 {
            stick = .zero
            autoplayTarget = nil
            run()
        } else {
            stick = offset / max(simd_length(offset), 0.03)
        }
    }

    private func say(_ text: String, _ tone: Message.Tone) {
        message = Message(text: text, tone: tone)
    }
}
