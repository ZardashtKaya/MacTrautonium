import SwiftUI

public enum TrautoniumTheme {
    // Graphite Neutral Ramp
    public static let bgDeep = Color(red: 0.06, green: 0.06, blue: 0.065)    // #0f0f10
    public static let bgPage = Color(red: 0.08, green: 0.08, blue: 0.085)    // #141416
    public static let bgCard = Color(red: 0.10, green: 0.10, blue: 0.11)     // #1a1a1c
    public static let bgRaised = Color(red: 0.13, green: 0.13, blue: 0.14)   // #212124
    public static let bgHover = Color(red: 0.16, green: 0.16, blue: 0.17)    // #29292c

    // Hairline borders
    public static let hairline = Color.white.opacity(0.08)
    public static let hairlineStrong = Color.white.opacity(0.14)

    // Text roles (Primary, Secondary, Muted)
    public static let textPrimary = Color(red: 0.93, green: 0.93, blue: 0.94) // #ededed
    public static let textSecondary = Color(red: 0.63, green: 0.63, blue: 0.65) // #a1a1a6
    public static let textMuted = Color(red: 0.47, green: 0.47, blue: 0.50)    // #787880

    // Single laboratory accent (Incandescent amber)
    public static let accent = Color(red: 0.90, green: 0.62, blue: 0.24)       // #e69e3d
    public static let accentMuted = Color(red: 0.90, green: 0.62, blue: 0.24).opacity(0.18)

    // CRT Screen Phosphor (The one special moment for oscilloscope)
    public static let crtTrace = Color(red: 0.45, green: 0.88, blue: 0.58)
    public static let crtGraticule = Color(red: 0.45, green: 0.88, blue: 0.58).opacity(0.09)
    public static let crtBg = Color(red: 0.05, green: 0.065, blue: 0.055)

    // Semantic colors (toned to sit quietly in palette)
    public static let recordingRed = Color(red: 0.88, green: 0.30, blue: 0.32)
    public static let playGreen = Color(red: 0.32, green: 0.78, blue: 0.52)
}
