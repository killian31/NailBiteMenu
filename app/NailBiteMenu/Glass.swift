import SwiftUI

// Surfaces use the design system colors on every macOS version (that's the app's identity).
// Liquid Glass is kept where it belongs on macOS 26+: buttons, and alerts floating over other apps.
extension View {
    /// Content card: brand surface with a hairline border.
    func card(cornerRadius: CGFloat = DS.Radius.card) -> some View {
        background(Color.dsSurface, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.dsBorder, lineWidth: 1)
            )
    }

    /// Full-width card for the menu panel.
    func panelCard(cornerRadius: CGFloat = DS.Radius.tile) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .card(cornerRadius: cornerRadius)
    }

    /// Glass button style on macOS 26+, bordered before. Tinted by the accent color asset.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }

    /// Floating surface for alerts: glass on macOS 26+, material before.
    @ViewBuilder
    func floatingSurface<S: Shape>(_ shape: S) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.dsBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 16, y: 6)
        }
    }
}

/// The real app icon, so every screen shows the same mark as the Dock.
struct AppIconView: View {
    var size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Pumpkin disc with a dark glyph: the "bite" mark used by alerts.
/// (Pumpkin is too light for a white glyph, and too light on its own as an icon on white.)
struct BiteBadge: View {
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: "hand.raised.fill")
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(Color(light: 0x32292F, dark: 0x32292F))
            .frame(width: size, height: size)
            .background(Color.dsBite, in: .circle)
            .accessibilityHidden(true)
    }
}
