import SwiftUI

/// B9 (#28) — the 13 hand-finished picture icons, one recognizable object per
/// catalog song, code-drawn (Canvas + Path — no SF Symbols, no image assets).
/// Style rules, matched to Pim's chibi canon: one single object, thick rounded
/// `Palette.ink` outlines, flat token fills, friendly dot-eyes-and-smile faces,
/// readable at 120pt by a 5-year-old. All colors are `Palette` tokens.
///
/// Icons draw in a fixed 100×100 design space and scale to whatever frame the
/// card gives them.
struct SongIconView: View {
    let seedID: String?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.translateBy(
                x: (size.width - 100 * scale) / 2,
                y: (size.height - 100 * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            SongIconArt.draw(seedID: seedID, in: &context)
        }
        .accessibilityHidden(true) // the card announces the song title
    }
}

/// The drawing table. `drawers` is the single source of truth the completeness
/// test (`ArtSystemTests`) checks against the seed catalog.
enum SongIconArt {
    typealias Drawer = (inout GraphicsContext) -> Void

    static func hasIcon(for seedID: String) -> Bool { drawers[seedID] != nil }

    static func draw(seedID: String?, in ctx: inout GraphicsContext) {
        let drawer = seedID.flatMap { drawers[$0] } ?? fallbackNote
        drawer(&ctx)
    }

    /// seedID → icon. Objects verified against the seed catalog:
    /// Plim Plim is "Salta l'Esquirol" (jump, little squirrel) → an acorn —
    /// the squirrel itself is Pim's job, the acorn is the squirrel's song.
    private static let drawers: [String: Drawer] = [
        "plim-plim": acorn,
        "sol-solet": sun,
        "cargol-treu-banya": snail,
        "la-lluna-la-pruna": moon,
        "el-lleo-no-em-fa-por": lion,
        "kirmizi-balik": fish,
        "ali-babanin-ciftligi": barn,
        "mini-mini-bir-kus": bird,
        "portakali-soydum": orangeFruit,
        "old-macdonald": cow,
        "twinkle-twinkle": star,
        "wheels-on-the-bus": bus,
        "itsy-bitsy-spider": spider,
    ]

    // MARK: - Shared style

    /// Chibi line weight in the 100×100 design space (≈ Pim's outline feel).
    private static let line: CGFloat = 4.5
    private static let detailLine: CGFloat = 3

