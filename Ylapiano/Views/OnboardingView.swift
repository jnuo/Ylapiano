import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var micPermissionGranted = false
    @State private var micPermissionDenied = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.85, blue: 1.0),
                    Color(red: 0.85, green: 0.92, blue: 1.0),
                    Color(red: 0.9, green: 1.0, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Welcome
                welcomePage
                    .tag(0)

                // Page 2: Microphone
                microphonePage
                    .tag(1)

                // Page 3: Ready
                readyPage
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "pianokeys")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .symbolEffect(.bounce, options: .repeating.speed(0.3))

            Text("Ylapiano")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Learn piano the fun way!")
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "music.note.list", text: "Follow songs note by note")
                featureRow(icon: "mic.fill", text: "Listens to your piano playing")
                featureRow(icon: "hand.thumbsup.fill", text: "Get instant feedback")
            }
            .padding(.top, 20)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Next")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Microphone Page

    private var microphonePage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(micPermissionGranted ? .green : .orange)
                .symbolEffect(.bounce, value: micPermissionGranted)

            Text("Microphone Access")
                .font(.system(.title, design: .rounded, weight: .bold))

            Text("Ylapiano listens to your piano through the microphone to know which notes you play.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            if micPermissionGranted {
                Label("Microphone enabled", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.green)
            } else if micPermissionDenied {
                VStack(spacing: 8) {
                    Label("Permission denied", systemImage: "xmark.circle.fill")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.red)
                    Text("You can enable it later in Settings.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    requestMicPermission()
                } label: {
                    Label("Allow Microphone", systemImage: "mic.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(width: 220)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
            }

            Spacer()

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("Next")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Ready Page

    private var readyPage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, options: .repeating.speed(0.5))

            Text("You're all set!")
                .font(.system(.title, design: .rounded, weight: .bold))

            Text("Pick a song and start playing. Have fun!")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("Let's Go!")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)
            Text(text)
                .font(.system(.body, design: .rounded))
        }
    }

    private func requestMicPermission() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micPermissionGranted = granted
                micPermissionDenied = !granted
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
