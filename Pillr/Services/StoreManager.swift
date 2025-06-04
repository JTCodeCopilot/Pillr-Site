import StoreKit
import SwiftUI

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()
    
    // Product identifiers
    private let premiumIdentifier = "com.pillr.ai"
    
    // All product identifiers
    private var productIdentifiers: [String] {
        return [premiumIdentifier]
    }
    
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published var isLoading = false
    
    // Flag to disable StoreKit for testing
    private let isTestMode = false
    
    private var productsLoaded = false
    private var updateListenerTask: Task<Void, Error>?
    
    // Static method to create a preview manager
    static func previewManager() -> StoreManager {
        let manager = StoreManager()
        manager.isLoading = false
        return manager
    }
    
    init() {
        if isTestMode {
            // In test mode, skip StoreKit initialization and set premium to true
            Task {
                await setTestModePremium()
            }
        } else {
            updateListenerTask = listenForTransactions()
            Task {
                await loadProducts()
                await updatePurchasedProducts()
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Set premium status in test mode
    private func setTestModePremium() async {
        // Set premium status for testing
        purchasedProductIDs.insert(premiumIdentifier)
        OpenAIService.shared.setPremiumPurchased()
        print("TEST MODE: Premium features enabled for testing")
    }
    
    // Load products from the App Store
    func loadProducts() async {
        if isTestMode {
            print("TEST MODE: Skipping App Store product loading")
            return
        }
        
        guard !productsLoaded else { return }
        
        isLoading = true
        
        do {
            let storeProducts = try await Product.products(for: productIdentifiers)
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
        if isTestMode {
            print("TEST MODE: Skipping purchased products update")
            return
        }
        
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
        if purchasedIDs.contains(premiumIdentifier) {
            // If the user has purchased premium, update the UserSettings
            OpenAIService.shared.setPremiumPurchased()
        }
    }
    
    // Purchase a product
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        if isTestMode {
            print("TEST MODE: Simulating successful purchase")
            await setTestModePremium()
            return nil
        }
        
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
        if isTestMode {
            print("TEST MODE: Simulating successful restore")
            await setTestModePremium()
            return
        }
        
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
        if isTestMode {
            return true
        }
        return purchasedProductIDs.contains(premiumIdentifier)
    }
    
    // Get premium product
    func getPremiumProduct() -> Product? {
        if isTestMode {
            print("TEST MODE: No actual product available in test mode")
            return nil
        }
        return products.first(where: { $0.id == premiumIdentifier })
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

// MARK: - StoreKit Product Extension
extension Product {
    /// Returns the price formatted according to the locale of the App Store the product was loaded from.
    /// This ensures the price is displayed in the correct format for the user's current region.
    var localizedDisplayPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceFormatStyle.locale
        return formatter.string(from: price as NSNumber) ?? displayPrice
    }
} 
