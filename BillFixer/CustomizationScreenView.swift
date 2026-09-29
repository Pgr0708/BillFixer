//
//  CustomizationScreenView.swift
//  BillFixer — One-time theme & accent colour picker shown after notification prompt
//

import SwiftUI

struct CustomizationScreenView: View {
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var selectedColor: AppAccentColor = .teal
    @State private var selectedTheme: AppTheme = .system

    // MARK: - Accent colour options
    private let colorOptions: [(AppAccentColor, Color, String)] = [
        (.teal,    Color(hex: "#0A9396"), "Teal"),
        (.ocean,   Color(hex: "#0066FF"), "Ocean"),
        (.purple,  Color(hex: "#8A2BE2"), "Purple"),
        (.amber,   Color(hex: "#FFBF00"), "Amber"),
        (.emerald, Color(hex: "#00A86B"), "Emerald"),
    ]

    var body: some View {
        ZStack {
            // ── Gradient background ──────────────────────────────────────
            backgroundLayer

            // ── Decorative circles (circular design) ────────────────────
            circleDecorations

            // ── Content ─────────────────────────────────────────────────
            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#0F2B5B"), Color(hex: "#00B4A0")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: Color(hex: "#00B4A0").opacity(0.4), radius: 20, y: 8)

                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 40))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(hex: "#00D4BC"))
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .padding(.bottom, 24)

                // Title
                Text("Make it yours")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(light: 0x0F2B5B, dark: 0xFFFFFF))
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)

                Text("Pick an accent colour and appearance")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BFColor.text2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    .offset(y: appeared ? 0 : 16)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 36)

                // ── Accent Colour Picker ─────────────────────────────────
                colorPickerSection
                    .offset(y: appeared ? 0 : 24)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 28)

                // ── Theme Picker ─────────────────────────────────────────
                themePickerSection
                    .offset(y: appeared ? 0 : 24)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                // ── CTA ──────────────────────────────────────────────────
                Button(action: finish) {
                    HStack(spacing: 10) {
                        Text("Looks great!")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#0F2B5B"), selectedColor.color],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "#0F2B5B").opacity(0.3), radius: 16, y: 8)
                }
                .buttonStyle(.pressable)
                .scaleEffect(appeared ? 1 : 0.9)
                .opacity(appeared ? 1 : 0)
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0.15) :
                .spring(response: 0.6, dampingFraction: 0.75)) {
                appeared = true
            }
            // Pre-fill from existing settings
            selectedColor = AppAccentColor(rawValue: settings.selectedAccentColor) ?? .teal
            selectedTheme = AppTheme(rawValue: settings.selectedTheme) ?? .system
        }
    }

    // MARK: - Colour Picker

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Accent Colour", systemImage: "circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BFColor.text2)
                .padding(.horizontal, 28)

            HStack(spacing: 18) {
                ForEach(colorOptions, id: \.0.rawValue) { option, color, name in
                    colorChip(option: option, color: color, name: name)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func colorChip(option: AppAccentColor, color: Color, name: String) -> some View {
        let isSelected = selectedColor == option
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                selectedColor = option
                settings.selectedAccentColor = option.rawValue
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .shadow(color: color.opacity(0.5), radius: isSelected ? 12 : 4, y: isSelected ? 4 : 2)
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityLabel("\(name) \(isSelected ? "selected" : "")")
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Theme Picker

    private var themePickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Appearance", systemImage: "sun.max.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BFColor.text2)
                .padding(.horizontal, 28)

            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    themeChip(theme)
                }
            }
            .padding(.horizontal, 28)
        }
    }

    private func themeChip(_ theme: AppTheme) -> some View {
        let isSelected = selectedTheme == theme
        let icon: String = {
            switch theme {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }()

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                selectedTheme = theme
                settings.selectedTheme = theme.rawValue
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected
                            ? LinearGradient(colors: [Color(hex: "#0F2B5B"), selectedColor.color],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [BFColor.line, BFColor.line],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 60, height: 60)
                        .shadow(color: isSelected ? Color(hex: "#0F2B5B").opacity(0.25) : .clear,
                                radius: 10, y: 4)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : BFColor.text2)
                }

                Text(theme.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(light: 0x0F2B5B, dark: 0xFFFFFF) : BFColor.text3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Background & Decorations

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(light: 0xF0F4FF, dark: 0x0B1636), Color(light: 0xE8F8F5, dark: 0x0A1024)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var circleDecorations: some View {
        ZStack {
            // Top-right large circle
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "#0F2B5B").opacity(0.08),
                                            Color(hex: "#00B4A0").opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 320, height: 320)
                .offset(x: 160, y: -100)
                .blur(radius: 2)

            // Bottom-left medium circle
            Circle()
                .fill(
                    LinearGradient(colors: [Color(hex: "#00B4A0").opacity(0.10),
                                            Color(hex: "#0F2B5B").opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 240, height: 240)
                .offset(x: -100, y: 300)
                .blur(radius: 1)

            // Small accent circle
            Circle()
                .fill(selectedColor.color.opacity(0.15))
                .frame(width: 120, height: 120)
                .offset(x: 130, y: 260)
                .blur(radius: 4)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedColor.rawValue)
        }
    }

    // MARK: - Finish

    private func finish() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(BFMotion.smooth) {
            settings.hasSeenCustomization = true
        }
    }
}

#Preview {
    CustomizationScreenView()
        .environmentObject(SettingsManager())
}
