import Foundation
import StoreKit
import Combine // To naprawi błąd ObservableObject i @Published

@MainActor
class CoffeeStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    
    // ZMIEŃ TE IDENTYFIKATORY na takie, jakie ustawisz w App Store Connect
    private let productIds = ["com.cardiary.xenergi.kawa_mala", "com.cardiary.xenergi.kawa_duza"]
    
    init() {
        Task {
            await fetchProducts()
        }
    }
    
    func fetchProducts() async {
        do {
            // Pobieranie produktów z serwerów Apple
            let storeProducts = try await Product.products(for: productIds)
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Błąd StoreKit: \(error)")
        }
    }
    
    func buy(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
