import SwiftUI

/// B9 (#28) — art-system song card. The picture icon dominates (pre-readers
/// choose by picture), the title sits small below, and 0-3 progress stars
/// render ON the card (Khan-checkmark pattern: progress lives on the choosing
/// surface). Cream card ground + Pim palette tokens only.
///
/// Return-home star-pop: when `animateFromStars` is non-nil and lower than
/// `song.bestStars`, the newly earned star(s) pop in with the same spring the
/// result screen uses (`.spring(response: 0.4, dampingFraction: 0.45)`,
/// one star per 340 ms beat). Reduce Motion renders them statically.
struct SongCardView: View {
    let song: Song
    /// Star count last seen on home (B9 star-pop); nil = no pop, show as-is.
    var animateFromStars: Int? = nil
    /// Called once the pop finishes so the owner can clear its pop marker
    /// (a LazyVGrid re-creates cards on scroll; without this it would re-pop).
    var onStarPopFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pop-in-progress fill count; nil when no pop is running. Displayed fill
    /// falls back to `animateFromStars` (pre-pop, so the card never flashes
    /// the new star early) and then to `earned`.
    @State private var popRevealed: Int? = nil

    private var earned: Int { min(max(song.bestStars, 0), 3) }
    private var displayedStars: Int { popRevealed ?? animateFromStars ?? earned }

    var body: some View {
        VStack(spacing: 6) {
            // The picture — ≥60% of the card.
            SongIconView(seedID: song.seedID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 8)

            Text(song.title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)

            starsRow
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Palette.pimCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Palette.ink.opacity(0.08), lineWidth: 1.5)
                )
                .shadow(color: Palette.ink.opacity(0.12), radius: 6, x: 0, y: 3)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(song.title), \(earned) of 3 stars")
        .task(id: animateFromStars) { await revealStars() }
    }

    private var starsRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                let isEarned = index < earned
                let isShown = index < displayedStars
                Image(systemName: isEarned ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isEarned ? Palette.gold : Palette.ink.opacity(0.22))
                    .scaleEffect(isEarned ? (isShown ? 1 : 0.1) : 1)
                    .opacity(isEarned ? (isShown ? 1 : 0) : 1)
                    .rotationEffect(.degrees(isEarned && !isShown ? -40 : 0))
            }
        }
    }

    /// Same reveal choreography as `SongResultView.runSequence` — pop, beat,
    /// pop, beat — but only for stars earned since the kid last saw this card.
    @MainActor
    private func revealStars() async {
        guard let from = animateFromStars else {
            popRevealed = nil // pop over (marker cleared) — settle on `earned`
            return
        }
        guard from < earned, !reduceMotion else {
            // Nothing new, or Reduce Motion: static appear, no choreography.
            popRevealed = earned
            onStarPopFinished()
            return
        }
        popRevealed = min(max(from, 0), 3)
        // Let the home screen settle before the pop draws the eye.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        for i in (min(max(from, 0), 3) + 1)...earned {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { popRevealed = i }
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled else { return }
        }
        onStarPopFinished()
    }
}

#Preview {
    let song = Song(title: "Kırmızı Balık", bpm: 90, seedID: "kirmizi-balik", notes: [
        NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
        NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
    ])
    song.bestStars = 2
    return SongCardView(song: song)
        .frame(width: 180, height: 200)
        .padding()
        .background(Palette.cream)
}
