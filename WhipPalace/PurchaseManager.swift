import Foundation
import StoreKit
import Combine

enum PurchaseStatus: Equatable {
    case idle
    case loadingPrice
    case unavailable
    case purchasing
    case pending
    case restoring
}

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isOwned = false
    @Published private(set) var product: Product?
    @Published private(set) var status: PurchaseStatus = .loadingPrice
    @Published private(set) var pendingPackPresentation = false
    @Published var bannerMessage: String?
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var intentsTask: Task<Void, Never>?
    private var storeObserver: StorePaymentObserver?

    var localizedPriceText: String? {
        product?.displayPrice
    }

    func start() {
        registerStoreObserverIfNeeded()
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(transaction: update)
                }
            }
        }
        if intentsTask == nil {
            intentsTask = Task { [weak self] in
                await self?.listenForPurchaseIntents()
            }
        }
        Task { await refreshEntitlements() }
        Task { await loadProduct() }
    }

    func loadProduct() async {
        let busy = status == .purchasing || status == .restoring || status == .pending
        if !busy {
            status = .loadingPrice
            errorMessage = nil
        }
        do {
            let products = try await Product.products(for: [PurchaseConfig.royalWhipPackProductID])
            if let loaded = products.first {
                product = loaded
            }
            if !busy {
                status = product == nil ? .unavailable : .idle
                if product == nil {
                    errorMessage = "The purchase is currently unavailable."
                }
            }
        } catch {
            if !busy {
                status = product == nil ? .unavailable : .idle
                if product == nil {
                    errorMessage = "The purchase is currently unavailable."
                }
            }
        }
        await refreshEntitlements()
        await syncPromotionVisibility()
    }

    func purchase() async {
        await purchase(using: product)
    }

    func restore() async {
        guard status != .purchasing else { return }
        status = .restoring
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            await syncPromotionVisibility()
            if isOwned {
                bannerMessage = "Purchase Restored"
            } else {
                bannerMessage = "No Purchase Found"
            }
            status = .idle
        } catch {
            status = .idle
            bannerMessage = "Purchase Failed"
            errorMessage = "Please try again."
        }
    }

    func acknowledgePackPresentation() {
        pendingPackPresentation = false
    }

    func refreshEntitlements() async {
        var owned = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == PurchaseConfig.royalWhipPackProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isOwned = owned
    }

    func handlePromotedStoreProduct(id: String) async {
        guard id == PurchaseConfig.royalWhipPackProductID else { return }
        pendingPackPresentation = true
        if product == nil {
            await loadProduct()
        }
        if status == .unavailable || status == .loadingPrice, product != nil {
            status = .idle
            errorMessage = nil
        }
        await purchase(using: product)
    }

    private func purchase(using product: Product?) async {
        guard let product, status != .purchasing, status != .restoring else { return }
        status = .purchasing
        errorMessage = nil
        bannerMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(transaction: verification)
                status = .idle
            case .userCancelled:
                status = .idle
            case .pending:
                status = .pending
                bannerMessage = "Purchase pending approval."
            @unknown default:
                status = .idle
                bannerMessage = "Purchase Failed"
                errorMessage = "Please try again."
            }
        } catch {
            status = .idle
            bannerMessage = "Purchase Failed"
            errorMessage = "Please try again."
        }
        await syncPromotionVisibility()
    }

    private func listenForPurchaseIntents() async {
        for await purchaseIntent in PurchaseIntent.intents {
            let intentProduct = purchaseIntent.product
            guard intentProduct.id == PurchaseConfig.royalWhipPackProductID else { continue }
            product = intentProduct
            pendingPackPresentation = true
            if status == .unavailable || status == .loadingPrice {
                status = .idle
                errorMessage = nil
            }
            await purchase(using: intentProduct)
        }
    }

    private func handle(transaction verification: VerificationResult<Transaction>) async {
        switch verification {
        case .unverified:
            bannerMessage = "The purchase could not be verified."
            errorMessage = nil
        case .verified(let transaction):
            if transaction.productID == PurchaseConfig.royalWhipPackProductID {
                if transaction.revocationDate != nil {
                    isOwned = false
                } else {
                    isOwned = true
                    if status == .purchasing || status == .pending {
                        bannerMessage = "Royal Whip Pack Unlocked"
                    }
                }
                await transaction.finish()
            }
        }
        await refreshEntitlements()
        await syncPromotionVisibility()
    }

    private func syncPromotionVisibility() async {
        let visibility: Product.PromotionInfo.Visibility = isOwned ? .hidden : .appStoreConnectDefault
        do {
            try await Product.PromotionInfo.updateProductVisibility(
                visibility,
                for: PurchaseConfig.royalWhipPackProductID
            )
        } catch {
            // Simulator and StoreKit Testing may not accept promotion updates.
        }
    }

    private func registerStoreObserverIfNeeded() {
        guard storeObserver == nil else { return }
        let observer = StorePaymentObserver()
        observer.owner = self
        storeObserver = observer
        SKPaymentQueue.default().add(observer)
    }
}

private final class StorePaymentObserver: NSObject, SKPaymentTransactionObserver {
    weak var owner: PurchaseManager?

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        // StoreKit 2 Transaction.updates is the source of truth.
    }

    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        let productID = payment.productIdentifier
        Task { @MainActor [weak owner] in
            await owner?.handlePromotedStoreProduct(id: productID)
        }
        return false
    }
}
