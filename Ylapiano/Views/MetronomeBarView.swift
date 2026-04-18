import SwiftUI

struct MetronomeBarView: View {
    @Bindable var metronome: Metronome
    let onEditSong: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // BPM controls
            Button {
                if metronome.bpm > 40 { metronome.bpm -= 5 }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            Text("\(metronome.bpm)")
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
                .frame(width: 36)

            Button {
                if metronome.bpm < 220 { metronome.bpm += 5 }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            // Edit song button
            Button(action: onEditSong) {
                Image(systemName: "pencil.circle")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MetronomeBarView(
        metronome: Metronome(bpm: 100),
        onEditSong: {}
    )
    .padding()
}
