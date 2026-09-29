import SwiftUI

/// Labelled text field with icon, inline error, valid tick, secure toggle and optional low-confidence rail (OCR review).
struct BFTextField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure = false
    var error: String? = nil
    var lowConfidence = false
    /// Green border + tick once the value passes validation.
    var isValid = false
    var autocapitalization: TextInputAutocapitalization = .sentences
    var onEdit: (() -> Void)? = nil

    @State private var reveal = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(BFColor.text3)
                if lowConfidence { Pill(text: "Low confidence", tone: .amber, icon: "exclamationmark.triangle.fill", small: true) }
            }
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon).foregroundStyle(focused ? BFColor.blue : BFColor.text3).frame(width: 18) }
                Group {
                    if isSecure && !reveal {
                        SecureField(prompt, text: $text)
                    } else {
                        TextField(prompt, text: $text)
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(BFColor.text1)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(keyboard != .default || isSecure)
                .focused($focused)
                .onChange(of: text) { _, _ in if focused { onEdit?() } }
                if showValid {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BFColor.green)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityLabel("Looks good")
                }
                if isSecure {
                    Button { reveal.toggle(); Haptics.selection() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(BFColor.text3)
                    }
                    .accessibilityLabel(reveal ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(BFColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(error != nil ? BFColor.red : (showValid ? BFColor.green : (focused ? BFColor.blue : (lowConfidence ? BFColor.amber : BFColor.line))),
                                  lineWidth: focused || error != nil || lowConfidence || showValid ? 1.5 : 1)
            }
            .overlay(alignment: .leading) {
                if lowConfidence { Capsule().fill(BFColor.amber).frame(width: 3).padding(.vertical, 10) }
            }
            .animation(BFMotion.quick, value: focused)
            .animation(BFMotion.quick, value: showValid)
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BFColor.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var showValid: Bool { isValid && error == nil }
}
