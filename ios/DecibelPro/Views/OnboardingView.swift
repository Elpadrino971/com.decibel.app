import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: Int = 0

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "waveform",
            iconColors: [Color(red: 0, green: 1, blue: 0.53), Color(red: 0, green: 0.8, blue: 0.4)],
            title: "Mesure précise",
            subtitle: "Mesurez le niveau sonore ambiant en dB(A) avec une précision professionnelle, calibré selon les normes ISO.",
            decorationSymbol: "waveform.path.ecg"
        ),
        OnboardingPage(
            icon: "chart.xyaxis.line",
            iconColors: [Color.orange, Color(red: 1, green: 0.6, blue: 0)],
            title: "Historique complet",
            subtitle: "Enregistrez vos sessions et visualisez l'évolution du bruit avec des graphiques détaillés et des statistiques avancées.",
            decorationSymbol: "chart.bar.fill"
        ),
        OnboardingPage(
            icon: "doc.richtext.fill",
            iconColors: [Color(red: 0.4, green: 0.6, blue: 1), Color(red: 0.3, green: 0.4, blue: 0.9)],
            title: "Rapports PDF",
            subtitle: "Générez des rapports professionnels conformes aux normes françaises, prêts pour les dossiers juridiques ou techniques.",
            decorationSymbol: "doc.on.doc.fill"
        ),
    ]

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.05)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentPage)

                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [page.iconColors[0].opacity(0.12), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)

                Circle()
                    .stroke(page.iconColors[0].opacity(0.08), lineWidth: 1)
                    .frame(width: 200, height: 200)

                Circle()
                    .stroke(page.iconColors[0].opacity(0.04), lineWidth: 1)
                    .frame(width: 260, height: 260)

                Image(systemName: page.decorationSymbol)
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundStyle(page.iconColors[0].opacity(0.06))
                    .offset(x: 30, y: -20)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5))
            }

            Spacer()
                .frame(height: 48)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 80)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? accentGreen : .white.opacity(0.15))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPage)
                }
            }

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        currentPage += 1
                    }
                } else {
                    completeOnboarding()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage < pages.count - 1 ? "Suivant" : "Commencer")
                        .font(.headline)
                    if currentPage == pages.count - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(accentGreen)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: accentGreen.opacity(0.3), radius: 16, y: 6)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: currentPage)

            if currentPage < pages.count - 1 {
                Button {
                    completeOnboarding()
                } label: {
                    Text("Passer")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    let decorationSymbol: String
}