    private static func outline(_ ctx: inout GraphicsContext, _ path: Path, width: CGFloat = line, color: Color = Palette.ink) {
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    /// Flat fill + ink outline — the base look of every icon part.
    private static func paint(_ ctx: inout GraphicsContext, _ path: Path, _ fill: Color, width: CGFloat = line) {
        ctx.fill(path, with: .color(fill))
        outline(&ctx, path, width: width)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// Filled dot with no outline (eyes, blush, nostrils, texture).
    private static func dot(_ ctx: inout GraphicsContext, _ center: CGPoint, _ radius: CGFloat, _ color: Color) {
        ctx.fill(circle(center, radius), with: .color(color))
    }

    /// Downward smile arc, stroked in ink.
    private static func smile(_ ctx: inout GraphicsContext, _ center: CGPoint, _ radius: CGFloat, color: Color = Palette.ink) {
        var path = Path()
        path.move(to: CGPoint(x: center.x - radius, y: center.y))
        path.addQuadCurve(
            to: CGPoint(x: center.x + radius, y: center.y),
            control: CGPoint(x: center.x, y: center.y + radius * 1.3)
        )
        outline(&ctx, path, width: detailLine, color: color)
    }

    /// Dot eyes + smile + blush — the shared friendly face.
    private static func face(
        _ ctx: inout GraphicsContext, eyeY: CGFloat, eyeSpread: CGFloat, mouth: CGPoint,
        centerX: CGFloat = 50, eyeRadius: CGFloat = 2.8, smileRadius: CGFloat = 6, blush: Bool = true
    ) {
        dot(&ctx, CGPoint(x: centerX - eyeSpread, y: eyeY), eyeRadius, Palette.ink)
        dot(&ctx, CGPoint(x: centerX + eyeSpread, y: eyeY), eyeRadius, Palette.ink)
        smile(&ctx, mouth, smileRadius)
        if blush {
            dot(&ctx, CGPoint(x: centerX - eyeSpread - 8, y: eyeY + 8), 3.5, Palette.pimBlush)
            dot(&ctx, CGPoint(x: centerX + eyeSpread + 8, y: eyeY + 8), 3.5, Palette.pimBlush)
        }
    }

    private static func polar(_ center: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
        let rad = degrees * .pi / 180
        return CGPoint(x: center.x + radius * cos(rad), y: center.y + radius * sin(rad))
    }

    // MARK: - Fallback (user-created songs)

    /// Simple music note for songs without a seedID (user-created).
    private static func fallbackNote(_ ctx: inout GraphicsContext) {
        var stem = Path()
        stem.move(to: CGPoint(x: 62, y: 26))
        stem.addLine(to: CGPoint(x: 62, y: 66))
        outline(&ctx, stem, width: 5)
        var flag = Path()
        flag.move(to: CGPoint(x: 62, y: 26))
        flag.addQuadCurve(to: CGPoint(x: 78, y: 42), control: CGPoint(x: 78, y: 28))
        outline(&ctx, flag, width: 5)
        paint(&ctx, Path(ellipseIn: CGRect(x: 44, y: 60, width: 22, height: 17)), Palette.pimOrange)
    }

    // MARK: - The 13

    /// plim-plim — Salta l'Esquirol: the squirrel's acorn.
    private static func acorn(_ ctx: inout GraphicsContext) {
        // Stem
        var stem = Path()
        stem.move(to: CGPoint(x: 50, y: 20))
        stem.addQuadCurve(to: CGPoint(x: 58, y: 10), control: CGPoint(x: 50, y: 12))
        outline(&ctx, stem, width: 5)
        // Nut — egg shape pointing down, drawn first so the cap overlaps it
        var nut = Path()
        nut.move(to: CGPoint(x: 28, y: 42))
        nut.addCurve(to: CGPoint(x: 50, y: 88), control1: CGPoint(x: 28, y: 70), control2: CGPoint(x: 38, y: 84))
        nut.addCurve(to: CGPoint(x: 72, y: 42), control1: CGPoint(x: 62, y: 84), control2: CGPoint(x: 72, y: 70))
        nut.closeSubpath()
        paint(&ctx, nut, Palette.pimOrange)
        // Cap — dome with a gently bowed brim
        var cap = Path()
        cap.move(to: CGPoint(x: 24, y: 42))
        cap.addQuadCurve(to: CGPoint(x: 76, y: 42), control: CGPoint(x: 50, y: 8))
        cap.addQuadCurve(to: CGPoint(x: 24, y: 42), control: CGPoint(x: 50, y: 52))
        cap.closeSubpath()
        paint(&ctx, cap, Palette.pimDeepOrange)
        face(&ctx, eyeY: 60, eyeSpread: 8, mouth: CGPoint(x: 50, y: 66), smileRadius: 5)
    }

    /// sol-solet — smiling sun.
    private static func sun(_ ctx: inout GraphicsContext) {
        let center = CGPoint(x: 50, y: 52)
        // 8 petal rays
        for i in 0..<8 {
            let angle = CGFloat(i) * 45 - 90
            var ray = Path()
            ray.move(to: polar(center, 27, angle - 9))
            ray.addQuadCurve(to: polar(center, 27, angle + 9), control: polar(center, 48, angle))
            ray.closeSubpath()
            paint(&ctx, ray, Palette.gold)
        }
        paint(&ctx, circle(center, 27), Palette.gold)
        face(&ctx, eyeY: 47, eyeSpread: 9, mouth: CGPoint(x: 50, y: 56), smileRadius: 7)
    }

    /// cargol-treu-banya — snail with its horns out.
    private static func snail(_ ctx: inout GraphicsContext) {
        // Body — low slug with a raised head on the left
        var body = Path()
        body.move(to: CGPoint(x: 14, y: 82))
        body.addCurve(to: CGPoint(x: 24, y: 46), control1: CGPoint(x: 10, y: 68), control2: CGPoint(x: 12, y: 48))
        body.addCurve(to: CGPoint(x: 40, y: 66), control1: CGPoint(x: 36, y: 44), control2: CGPoint(x: 40, y: 56))
        body.addLine(to: CGPoint(x: 40, y: 74))
        body.addQuadCurve(to: CGPoint(x: 84, y: 82), control: CGPoint(x: 66, y: 70))
        body.addQuadCurve(to: CGPoint(x: 14, y: 82), control: CGPoint(x: 50, y: 86))
        body.closeSubpath()
        paint(&ctx, body, Palette.pimCream)
        // Horns ("treu banya!")
        for (from, to): (CGPoint, CGPoint) in [
            (CGPoint(x: 20, y: 46), CGPoint(x: 12, y: 30)),
            (CGPoint(x: 28, y: 46), CGPoint(x: 32, y: 28)),
        ] {
            var horn = Path()
            horn.move(to: from)
            horn.addLine(to: to)
            outline(&ctx, horn, width: 4)
            paint(&ctx, circle(to, 3.5), Palette.pimOrange, width: detailLine)
        }
        // Face on the head
        dot(&ctx, CGPoint(x: 20, y: 56), 2.6, Palette.ink)
        smile(&ctx, CGPoint(x: 22, y: 63), 4)
        dot(&ctx, CGPoint(x: 14, y: 62), 3, Palette.pimBlush)
        // Shell over the back, with a spiral
        let shellCenter = CGPoint(x: 60, y: 52)
        paint(&ctx, circle(shellCenter, 24), Palette.pimOrange)
        var spiral = Path()
        spiral.addArc(center: shellCenter, radius: 15, startAngle: .degrees(0), endAngle: .degrees(260), clockwise: false)
        spiral.addArc(center: CGPoint(x: shellCenter.x - 2, y: shellCenter.y - 2), radius: 7,
                      startAngle: .degrees(260), endAngle: .degrees(80), clockwise: false)
        outline(&ctx, spiral, width: detailLine)
    }

    /// la-lluna-la-pruna — sleepy crescent moon (with its tiny plum).
    private static func moon(_ ctx: inout GraphicsContext) {
        var crescent = Path()
        crescent.move(to: CGPoint(x: 60, y: 18))
        crescent.addCurve(to: CGPoint(x: 60, y: 82), control1: CGPoint(x: 10, y: 26), control2: CGPoint(x: 10, y: 74))
        crescent.addCurve(to: CGPoint(x: 60, y: 18), control1: CGPoint(x: 36, y: 70), control2: CGPoint(x: 36, y: 30))
        crescent.closeSubpath()
        paint(&ctx, crescent, Palette.gold)
        // Sleepy closed eye + soft smile on the bulge
        var eye = Path()
        eye.move(to: CGPoint(x: 27, y: 45))
        eye.addQuadCurve(to: CGPoint(x: 37, y: 45), control: CGPoint(x: 32, y: 51))
        outline(&ctx, eye, width: detailLine)
        smile(&ctx, CGPoint(x: 33, y: 57), 4.5)
        dot(&ctx, CGPoint(x: 24, y: 55), 3, Palette.pimBlush)
        // The plum, tucked beside the moon
        paint(&ctx, circle(CGPoint(x: 74, y: 68), 10), Palette.plum)
        var plumStem = Path()
        plumStem.move(to: CGPoint(x: 74, y: 58))
        plumStem.addQuadCurve(to: CGPoint(x: 79, y: 50), control: CGPoint(x: 74, y: 52))
        outline(&ctx, plumStem, width: detailLine)
    }

    /// el-lleo-no-em-fa-por — friendly lion face.
    private static func lion(_ ctx: inout GraphicsContext) {
        let center = CGPoint(x: 50, y: 50)
        // Scalloped mane — 10 bumps
        var mane = Path()
        let bumps = 10
        mane.move(to: polar(center, 28, -90))
        for i in 0..<bumps {
            let a0 = CGFloat(i) * 36 - 90
            let a1 = CGFloat(i + 1) * 36 - 90
            mane.addQuadCurve(to: polar(center, 28, a1), control: polar(center, 46, (a0 + a1) / 2))
        }
        mane.closeSubpath()
        paint(&ctx, mane, Palette.pimDeepOrange)
        // Face
        paint(&ctx, circle(center, 23), Palette.cream)
        face(&ctx, eyeY: 45, eyeSpread: 9, mouth: CGPoint(x: 50, y: 58), smileRadius: 6, blush: true)
        // Triangle nose
        var nose = Path()
        nose.move(to: CGPoint(x: 45, y: 52))
        nose.addLine(to: CGPoint(x: 55, y: 52))
        nose.addLine(to: CGPoint(x: 50, y: 58))
        nose.closeSubpath()
        ctx.fill(nose, with: .color(Palette.ink))
    }

    /// kirmizi-balik — the little red fish.
    private static func fish(_ ctx: inout GraphicsContext) {
        // Tail first, body overlaps the joint
        var tail = Path()
        tail.move(to: CGPoint(x: 64, y: 52))
        tail.addLine(to: CGPoint(x: 84, y: 36))
        tail.addQuadCurve(to: CGPoint(x: 84, y: 68), control: CGPoint(x: 90, y: 52))
        tail.closeSubpath()
        paint(&ctx, tail, Palette.deepRed)
        // Body
        paint(&ctx, Path(ellipseIn: CGRect(x: 18, y: 34, width: 52, height: 36)), Palette.deepRed)
        // Top fin
        var fin = Path()
        fin.move(to: CGPoint(x: 36, y: 36))
        fin.addQuadCurve(to: CGPoint(x: 52, y: 37), control: CGPoint(x: 46, y: 24))
        fin.closeSubpath()
        paint(&ctx, fin, Palette.deepRed, width: detailLine)
        // Eye + smile
        paint(&ctx, circle(CGPoint(x: 32, y: 47), 5), Palette.cream, width: detailLine)
        dot(&ctx, CGPoint(x: 32, y: 47), 2.2, Palette.ink)
        smile(&ctx, CGPoint(x: 26, y: 58), 4)
        // Bubbles
        outline(&ctx, circle(CGPoint(x: 14, y: 26), 4), width: detailLine, color: Palette.skyBlue)
        outline(&ctx, circle(CGPoint(x: 22, y: 16), 2.6), width: detailLine, color: Palette.skyBlue)
    }

    /// ali-babanin-ciftligi — the farm's red barn.
    private static func barn(_ ctx: inout GraphicsContext) {
        // Walls
        paint(&ctx, Path(roundedRect: CGRect(x: 24, y: 50, width: 52, height: 34), cornerRadius: 3), Palette.deepRed)
        // Gambrel-ish roof
        var roof = Path()
        roof.move(to: CGPoint(x: 16, y: 52))
        roof.addLine(to: CGPoint(x: 34, y: 26))
        roof.addLine(to: CGPoint(x: 66, y: 26))
        roof.addLine(to: CGPoint(x: 84, y: 52))
        roof.closeSubpath()
        paint(&ctx, roof, Palette.pimDeepOrange)
        // Round gable window
        paint(&ctx, circle(CGPoint(x: 50, y: 40), 6), Palette.pimCream, width: detailLine)
        // Arched door with cross brace
        var door = Path()
        door.move(to: CGPoint(x: 41, y: 84))
        door.addLine(to: CGPoint(x: 41, y: 66))
        door.addQuadCurve(to: CGPoint(x: 59, y: 66), control: CGPoint(x: 50, y: 56))
        door.addLine(to: CGPoint(x: 59, y: 84))
        door.closeSubpath()
        paint(&ctx, door, Palette.pimCream, width: detailLine)
        var brace = Path()
        brace.move(to: CGPoint(x: 43, y: 68))
        brace.addLine(to: CGPoint(x: 57, y: 82))
        brace.move(to: CGPoint(x: 57, y: 68))
        brace.addLine(to: CGPoint(x: 43, y: 82))
        outline(&ctx, brace, width: 2.2)
    }

    /// mini-mini-bir-kus — the tiny round bird.
    private static func bird(_ ctx: inout GraphicsContext) {
        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x: 30, y: 48))
        tail.addLine(to: CGPoint(x: 12, y: 38))
        tail.addLine(to: CGPoint(x: 16, y: 56))
        tail.closeSubpath()
        paint(&ctx, tail, Palette.skyBlue)
        // Body
        paint(&ctx, circle(CGPoint(x: 48, y: 52), 24), Palette.skyBlue)
        // Head tuft
        var tuft = Path()
        tuft.move(to: CGPoint(x: 50, y: 28))
        tuft.addQuadCurve(to: CGPoint(x: 57, y: 18), control: CGPoint(x: 50, y: 20))
        outline(&ctx, tuft, width: detailLine)
        // Wing
        var wing = Path()
        wing.move(to: CGPoint(x: 32, y: 52))
        wing.addQuadCurve(to: CGPoint(x: 52, y: 64), control: CGPoint(x: 34, y: 68))
        wing.addQuadCurve(to: CGPoint(x: 32, y: 52), control: CGPoint(x: 42, y: 52))
        wing.closeSubpath()
        paint(&ctx, wing, Palette.pimCream, width: detailLine)
        // Beak
        var beak = Path()
        beak.move(to: CGPoint(x: 70, y: 46))
        beak.addLine(to: CGPoint(x: 82, y: 51))
        beak.addLine(to: CGPoint(x: 70, y: 56))
        beak.closeSubpath()
        paint(&ctx, beak, Palette.gold, width: detailLine)
        // Face
        dot(&ctx, CGPoint(x: 60, y: 44), 2.8, Palette.ink)
        dot(&ctx, CGPoint(x: 63, y: 54), 3.2, Palette.pimBlush)
        // Legs
        var legs = Path()
        legs.move(to: CGPoint(x: 42, y: 76)); legs.addLine(to: CGPoint(x: 42, y: 88))
        legs.move(to: CGPoint(x: 54, y: 76)); legs.addLine(to: CGPoint(x: 54, y: 88))
        outline(&ctx, legs, width: detailLine)
    }

