import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    /// B31 (#56) — cold-launch intro, consumed once per process launch.
    /// Home stays mounted (and seeding) UNDERNEATH the overlay, so the intro
    /// costs zero time-to-interactive beyond the moment itself.
    @State private var showIntro = IntroGate.consumeShouldShow()
    @EnvironmentObject private var sampler: PianoSampler

    var body: some View {
        if shouldShowSpike {
            SpikeView()
        } else if hasCompletedOnboarding {
            ZStack {
                NavigationStack {
                    HomeScreen()
                }
                if showIntro {
                    IntroView(sampler: sampler) {
                        withAnimation(.easeOut(duration: IntroDesign.fadeOutSeconds)) {
                            showIntro = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    private var shouldShowSpike: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["YLAPIANO_SPIKE"] != nil
        #else
        return false
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(PianoSampler())
        .modelContainer(for: Song.self, inMemory: true)
}
