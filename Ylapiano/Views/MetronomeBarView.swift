import SwiftUI

struct MetronomeBarView: View {
    @Bindable var metronome: Metronome
    let onEditSong: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Play/Pause button
            Button {
                metronome.toggle()
            } label: {
                Image(systemName: metronome.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(metronome.isPlaying ? .orange : .green)
                    .symbolEffect(.bounce, value: metronome.isPlaying)
            }
            .buttonStyle(.plain)

            // BPM controls
            HStack(spacing: 8) {
                Button {
                    if metronome.bpm > 40 {
                        metronome.bpm -= 5
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    Image(systemName: "metronome.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metronome.bpm)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .monospacedDigit()
                }
                .frame(width: 60)

                Button {
                    if metronome.bpm < 220 {
                        metronome.bpm += 5
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Beat indicator
            if metronome.isPlaying {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { beat in
                        Circle()
                            .fill(
                                (metronome.currentBeat % 4) == beat
                                    ? Color.orange
                                    : Color.gray.opacity(0.3)
                            )
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut(duration: 0.1), value: metronome.currentBeat)
                    }
                }
            }

            Spacer()

            // Edit song button
            Button(action: onEditSong) {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
}

#Preview {
    MetronomeBarView(
        metronome: Metronome(bpm: 100),
        onEditSong: {}
    )
    .padding()
}