    /// portakali-soydum — the orange (the fruit you peel).
    private static func orangeFruit(_ ctx: inout GraphicsContext) {
        paint(&ctx, circle(CGPoint(x: 50, y: 56), 28), Palette.pimOrange)
        // Peel dimples
        for p in [CGPoint(x: 34, y: 44), CGPoint(x: 68, y: 48), CGPoint(x: 40, y: 74), CGPoint(x: 64, y: 70)] {
            dot(&ctx, p, 1.8, Palette.pimDeepOrange)
        }
        // Stem + leaf
        var stem = Path()
        stem.move(to: CGPoint(x: 50, y: 28))
        stem.addLine(to: CGPoint(x: 50, y: 20))
        outline(&ctx, stem, width: detailLine)
        var leaf = Path()
        leaf.move(to: CGPoint(x: 52, y: 22))
        leaf.addQuadCurve(to: CGPoint(x: 74, y: 14), control: CGPoint(x: 62, y: 6))
        leaf.addQuadCurve(to: CGPoint(x: 52, y: 22), control: CGPoint(x: 64, y: 24))
        leaf.closeSubpath()
        paint(&ctx, leaf, Palette.leafGreen, width: detailLine)
        face(&ctx, eyeY: 52, eyeSpread: 9, mouth: CGPoint(x: 50, y: 61), smileRadius: 6)
    }

