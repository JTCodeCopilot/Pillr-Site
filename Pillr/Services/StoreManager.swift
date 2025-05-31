import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    private let productIdentifier = "com.pillr.app.premium"
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published var isLoading = false
    
    private var productsLoaded = false
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Load products from the App Store
    func loadProducts() async {
        guard !productsLoaded else { return }
        
        isLoading = true
        
        do {
            let storeProducts = try await Product.products(for: [productIdentifier])
            DispatchQueue.main.async { [weak self] in
                self?.products = storeProducts
                self?.productsLoaded = true
                self?.isLoading = false
            }
        } catch {
            print("Failed to load products: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
    }
    
    // Listen for transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Update the list of purchased product IDs
                    await self.updatePurchasedProducts()
                    
                    // Always finish the transaction
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // Update purchased products
    @MainActor
    func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()
        
        // Check for previous purchases
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
        
        // Update UserSettings
        if !purchasedIDs.isEmpty {
            // If the user has purchased premium, update the UserSettings
            OpenAIService.shared.setPremiumPurchased()
        }
    }
    
    // Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try await checkVerified(verification)
                await updatePurchasedProducts()
                isLoading = false
                return transaction
                
            case .userCancelled:
                isLoading = false
                return nil
                
            case .pending:
                isLoading = false
                return nil
                
            default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            throw error
        }
    }
    
    // Restore purchases
    func restorePurchases() async throws {
        isLoading = true
        
        // Request a refresh of the app receipt
        try? await AppStore.sync()
        
        // Update purchased products
        await updatePurchasedProducts()
        
        isLoading = false
    }
    
    // Helper method to verify a transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // Check if the user has purchased premium
    func isPremiumPurchased() -> Bool {
        return !purchasedProductIDs.isEmpty
    }
    
    // Get premium product
    func getPremiumProduct() -> Product? {
        return products.first(where: { $0.id == productIdentifier })
    }
}

enum StoreError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .failedVerification:
            return "Failed to verify purchase"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
} 