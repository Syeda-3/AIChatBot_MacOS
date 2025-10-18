//
//  Untitled.swift
//  AiChatBot
//
//  Created by Simra Syed on 17/10/2025.
//

import SwiftUI
import StoreKit
import Combine

import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var subscriptions: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var currentPlan: Product?

    init() {
        // Start listening immediately when the app launches
        listenForTransactions()
    }

    // MARK: - Listen for transaction updates
    private func listenForTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    if let transaction = try? await self.checkVerified(result) {
                        // Update UI and entitlements on main actor
                        await transaction.finish()
                        await MainActor.run {
                            Task {
                                await self.updatePurchasedProducts()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fetch products
    func fetchProducts() async {
        do {
            let productIDs = [
                "AI.Chatbot.weekly.subscription.mac.app",
                "AI.Chatbot.monthly.subscription.mac.app",
                "AI.Chatbot.yearly.subscription.mac.app",
                "AI.Chatbot.lifetime.subscription.mac.app"
            ]

            subscriptions = try await Product.products(for: productIDs)
            loadCachedPlan()
            await updatePurchasedProducts()
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = try? self.checkVerified(verification) {
                    await transaction.finish()
                    await updatePurchasedProducts()
                }
            default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }

    // MARK: - Check purchased
    func updatePurchasedProducts() async {
        var purchased: [Product] = []

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               let product = subscriptions.first(where: { $0.id == transaction.productID }) {
                purchased.append(product)
            }
        }

        purchasedSubscriptions = purchased
        currentPlan = purchased.first
        saveCurrentPlan()
    }

    // MARK: - Verify
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
        } else {
            UserDefaults.standard.removeObject(forKey: "activePlanID")
        }
    }

    private func loadCachedPlan() {
        guard let cachedID = UserDefaults.standard.string(forKey: "activePlanID"),
              let product = subscriptions.first(where: { $0.id == cachedID }) else { return }
        currentPlan = product
    }
}

enum StoreKitError: Error {
    case verificationFailed
}
                                                               
