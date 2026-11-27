import SwiftUI

// Liquid Glass on macOS 26+, the original opaque look on macOS 15.
extension View {
    /// Content card: glass on macOS 26+, solid control background before.
    @ViewBuilder
    func card(cornerRadius: CGFloat = 18) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    /// Card inside a surface that is already glass (the menu bar panel): a quiet fill, no glass-on-glass.
    @ViewBuilder
    func panelCard(cornerRadius: CGFloat = 16) -> some View {
        if #available(macOS 26, *) {
            frame(maxWidth: .infinity, alignment: .leading)
                .background(.quinary, in: .rect(cornerRadius: cornerRadius))
        } else {
            frame(maxWidth: .infinity, alignment: .leading)
                .card(cornerRadius: cornerRadius)
        }
    }

    /// Interactive glass for a custom tappable card (macOS 26+), plain card before.
    @ViewBuilder
    func interactiveCard(cornerRadius: CGFloat = 18) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            card(cornerRadius: cornerRadius)
        }
    }

    /// Glass button style on macOS 26+, bordered before.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }

    /// Opaque window background only where glass isn't available.
    @ViewBuilder
    func legacyWindowBackground() -> some View {
        if #available(macOS 26, *) {
            self
        } else {
            background(Color(nsColor: .windowBackgroundColor))
        }
    }

    /// Groups sibling glass shapes so they blend (macOS 26+).
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 14) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
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
