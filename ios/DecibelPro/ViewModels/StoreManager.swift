import StoreKit

nonisolated enum Feature: String, Sendable {
    case unlimitedHistory
    case advancedCalibration
    case charts
    case unlimitedExport
    case fullReport
}

@Observable
@MainActor
final class StoreManager {
    var isProUnlocked: Bool = false
    var isPDFExportUnlocked: Bool = false
    var products: [Product] = []
    var isLoading: Bool = false
    var errorMessage: String?

    static let proProductID = "com.decibelpro.unlock"
    static let pdfProductID = "com.decibelpro.export"

    private let freeHistoryLimit = 5

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        isProUnlocked = UserDefaults.standard.bool(forKey: "proUnlocked")
        isPDFExportUnlocked = UserDefaults.standard.bool(forKey: "pdfExportUnlocked")
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    func isFeatureUnlocked(_ feature: Feature) -> Bool {
        switch feature {
        case .unlimitedHistory, .advancedCalibration, .charts:
            return isProUnlocked
        case .unlimitedExport, .fullReport:
            return isProUnlocked || isPDFExportUnlocked
        }
    }

    func canAccessSession(at index: Int) -> Bool {
        isProUnlocked || index < freeHistoryLimit
    }

    var proProduct: Product? {
        products.first { $0.id == Self.proProductID }
    }

    var pdfProduct: Product? {
        products.first { $0.id == Self.pdfProductID }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: [Self.proProductID, Self.pdfProductID])
            products = storeProducts.sorted { $0.price > $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedState(transaction)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await updatePurchasedState(transaction)
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.updatePurchasedState(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    private func updatePurchasedState(_ transaction: Transaction) async {
        if transaction.productID == Self.proProductID {
            isProUnlocked = true
            UserDefaults.standard.set(true, forKey: "proUnlocked")
        } else if transaction.productID == Self.pdfProductID {
            isPDFExportUnlocked = true
            UserDefaults.standard.set(true, forKey: "pdfExportUnlocked")
        }
    }
}

nonisolated enum StoreError: Error, Sendable {
    case failedVerification
}
