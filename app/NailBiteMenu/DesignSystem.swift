import SwiftUI
import AppKit

// NailBite design system, proposal C ("Signal").
//
// Monochrome ink on paper, plus one color that means one thing:
//   signal (vermilion) = nail-biting happened: the alert, episode counts, the bite charts.
//   ink               = everything you can do and every number that is good news.
//   live (green)      = the camera is on. Same green as the camera light next to the lens.
// Text pairs meet WCAG AA (4.5:1) on their surfaces in both modes, `dsTextTertiary` included.

extension Color {
    // Surfaces
    static let dsBackground = Color(light: 0xF4F4F1, dark: 0x0F0F10)
    static let dsSurface = Color(light: 0xFFFFFF, dark: 0x18181A)
    static let dsSurfaceRaised = Color(light: 0xEDEDEA, dark: 0x232326)
    /// Hairlines: the text color at low opacity, so they sit on any surface.
    static let dsBorder = Color(light: 0x151517, dark: 0xF2F2F0).opacity(0.09)

    // Text
    static let dsText = Color(light: 0x151517, dark: 0xF2F2F0)
    static let dsTextSecondary = Color(light: 0x4A4A4F, dark: 0xA1A1A6)
    static let dsTextTertiary = Color(light: 0x6B6B6B, dark: 0x8E8E93)
    /// Text on an ink fill.
    static let dsOnInk = Color(light: 0xFFFFFF, dark: 0x111112)

    // Signal
    /// Vermilion for bars, cells, glows. Never text on light surfaces.
    static let dsSignal = Color(light: 0xE5432A, dark: 0xFF5A3D)
    /// Vermilion that reads as text or as a fill under white text (5.3:1).
    static let dsSignalText = Color(light: 0xC8341C, dark: 0xFF5A3D)
    static let dsSignalTint = Color(light: 0xFBE5E0, dark: 0x3A1A14)

    /// Camera-on dot only.
    static let dsLive = Color(light: 0x1E9E4A, dark: 0x30D158)

    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }

    /// The alert glow. Display P3, a touch richer than sRGB can show, on the displays that have it.
    static let signalGlow = NSColor(displayP3Red: 0.95, green: 0.25, blue: 0.14, alpha: 1)
}

enum DS {
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let tile: CGFloat = 12
        static let card: CGFloat = 16
        static let sheet: CGFloat = 20
    }

    enum Motion {
        /// State changes: toggles, selection, appearing content.
        static let snappy = Animation.snappy(duration: 0.24)
        /// Charts and range changes.
        static let smooth = Animation.smooth(duration: 0.4)
        /// Numbers ticking over.
        static let counter = Animation.spring(response: 0.4, dampingFraction: 1)
    }
}

extension Font {
    /// The display face: SF Pro Compressed, tabular. Big figures only (timers, counts).
    static func dsFigure(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.compressed).monospacedDigit()
    }
    /// Meta, axis labels, counts in lists: SF Mono.
    static let dsMeta = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let dsPageTitle = Font.system(size: 26, weight: .semibold)
    static let dsHeadline = Font.system(size: 13, weight: .semibold)
    static let dsBody = Font.system(size: 13)
    static let dsCaption = Font.system(size: 12)
}

// MARK: - Buttons

/// Ink fill, inverse label. The one primary action on a surface.
struct InkButtonStyle: ButtonStyle {
    var large = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14 : 13, weight: .semibold))
            .foregroundStyle(Color.dsOnInk)
            .padding(.horizontal, large ? 20 : 14)
            .frame(height: large ? 40 : 30)
            .background(Color.dsText.opacity(configuration.isPressed ? 0.82 : 1),
                        in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(.rect)
    }
}

/// Raised surface with a hairline. Everything that isn't the primary action.
struct QuietButtonStyle: ButtonStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: large ? 14 : 13, weight: .medium))
            .foregroundStyle(Color.dsText)
            .padding(.horizontal, large ? 20 : 12)
            .frame(height: large ? 40 : 30)
            .background(Color.dsSurfaceRaised.opacity(configuration.isPressed ? 0.6 : 1),
                        in: .rect(cornerRadius: DS.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
                .strokeBorder(Color.dsBorder))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(.rect)
    }
}

// MARK: - Signature pieces

/// The camera-on dot. Green like the light by the lens; grey and hollow when paused.
struct LiveDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Color.dsLive : Color.clear)
            .strokeBorder(isOn ? Color.clear : Color.dsTextTertiary, lineWidth: 1.5)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

/// "Watching" / "Paused" with the live dot.
struct LiveStatus: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 6) {
            LiveDot(isOn: isOn)
            Text(isOn ? "Watching" : "Paused")
                .font(.dsCaption.weight(.medium))
                .foregroundStyle(Color.dsTextSecondary)
                .contentTransition(.opacity)
        }
        .animation(DS.Motion.snappy, value: isOn)
    }
}

extension View {
    /// The signature: a short vermilion bar on the leading edge of anything that counts bites.
    /// It echoes the alert, which comes in from the edges of the screen.
    func signalEdge(_ on: Bool = true, inset: CGFloat = DS.Space.l) -> some View {
        overlay(alignment: .leading) {
            if on {
                Capsule()
                    .fill(Color.dsSignal)
                    .frame(width: 3)
                    .padding(.vertical, inset)
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Appearance setting

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Applied app-wide so the menu panel, windows and alert overlays all follow it.
    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
