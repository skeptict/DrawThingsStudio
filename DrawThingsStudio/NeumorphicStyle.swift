//
//  NeumorphicStyle.swift
//  DrawThingsStudio
//
//  Neumorphic design system: colors, modifiers, and reusable components
//

import SwiftUI

// MARK: - Color Palette

extension Color {
    /// Warm beige background
    static let neuBackground = Color(red: 0.93, green: 0.90, blue: 0.85)
    /// Card/surface color (off-white)
    static let neuSurface = Color(red: 0.98, green: 0.97, blue: 0.96)
    /// Dark shadow color (beige-brown tinted)
    static let neuShadowDark = Color(red: 0.75, green: 0.71, blue: 0.65)
    /// Light shadow/highlight color
    static let neuShadowLight = Color.white
    /// Subtle text on beige background (WCAG AA compliant ~5.1:1 contrast)
    static let neuTextSecondary = Color(red: 0.40, green: 0.37, blue: 0.32)
    /// Accent for neumorphic UI
    static let neuAccent = Color(red: 0.55, green: 0.50, blue: 0.44)
}

// MARK: - Neumorphic Card Modifier (Raised/Convex)

struct NeumorphicCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.neuSurface)
                    .shadow(color: Color.neuShadowDark.opacity(0.3), radius: 10, x: 6, y: 6)
                    .shadow(color: Color.neuShadowLight.opacity(0.8), radius: 10, x: -6, y: -6)
            )
    }
}

// MARK: - Neumorphic Inset Modifier (Concave/Pressed)

struct NeumorphicInset: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.neuBackground.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.neuShadowDark.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Color.neuShadowDark.opacity(0.15), radius: 3, x: 2, y: 2)
                    .shadow(color: Color.neuShadowLight.opacity(0.7), radius: 3, x: -2, y: -2)
            )
    }
}

// MARK: - Neumorphic Button Style

struct NeumorphicButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isProminent ? Color.neuAccent : Color.neuSurface)
                    .shadow(
                        color: configuration.isPressed
                            ? Color.clear
                            : Color.neuShadowDark.opacity(0.25),
                        radius: configuration.isPressed ? 2 : 6,
                        x: configuration.isPressed ? 1 : 4,
                        y: configuration.isPressed ? 1 : 4
                    )
                    .shadow(
                        color: configuration.isPressed
                            ? Color.clear
                            : Color.neuShadowLight.opacity(0.7),
                        radius: configuration.isPressed ? 2 : 6,
                        x: configuration.isPressed ? -1 : -4,
                        y: configuration.isPressed ? -1 : -4
                    )
            )
            .foregroundColor(isProminent ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Neumorphic TextField Style

struct NeumorphicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.neuBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.neuShadowDark.opacity(0.1), lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Neumorphic Sidebar Style

struct NeumorphicSidebarItem: ViewModifier {
    var isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.neuSurface)
                            .shadow(color: Color.neuShadowDark.opacity(0.2), radius: 4, x: 2, y: 2)
                            .shadow(color: Color.neuShadowLight.opacity(0.7), radius: 4, x: -2, y: -2)
                    } else {
                        Color.clear
                    }
                }
            )
    }
}

// MARK: - Neumorphic Progress Bar

struct NeumorphicProgressBar: View {
    var value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track (inset)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.neuBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.neuShadowDark.opacity(0.1), lineWidth: 0.5)
                    )

                // Fill
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.neuAccent.opacity(0.6))
                    .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
                    .animation(.easeInOut(duration: 0.3), value: value)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// MARK: - View Extensions

extension View {
    /// Apply raised neumorphic card styling
    func neuCard(cornerRadius: CGFloat = 20, padding: CGFloat = 0) -> some View {
        modifier(NeumorphicCard(cornerRadius: cornerRadius, padding: padding))
    }

    /// Apply concave/inset neumorphic styling
    func neuInset(cornerRadius: CGFloat = 12) -> some View {
        modifier(NeumorphicInset(cornerRadius: cornerRadius))
    }

    /// Apply neumorphic sidebar item styling
    func neuSidebarItem(isSelected: Bool) -> some View {
        modifier(NeumorphicSidebarItem(isSelected: isSelected))
    }

    /// Apply neumorphic background to a full view
    func neuBackground() -> some View {
        self.background(Color.neuBackground)
    }
}

// MARK: - Neumorphic Section Header

struct NeuSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.neuTextSecondary)
            }
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.neuTextSecondary)
                .textCase(.uppercase)
                .tracking(0.5)
        }
    }
}

// MARK: - Neumorphic Status Badge

struct NeuStatusBadge: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption)
                .foregroundColor(.neuTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .neuInset(cornerRadius: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Reduced Motion Support

struct NeuAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Animation that respects the user's Reduce Motion accessibility setting.
    /// Returns nil (no animation) when Reduce Motion is enabled.
    func neuAnimation<V: Equatable>(_ animation: Animation = .easeInOut(duration: 0.25), value: V) -> some View {
        modifier(NeuAnimationModifier(animation: animation, value: value))
    }
}
