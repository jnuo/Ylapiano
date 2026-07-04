import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                // B9: warm Pim-palette wash (was a cool pastel gradient).
                colors: [
                    Palette.cream,
                    Palette.pimCream,
                    Palette.pimBlush.opacity(0.45)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Welcome
                welcomePage
                    .tag(0)

                // Page 2: Ready
                readyPage
                    .tag(1)
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
                featureRow(icon: "pianokeys", text: "Play on screen or a USB piano")
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

    // LocalizedStringKey so the literal feature lines resolve through the
    // String Catalog (B13) — a String parameter would render verbatim.
    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)
            Text(text)
                .font(.system(.body, design: .rounded))
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