    /// old-macdonald — the farm cow.
    private static func cow(_ ctx: inout GraphicsContext) {
        // Ears
        paint(&ctx, Path(ellipseIn: CGRect(x: 12, y: 38, width: 18, height: 12)), Palette.pimCream, width: detailLine)
        paint(&ctx, Path(ellipseIn: CGRect(x: 70, y: 38, width: 18, height: 12)), Palette.pimCream, width: detailLine)
        // Horns
        var hornL = Path()
        hornL.move(to: CGPoint(x: 34, y: 32))
        hornL.addQuadCurve(to: CGPoint(x: 26, y: 20), control: CGPoint(x: 26, y: 30))
        var hornR = Path()
        hornR.move(to: CGPoint(x: 66, y: 32))
        hornR.addQuadCurve(to: CGPoint(x: 74, y: 20), control: CGPoint(x: 74, y: 30))
        outline(&ctx, hornL, width: 5, color: Palette.pimDeepOrange)
        outline(&ctx, hornR, width: 5, color: Palette.pimDeepOrange)
        // Head
        paint(&ctx, Path(roundedRect: CGRect(x: 26, y: 30, width: 48, height: 48), cornerRadius: 18), Palette.cream)
        // Patch over the right brow
        dot(&ctx, CGPoint(x: 63, y: 40), 8, Palette.pimDeepOrange)
        // Eyes
        dot(&ctx, CGPoint(x: 40, y: 48), 2.8, Palette.ink)
        dot(&ctx, CGPoint(x: 60, y: 48), 2.8, Palette.ink)
        // Muzzle + nostrils
        paint(&ctx, Path(ellipseIn: CGRect(x: 33, y: 56, width: 34, height: 19)), Palette.pimBlush, width: detailLine)
        dot(&ctx, CGPoint(x: 43, y: 66), 2.4, Palette.ink)
        dot(&ctx, CGPoint(x: 57, y: 66), 2.4, Palette.ink)
    }

