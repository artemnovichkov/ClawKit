import SwiftUI

/// An arcade joystick made of clay. Reports its direction, each axis in -1...1, `y` pointing up.
struct Joystick: View {
    @Binding var direction: SIMD2<Float>
    var diameter: CGFloat = 132

    @State private var offset: CGSize = .zero

    private var travel: CGFloat { diameter * 0.3 }

    var body: some View {
        ZStack {
            Circle()
                .fill(ClayStyle.panelDark.gradient)
                .overlay {
                    Circle().strokeBorder(.black.opacity(0.15), lineWidth: 3)
                }
                .shadow(color: .black.opacity(0.25), radius: 1, y: -2)
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: diameter * 0.55, weight: .black))
                .foregroundStyle(.white.opacity(0.08))
            // The stick, stretching from the base to the ball.
            Capsule()
                .fill(ClayStyle.stick.gradient)
                .frame(width: diameter * 0.14, height: diameter * 0.14 + hypot(offset.width, offset.height))
                .offset(y: -hypot(offset.width, offset.height) / 2)
                .rotationEffect(.radians(atan2(offset.width, -offset.height)))
            ClayBall(color: ClayStyle.red, diameter: diameter * 0.46)
                .offset(offset)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(.circle)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var translation = value.translation
                    let length = hypot(translation.width, translation.height)
                    if length > travel {
                        translation.width *= travel / length
                        translation.height *= travel / length
                    }
                    offset = translation
                    direction = [Float(translation.width / travel), Float(-translation.height / travel)]
                }
                .onEnded { _ in
                    withAnimation(.spring(duration: 0.3, bounce: 0.5)) { offset = .zero }
                    direction = .zero
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Joystick")
    }
}

/// A shiny ball of clay with a soft highlight.
struct ClayBall: View {
    let color: Color
    let diameter: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.mix(with: .white, by: 0.45), color, color.mix(with: .black, by: 0.25)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: diameter * 0.7
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: .black.opacity(0.3), radius: 6, y: 5)
    }
}

#Preview {
    @Previewable @State var direction = SIMD2<Float>.zero
    Joystick(direction: $direction)
        .padding()
        .background(ClayStyle.panel)
}
