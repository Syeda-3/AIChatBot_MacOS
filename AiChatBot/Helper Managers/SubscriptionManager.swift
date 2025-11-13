//
//  Untitled.swift
//  AiChatBot
//
//  Created by Simra Syed on 17/10/2025.
//

import SwiftUI
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    
    static let shared = SubscriptionManager()
    
    @Published var subscriptions: [Product] = []
    @Published var currentPlan: Product?
    @Published var isLoading = false
    
    @Published var userRegion: String = "Unknown"
    @Published var userCurrency: String = "Unknown"
    @Published var showSubscription: Bool = false

    var hasActivePlan = false

    let productIDs = ["AI.Chatbot.weekly.subscription.mac.app",
                      "AI.Chatbot.monthly.subscription.mac.app",
                      "AI.Chatbot.yearly.subscription.mac.app",
                      "AI.Chatbot.lifetime.subscription.mac.app"]
    
    private init() {
        listenForTransactions()
    }
    
    
    // MARK: - Detect Region (App Store or Device)
    func detectRegion() async {
        // Try Storefront (Apple ID region)
        if let storefront = try? await Storefront.current {
            userRegion = storefront.countryCode
            print("📍 Storefront Region:", userRegion)
        }
        
        // Fallback: Device locale region
        if userRegion == "Unknown",
           let region = Locale.current.region?.identifier {
            userRegion = region
            print("📍 Fallback Device Region:", region)
        }
        
        // Currency
        userCurrency = Locale.current.currency?.identifier ?? "USD"
        print("💰 Currency:", userCurrency)
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetched = try await Product.products(for: productIDs)
            subscriptions = fetched.sorted(by: { $0.price < $1.price })
//            print(fetched[0].priceFormatStyle.locale.currencySymbol)
            print("✅ Loaded \(subscriptions.count) products")
            for product in subscriptions {
                print("→ \(product.displayName): \(product.displayPrice)")
            }
            self.loadCachedPlan()
        } catch {
            print("❌ Failed to load products:", error)
        }
    }
    
    // MARK: - Purchase
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? checkVerified(verification) {
                    await transaction.finish()
                    await updatePurchasedProducts()
                }
            default:
                break
            }
        } catch {
            ToastManager.shared.show(error.localizedDescription)
            print("❌ Purchase failed:", error)
        }
    }
    
    // MARK: - Listen for Live Updates
    private func listenForTransactions() {
        Task {
            for await result in Transaction.updates {
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }
    
    // MARK: - Verify + Update Purchased
    func updatePurchasedProducts() async {
        var purchased: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               let product = subscriptions.first(where: { $0.id == transaction.productID }) {
                purchased.append(product)
            }
        }
        
        if let active = purchased.first {
            currentPlan = active
            hasActivePlan = true
            showSubscription = false
            print("✅ Active subscription:", active.displayName)
        }
        else {
            currentPlan = nil
            print("🚫 No active subscriptions found.")
            clearCachedPlan()
        }
        saveCurrentPlan()
    }
    
    // MARK: - Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Cache
    private func saveCurrentPlan() {
        if let id = currentPlan?.id {
            UserDefaults.standard.set(id, forKey: "activePlanID")
            hasActivePlan = true
        }
        else {
            UserDefaults.standard.removeObject(forKey: "activePlanID")
            hasActivePlan = false
        }
    }
    
    func loadCachedPlan() {
        guard let cachedID = UserDefaults.standard.string(forKey: "activePlanID"),
              let product = subscriptions.first(where: { $0.id == cachedID }) else { return }
        currentPlan = product
        hasActivePlan = true
        
    }
    
    func clearCachedPlan() {
        UserDefaults.standard.removeObject(forKey: "activePlanID")
        currentPlan = nil
        hasActivePlan = false
    }
}

enum StoreKitError: Error {
    case verificationFailed
}