    /// twinkle-twinkle — the star.
    private static func star(_ ctx: inout GraphicsContext) {
        let center = CGPoint(x: 50, y: 52)
        var path = Path()
        for i in 0..<10 {
            let radius: CGFloat = i.isMultiple(of: 2) ? 36 : 17
            let point = polar(center, radius, CGFloat(i) * 36 - 90)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        paint(&ctx, path, Palette.gold)
        face(&ctx, eyeY: 49, eyeSpread: 8, mouth: CGPoint(x: 50, y: 57), smileRadius: 5.5)
    }

    /// wheels-on-the-bus — the bus.
    private static func bus(_ ctx: inout GraphicsContext) {
        // Body
        paint(&ctx, Path(roundedRect: CGRect(x: 12, y: 30, width: 76, height: 44), cornerRadius: 10), Palette.gold)
        // Windows
        paint(&ctx, Path(roundedRect: CGRect(x: 21, y: 38, width: 22, height: 15), cornerRadius: 4), Palette.skyBlue, width: detailLine)
        paint(&ctx, Path(roundedRect: CGRect(x: 49, y: 38, width: 22, height: 15), cornerRadius: 4), Palette.skyBlue, width: detailLine)
        // Headlight
        paint(&ctx, circle(CGPoint(x: 81, y: 62), 3.5), Palette.pimCream, width: 2.2)
        // Side stripe
        var stripe = Path()
        stripe.move(to: CGPoint(x: 14, y: 60))
        stripe.addLine(to: CGPoint(x: 72, y: 60))
        outline(&ctx, stripe, width: detailLine, color: Palette.pimDeepOrange)
        // Wheels
        for x in [CGFloat(30), CGFloat(66)] {
            paint(&ctx, circle(CGPoint(x: x, y: 74), 9.5), Palette.ink, width: detailLine)
            dot(&ctx, CGPoint(x: x, y: 74), 3.2, Palette.pimCream)
        }
    }

    /// itsy-bitsy-spider — the friendly spider on its thread.
    private static func spider(_ ctx: inout GraphicsContext) {
        // Thread
        var thread = Path()
        thread.move(to: CGPoint(x: 50, y: 4))
        thread.addLine(to: CGPoint(x: 50, y: 34))
        outline(&ctx, thread, width: detailLine)
        // Legs — 4 per side
        for (i, startY) in [CGFloat(46), 52, 58, 64].enumerated() {
            let endY = CGFloat(34 + i * 12)
            var left = Path()
            left.move(to: CGPoint(x: 36, y: startY))
            left.addQuadCurve(to: CGPoint(x: 12, y: endY), control: CGPoint(x: 20, y: startY - 8))
            var right = Path()
            right.move(to: CGPoint(x: 64, y: startY))
            right.addQuadCurve(to: CGPoint(x: 88, y: endY), control: CGPoint(x: 80, y: startY - 8))
            outline(&ctx, left, width: 4)
            outline(&ctx, right, width: 4)
        }
        // Body
        paint(&ctx, circle(CGPoint(x: 50, y: 56), 21), Palette.ink)
        // Big friendly eyes + cream smile
        paint(&ctx, circle(CGPoint(x: 42, y: 51), 5.5), Palette.cream, width: 2.2)
        paint(&ctx, circle(CGPoint(x: 58, y: 51), 5.5), Palette.cream, width: 2.2)
        dot(&ctx, CGPoint(x: 42, y: 51), 2.4, Palette.ink)
        dot(&ctx, CGPoint(x: 58, y: 51), 2.4, Palette.ink)
        smile(&ctx, CGPoint(x: 50, y: 63), 5, color: Palette.cream)
        dot(&ctx, CGPoint(x: 34, y: 60), 3, Palette.pimBlush)
        dot(&ctx, CGPoint(x: 66, y: 60), 3, Palette.pimBlush)
    }
}

#Preview("All 13") {
    let ids = [
        "plim-plim", "sol-solet", "cargol-treu-banya", "la-lluna-la-pruna",
        "el-lleo-no-em-fa-por", "kirmizi-balik", "ali-babanin-ciftligi",
        "mini-mini-bir-kus", "portakali-soydum", "old-macdonald",
        "twinkle-twinkle", "wheels-on-the-bus", "itsy-bitsy-spider",
    ]
    return ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))]) {
            ForEach(ids, id: \.self) { id in
                SongIconView(seedID: id)
                    .frame(width: 120, height: 120)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.pimCream))
            }
        }
        .padding()
    }
    .background(Palette.cream)
}
