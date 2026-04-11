import SwiftUI

struct SongCardView: View {
    let song: Song
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            // Music note icon
            Image(systemName: "music.note")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Text(song.title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "metronome")
                    .font(.caption)
                Text("\(song.bpm) BPM")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.8))

            Text("\(song.notes.count) notes")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.gradient)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
}

extension SongCardView {
    static let cardColors: [Color] = [
        Color(red: 1.0, green: 0.6, blue: 0.6),   // Soft red / coral
        Color(red: 1.0, green: 0.8, blue: 0.5),   // Warm yellow
        Color(red: 0.6, green: 0.9, blue: 0.6),   // Soft green
        Color(red: 0.5, green: 0.7, blue: 1.0),   // Sky blue
        Color(red: 0.8, green: 0.6, blue: 1.0),   // Lavender
        Color(red: 1.0, green: 0.7, blue: 0.85),  // Pink
        Color(red: 0.5, green: 0.9, blue: 0.9),   // Teal
        Color(red: 1.0, green: 0.65, blue: 0.45),  // Orange
    ]

    static func color(for index: Int) -> Color {
        cardColors[index % cardColors.count]
    }
}

#Preview {
    let song = Song(title: "Plim Plim", bpm: 90, notes: [
        NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
        NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
    ])
    return SongCardView(song: song, color: .blue)
        .frame(width: 180, height: 200)
        .padding()
}
