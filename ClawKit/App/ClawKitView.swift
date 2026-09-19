import SwiftUI

/// Turns iPhone Duo into a claw machine: the machine above the fold, the controls below it.
///
/// The two iPhone Duo APIs split the work the way Apple recommends:
/// - The **division region** is layout. Its frame says where the fold is, so the machine
///   and the control panel each get one half of the display. Stand the device on a table
///   like a small laptop, and it's an arcade cabinet.
/// - `onHingeChange` drives interactions. A closed device shows your prize shelf on the outer
///   display, and a quick fold or unfold shakes the machine.
struct ClawKitView: View {
    @State private var shelf: PrizeShelf
    @State private var game: ClawGame
    @State private var hinge: DeviceHinge?

    init() {
        let shelf = PrizeShelf()
        _shelf = State(initialValue: shelf)
        _game = State(initialValue: ClawGame(shelf: shelf))
    }

    var body: some View {
        // The arcade stays alive under the shelf, so the machine is just as you left it.
        ZStack {
            arcade
            if hinge?.status == .closed {
                ShelfView(shelf: shelf)
            }
        }
        // 👇 The API: the hinge drives interactions, not layout.
        .onHingeChange { oldContext, newContext in
            hinge = newContext.hinge
            if let old = oldContext.hinge, let new = newContext.hinge,
               abs(new.angle.degrees - old.angle.degrees) > 12 {
                game.shake()
            }
        }
    }

    private var arcade: some View {
        GeometryReader { proxy in
            // 👇 The API: include the inactive region, so a flat device splits along the fold too.
            let fold = proxy.reservedRegions(kind: .division, options: [.includeInactive]).first?.frame
            let halves = Halves(fold: fold, size: proxy.size)

            // The machine keeps its identity across layouts, so the 3D scene isn't rebuilt.
            ZStack(alignment: .topLeading) {
                MachineView(game: game)
                    .frame(width: halves.machine.width, height: halves.machine.height)
                    .offset(x: halves.machine.minX, y: halves.machine.minY)
                ControlPanel(game: game, isVertical: halves.isBook)
                    .padding(24)
                    .frame(width: halves.controls.width, height: halves.controls.height)
                    .offset(x: halves.controls.minX, y: halves.controls.minY)
            }
            .animation(.smooth, value: fold)
        }
        .ignoresSafeArea()
        .background(ClayStyle.backdrop)
    }
}

/// Splits the screen into the machine and the controls, on either side of the fold.
private struct Halves {
    var machine: CGRect
    var controls: CGRect
    var isBook = false

    init(fold: CGRect?, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        if let fold, fold.height > fold.width {
            // Book pose: the machine on the leading half, the controls on the trailing one.
            (machine, _) = bounds.divided(atDistance: fold.minX, from: .minXEdge)
            (controls, _) = bounds.divided(atDistance: size.width - fold.maxX, from: .maxXEdge)
            isBook = true
        } else {
            // Tabletop: the machine above the fold, the controls below it.
            let fold = fold ?? CGRect(x: 0, y: size.height * 0.6, width: size.width, height: 0)
            (machine, _) = bounds.divided(atDistance: fold.minY, from: .minYEdge)
            (controls, _) = bounds.divided(atDistance: size.height - fold.maxY, from: .maxYEdge)
        }
    }
}

#Preview {
    ClawKitView()
}
