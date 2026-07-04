import SwiftUI

// MARK: - Corner facts (B17 #7)

/// The Grown-Ups corner's non-copy facts, pulled out of the view so tests can
/// pin them: support endpoints, the App Store review deep link, the app
/// version line.
enum GrownUpsCornerInfo {
    /// The live support page (verified 200 — `product/store-listing/`
    /// records it as the App Store Connect support URL).
    static let supportPageURL = URL(string: "https://www.onurovali.me/ylapiano/support")!

    /// Same address the live support page publishes.
    static let supportEmail = "onurovalii@gmail.com"
    static var supportMailURL: URL {
        URL(string: "mailto:\(supportEmail)?subject=Ylapiano%20support")!
    }

    /// TODO(B17): the numeric App Store "Apple ID" doesn't exist anywhere in
    /// the repo yet (it's minted when the app record is created in App Store
    /// Connect). Until it lands here, `hasRealAppStoreID` is false and the
    /// "Write a review" row stays hidden — the soft `requestReview` path
    /// still works. Replace the zeros with the real ID and the row appears.
    static let appStoreID = "0000000000"
    static var hasRealAppStoreID: Bool { appStoreID.contains { $0 != "0" } }

    /// Direct write-a-review deep link — jumps straight to the App Store's
    /// review sheet, no gatekeeping (unlike the system prompt).
    static var writeReviewURL: URL {
        URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreID)?action=write-review")!
    }

    /// "1.4.10 (10)" — marketing version + build, straight from the bundle.
    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}

// MARK: - The corner (B17 #7)

/// The adult-facing corner behind the home screen's hold gate: how the game
/// works, the USB piano note, the mastery ladder explained, support links,
/// the rating ask (B28's adult-facing half), the CC0 piano credit (B23's
/// attribution promise), and the version footer. Parent-directed register —
/// a kid never reaches this (2.5 s hold), and nothing here is playful chrome.
struct GrownUpsCornerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header — same title/Done chrome as the player's grown-ups drawer.
            HStack {
                Text("Grown-ups")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(.body, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // (a) Setup & help
                    helpSection(
                        icon: "music.note",
                        title: "How it works",
                        body: "Pick a song and press play. Notes fall toward the piano keys, and your child plays each one as it lands — right notes earn up to 3 stars. There is no losing; every finished song ends in a little celebration."
                    )
                    helpSection(
                        icon: "pianokeys",
                        title: "USB piano",
                        body: "Plug a USB MIDI keyboard into the iPad and it connects by itself — the piano-keys icon at the top turns red when it's live. No keyboard around? The on-screen keys work just the same."
                    )
                    helpSection(
                        icon: "chart.bar.fill",
                        title: "The mastery ladder",
                        body: "One song — Plim Plim — climbs a 4-step ladder: each step is a bit faster, the key glow fades, and the timing gets stricter. A 3-star run offers the climb, and your child decides when to take it."
                    )

                    Divider()

                    // (b) Support
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Support")
                        linkRow(
                            destination: GrownUpsCornerInfo.supportPageURL,
                            icon: "questionmark.circle",
                            label: "Get help",
                            identifier: "SupportLinkRow"
                        )
                        linkRow(
                            destination: GrownUpsCornerInfo.supportMailURL,
                            icon: "envelope",
                            label: "Email us",
                            identifier: "SupportEmailRow"
                        )
                    }

                    Divider()

                    // (c) Rating ask — soft system prompt + (once the App
                    // Store ID exists) the direct write-a-review deep link.
                    VStack(alignment: .leading, spacing: 4) {
                        sectionHeader("Rate Ylapiano")
                        Button {
                            ReviewAsk.presentSystemPrompt()
                        } label: {
                            rowLabel(icon: "star", label: "Rate Ylapiano")
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("RateYlapianoRow")

                        if GrownUpsCornerInfo.hasRealAppStoreID {
                            linkRow(
                                destination: GrownUpsCornerInfo.writeReviewURL,
                                icon: "square.and.pencil",
                                label: "Write a review",
                                identifier: "WriteReviewRow"
                            )
                        }

                        Text("Love it? Ratings help other families find Ylapiano.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }

                    Divider()

                    // (d) B23's CC0 piano credit + (e) version footer.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Piano sound: Upright Piano KW, recorded from a real Kawai upright piano by the FreePats project. Released under CC0 — thank you.")
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("PianoCreditLine")

                        Text("Version \(GrownUpsCornerInfo.appVersion)")
                            .font(.system(.footnote, design: .rounded, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .accessibilityIdentifier("VersionFooter")
                    }
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(.body, design: .rounded))
        .foregroundStyle(Palette.ink)
        .background(Palette.cream.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("GrownUpsCorner")
    }

    // MARK: - Pieces

    /// Icon + heading + parent-directed paragraph.
    private func helpSection(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(Palette.coral)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            Text(body)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .padding(.bottom, 4)
    }

    private func linkRow(destination: URL, icon: String, label: LocalizedStringKey, identifier: String) -> some View {
        Link(destination: destination) {
            rowLabel(icon: icon, label: label)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func rowLabel(icon: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(.subheadline, weight: .bold))
                .foregroundStyle(Palette.coral)
                .frame(width: 24)
            Text(label)
                .font(.system(.body, design: .rounded, weight: .semibold))
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    GrownUpsCornerView()
}
