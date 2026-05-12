import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if shouldShowSpike {
            SpikeView()
        } else if hasCompletedOnboarding {
            NavigationStack {
                HomeScreen()
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
        .modelContainer(for: Song.self, inMemory: true)
}
