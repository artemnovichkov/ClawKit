import SwiftUI

/// The lower half of the machine: a console, a joystick, and a big Run button.
struct ControlPanel: View {
    @Bindable var game: ClawGame
    /// Lays the controls out in a column, for a panel beside the machine.
    var isVertical = false

    @State private var stick: SIMD2<Float> = .zero

    var body: some View {
        let layout = isVertical ? AnyLayout(VStackLayout(spacing: 28)) : AnyLayout(HStackLayout(spacing: 16))
        VStack(spacing: 18) {
            ConsoleLine(message: game.message, build: game.build)
            layout {
                Joystick(direction: $stick)
                if !isVertical { Spacer(minLength: 0) }
                RunButton(isEnabled: game.phase == .idle) {
                    game.run()
                }
            }
            .padding(.horizontal, isVertical ? 0 : 12)
        }
        .padding(20)
        .frame(maxWidth: 520)
        .background { ClaySlab(color: ClayStyle.panel) }
        .onChange(of: stick) { game.stick = stick }
        .sensoryFeedback(.success, trigger: game.wins)
        .sensoryFeedback(.impact(weight: .light), trigger: game.build)
    }
}

/// The last line of the Xcode console.
private struct ConsoleLine: View {
    let message: ClawGame.Message
    let build: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message.text)
                .foregroundStyle(message.tone == .info ? .white.opacity(0.85) : color)
                .lineLimit(3, reservesSpace: true)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(message.id)
                .transition(.push(from: .bottom))
            Text("Build \(build)")
                .foregroundStyle(.white.opacity(0.45))
                .contentTransition(.numericText(value: Double(build)))
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ClayStyle.console, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(.black.opacity(0.3), lineWidth: 2)
        }
        .animation(.snappy, value: message)
        .animation(.snappy, value: build)
    }

    private var icon: String {
        switch message.tone {
        case .info: "apple.terminal"
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch message.tone {
        case .info: .white.opacity(0.6)
        case .success: ClayStyle.green
        case .failure: ClayStyle.red.mix(with: .white, by: 0.2)
        }
    }
}

/// A big round button that runs the claw, like ⌘R.
private struct RunButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ClayBall(color: isEnabled ? ClayStyle.green : .gray, diameter: 112)
                Image(systemName: "play.fill")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 2)
                    .offset(x: 3)
            }
        }
        .buttonStyle(PressedStyle())
        .disabled(!isEnabled)
        .animation(.snappy, value: isEnabled)
        .accessibilityLabel("Run")
        .keyboardShortcut("r")
    }
}

private struct PressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.6), value: configuration.isPressed)
    }
}
