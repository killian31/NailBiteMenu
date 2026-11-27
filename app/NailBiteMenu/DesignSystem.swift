import SwiftUI
import AppKit

// NailBite design system.
//
// Three color roles, never mixed:
//   accent (Slate Indigo) = things you can do: buttons, selection, links
//   bite   (Pumpkin Spice) = nail-biting happened: banner, reset, episode counts, charts
//   win    (Frozen Water)  = progress: bite-free time, streaks, bite-free days
// Everything else is a neutral from the palette (Shadow Grey, Charcoal, Glaucous).
// Text pairs below meet WCAG AA (4.5:1) on their surfaces in both modes; `textTertiary` is
// for captions and icons only (≥3.8:1).

extension Color {
    // Surfaces
    static let dsBackground = Color(light: 0xF4F7F6, dark: 0x221C20)
    static let dsSurface = Color(light: 0xFFFFFF, dark: 0x32292F)
    static let dsSurfaceMuted = Color(light: 0xEDF1EF, dark: 0x3D343B)
    static let dsBorder = Color(light: 0xE1E6E4, dark: 0x42383F)

    // Text
    static let dsText = Color(light: 0x32292F, dark: 0xF1EEF3)
    static let dsTextSecondary = Color(light: 0x575366, dark: 0xA9A3B8)
    static let dsTextTertiary = Color(light: 0x6E7DAB, dark: 0x8C8399)

    // Roles
    /// Indigo for text, links and icons (lifted in dark so it reads on dark surfaces).
    static let dsAccent = Color(light: 0x5762D5, dark: 0x8C95EC)
    /// Indigo for filled controls (buttons, selection). Same as the AccentColor asset,
    /// darker than `dsAccent` in dark mode so white labels on it stay readable (4.6:1).
    static let dsAccentFill = Color(light: 0x5762D5, dark: 0x5F6AD9)
    static let dsOnAccent = Color.white
    /// Bright pumpkin for fills, rings and bars. Never put white text on it.
    static let dsBite = Color(light: 0xFF8C42, dark: 0xFF8C42)
    /// Pumpkin that is readable as text or a small icon on light surfaces.
    static let dsBiteText = Color(light: 0xA84F12, dark: 0xFF8C42)
    static let dsBiteTint = Color(light: 0xFFE6D4, dark: 0x4A2A18)
    static let dsWin = Color(light: 0x2A6E5A, dark: 0xD1E3DD)
    static let dsWinTint = Color(light: 0xD1E3DD, dark: 0x2C3B37)
    static let dsChartNeutral = Color(light: 0x6E7DAB, dark: 0x8C8399)

    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
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
        static let control: CGFloat = 10
        static let tile: CGFloat = 16
        static let card: CGFloat = 20
        static let sheet: CGFloat = 28
    }

    enum Motion {
        /// State changes: toggles, selection, appearing content.
        static let snappy = Animation.snappy(duration: 0.3)
        /// Larger layout moves and charts.
        static let smooth = Animation.smooth(duration: 0.45)
        /// Numbers ticking over.
        static let counter = Animation.spring(response: 0.45, dampingFraction: 0.9)
    }
}

extension Font {
    /// Big numbers (timers, counts): rounded and tabular so digits don't jiggle.
    static func dsNumber(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
    static let dsTitle = Font.system(.title2, weight: .semibold)
    static let dsHeadline = Font.system(.headline)
    static let dsBody = Font.system(.body)
    static let dsCaption = Font.system(.caption)
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
