import SwiftUI
import StoreKit

struct PaywallView: View {
    let storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing: Bool = false
    @State private var selectedProduct: String = StoreManager.proProductID
    @State private var showRestoreSuccess: Bool = false
    @State private var animateIn: Bool = false

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView {
                    VStack(spacing: 0) {
                        heroSection
                            .padding(.bottom, 28)

                        comparisonTable
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)

                        productsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)

                        purchaseButton
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        freeOption
                            .padding(.bottom, 8)

                        restoreButton
                            .padding(.bottom, 40)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .task {
                await storeManager.loadProducts()
                withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                    animateIn = true
                }
            }
            .overlay {
                if showRestoreSuccess {
                    restoreSuccessBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.05)
            
            Circle()
                .fill(accentGreen.opacity(0.06))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(y: -200)

            Circle()
                .fill(Color.blue.opacity(0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 100, y: 300)
        }
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.08))
                    .frame(width: 100, height: 100)
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .opacity(animateIn ? 1 : 0)

                Circle()
                    .stroke(accentGreen.opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateIn ? 1 : 0.3)
                    .opacity(animateIn ? 1 : 0)

                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(accentGreen)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
                    .scaleEffect(animateIn ? 1 : 0.6)
                    .opacity(animateIn ? 1 : 0)
            }
            .padding(.top, 20)

            VStack(spacing: 8) {
                Text("DecibelPro")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Passez au niveau professionnel")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 10)
        }
    }

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fonctionnalité")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Gratuit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 60)
                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentGreen)
                    .frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().background(.white.opacity(0.08))

            comparisonRow(feature: "Sonomètre temps réel", free: .unlimited, pro: .unlimited)
            comparisonRow(feature: "Historique", free: .limited("5"), pro: .unlimited)
            comparisonRow(feature: "Calibration", free: .limited("1"), pro: .unlimited)
            comparisonRow(feature: "Graphiques avancés", free: .locked, pro: .unlimited)
            comparisonRow(feature: "Export PDF", free: .limited("1p"), pro: .unlimited)
            comparisonRow(feature: "Rapport 4 pages", free: .locked, pro: .unlimited)
        }
        .background(Color.white.opacity(0.03))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        )
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 16)
    }

    private func comparisonRow(feature: String, free: FeatureAccess, pro: FeatureAccess) -> some View {
        HStack {
            Text(feature)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            accessBadge(free)
                .frame(width: 60)

            accessBadge(pro)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func accessBadge(_ access: FeatureAccess) -> some View {
        switch access {
        case .unlimited:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(accentGreen)
        case .limited(let text):
            Text(text)
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(.orange)
        case .locked:
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.2))
        }
    }

    private var productsSection: some View {
        VStack(spacing: 10) {
            if storeManager.isLoading {
                ProgressView()
                    .tint(accentGreen)
                    .frame(height: 140)
            } else {
                productOption(
                    id: StoreManager.proProductID,
                    title: "Unlock Complet",
                    subtitle: "Historique illimité · Calibration · Graphiques",
                    price: storeManager.proProduct?.displayPrice ?? "3,99 €",
                    badge: "MEILLEUR CHOIX",
                    isUnlocked: storeManager.isProUnlocked
                )

                productOption(
                    id: StoreManager.pdfProductID,
                    title: "Export PDF Pro",
                    subtitle: "Rapports professionnels 4 pages",
                    price: storeManager.pdfProduct?.displayPrice ?? "1,99 €",
                    badge: nil,
                    isUnlocked: storeManager.isPDFExportUnlocked
                )
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
    }

    private func productOption(
        id: String,
        title: String,
        subtitle: String,
        price: String,
        badge: String?,
        isUnlocked: Bool
    ) -> some View {
        let isSelected = selectedProduct == id && !isUnlocked

        return Button {
            guard !isUnlocked else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedProduct = id
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? accentGreen : .white.opacity(0.15), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(accentGreen)
                            .frame(width: 12, height: 12)
                            .transition(.scale)
                    }
                    if isUnlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(accentGreen)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentGreen)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                if isUnlocked {
                    Text("Débloqué")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentGreen)
                } else {
                    Text(price)
                        .font(.system(.body, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? accentGreen.opacity(0.06) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? accentGreen.opacity(0.4) : .white.opacity(0.06), lineWidth: 1)
            )
        }
        .disabled(isUnlocked)
        .sensoryFeedback(.selection, trigger: selectedProduct)
    }

    private var purchaseButton: some View {
        let allUnlocked = storeManager.isProUnlocked && storeManager.isPDFExportUnlocked
        let currentUnlocked = (selectedProduct == StoreManager.proProductID && storeManager.isProUnlocked) ||
            (selectedProduct == StoreManager.pdfProductID && storeManager.isPDFExportUnlocked)

        return Button {
            guard !currentUnlocked else { return }
            let product: Product?
            if selectedProduct == StoreManager.proProductID {
                product = storeManager.proProduct
            } else {
                product = storeManager.pdfProduct
            }
            guard let product else { return }
            Task {
                isPurchasing = true
                let success = await storeManager.purchase(product)
                isPurchasing = false
                if success { dismiss() }
            }
        } label: {
            HStack(spacing: 10) {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: allUnlocked ? "checkmark.seal.fill" : "lock.open.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(allUnlocked ? "Tout débloqué" : "Acheter maintenant")
                        .font(.headline)
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                allUnlocked ? accentGreen.opacity(0.5) : accentGreen
            )
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: accentGreen.opacity(allUnlocked ? 0 : 0.3), radius: 16, y: 6)
        }
        .disabled(isPurchasing || allUnlocked || currentUnlocked)
        .opacity(animateIn ? 1 : 0)
    }

    private var freeOption: some View {
        Button {
            dismiss()
        } label: {
            Text("Continuer gratuitement")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await storeManager.restorePurchases()
                if storeManager.isProUnlocked || storeManager.isPDFExportUnlocked {
                    withAnimation(.spring(response: 0.4)) {
                        showRestoreSuccess = true
                    }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { showRestoreSuccess = false }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                Text("Restaurer les achats")
                    .font(.footnote.weight(.medium))
            }
            .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var restoreSuccessBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(accentGreen)
            Text("Achats restaurés avec succès")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private enum FeatureAccess {
    case unlimited
    case limited(String)
    case locked
}
