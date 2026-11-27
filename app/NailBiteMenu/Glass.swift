import SwiftUI

// Surfaces. Depth comes from surface steps and hairlines, not shadows: the content carries the weight.
extension View {
    /// Content card: surface with a hairline border.
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
