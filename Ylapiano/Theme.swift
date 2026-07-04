import SwiftUI

/// B9 (#28) — the locked Ylapiano palette: ≤12 named tokens, extracted from
/// Pim canon art (the mascot stills were color-sampled; see the hex notes) plus
/// the handful of UI accents the app already shipped. This file is the ONLY
/// place a literal RGB color may be defined — `ArtSystemTests` greps the app
/// source and fails on any literal color constructor outside this file, and
/// caps the token count here at 12.
///
/// SpriteKit call sites bridge with `UIColor(Palette.x)` (SKColor == UIColor).
enum Palette {
    // MARK: Pim canon (sampled from MascotGreeting/Cheer/Pointing PNGs)

    /// Pim's fur — the brand orange. ~#F88D3E.
    static let pimOrange = Color(red: 0.973, green: 0.553, blue: 0.243)
    /// Fur shading / deep orange. ~#E06438.
    static let pimDeepOrange = Color(red: 0.878, green: 0.392, blue: 0.220)
    /// Pim's belly cream — card ground + warm header band. ~#F9EACB.
    static let pimCream = Color(red: 0.976, green: 0.918, blue: 0.796)
    /// Rosy cheeks. ~#F8B5A9.
    static let pimBlush = Color(red: 0.973, green: 0.710, blue: 0.663)
    /// Outline / eye brown — icon linework and text ink. ~#382826.
    static let ink = Color(red: 0.220, green: 0.157, blue: 0.149)

    // MARK: App surfaces & accents (pre-B9 UI, folded into the token set)

    /// App/scene background cream (lighter than the card ground). #FFF7ED.
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.93)
    /// Star gold — result stars, card stars, sun/moon/star icons. ~#FFC733.
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.20)
    /// CTA coral — primary buttons, celebration accents. ~#F8734D.
    static let coral = Color(red: 0.97, green: 0.45, blue: 0.30)
    /// Deep red — MIDI-connected glyph, falling notes, fish, barn. ~#D62929.
    static let deepRed = Color(red: 0.84, green: 0.16, blue: 0.16)

    // MARK: Icon support (used only by the 13 song picture icons)

    /// Leaf green — orange-fruit leaf, snail accents. ~#7AB352.
    static let leafGreen = Color(red: 0.478, green: 0.702, blue: 0.322)
    /// Sky blue — little bird, bus windows, fish bubbles. ~#72B0DA.
    static let skyBlue = Color(red: 0.447, green: 0.690, blue: 0.855)
    /// Plum purple — "la pruna" in La lluna, la pruna. ~#98689C.
    static let plum = Color(red: 0.596, green: 0.408, blue: 0.612)
}
