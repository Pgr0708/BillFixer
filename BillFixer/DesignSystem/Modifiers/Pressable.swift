import SwiftUI

/// Scale-to-0.96 press feedback with a spring release. Used by every tappable card and button.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var haptic: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(BFMotion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic { Haptics.tapLight() }
            }
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static var pressableQuiet: PressableButtonStyle { PressableButtonStyle(haptic: false) }
}
