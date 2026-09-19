import SwiftUI

/// The palette of the control panel, matching the clay in the 3D scene.
enum ClayStyle {
    static let backdrop = Color(red: 1.0, green: 0.95, blue: 0.88)
    static let panel = Color(red: 0.98, green: 0.55, blue: 0.62)
    static let panelDark = Color(red: 0.4, green: 0.35, blue: 0.55)
    static let trim = Color(red: 1.0, green: 0.84, blue: 0.4)
    static let red = Color(red: 0.95, green: 0.27, blue: 0.3)
    static let green = Color(red: 0.3, green: 0.8, blue: 0.4)
    static let stick = Color(red: 0.75, green: 0.78, blue: 0.85)
    static let console = Color(red: 0.16, green: 0.15, blue: 0.2)
}

/// A puffy rounded slab of clay, used as a background.
struct ClaySlab: View {
    let color: Color
    var cornerRadius: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.gradient)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.5), .clear, .black.opacity(0.15)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 4
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
    }
}
