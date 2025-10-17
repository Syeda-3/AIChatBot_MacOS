//
//  SubscriptionView.swift
//  AiChatBot
//
//  Created by Simra Syed on 13/10/2025.
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan = .monthly
    
    @StateObject private var store = SubscriptionManager.shared

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(.gray)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    highlights
                    plans
                    cta
                    footer
                }
                .padding()
                .frame(maxWidth: 800)
                .padding(.top, 40)
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gray)
                    .padding(12)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(radius: 2)
                    .padding()
            }
        }
        .task {
            await store.fetchProducts()
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 6) {
            Text("Powered By")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("ChatGPT API")
                .font(.largeTitle)
                .fontWeight(.bold)
            Label("Powered By OpenAI", systemImage: "bolt.fill")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private var highlights: some View {
        VStack(spacing: 4) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("• Unlimited usage for one month")
                    Text("• Enjoy the Ad-Free experience")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("• Powered by GPT-4O & GPT-5")
                    Text("• 99% Up-Time Guaranteed")
                }
            }
            .font(.footnote)
            .foregroundColor(.gray)
        }
    }

    private var plans: some View {
        HStack(spacing: 16) {
            ForEach(Plan.allCases, id: \.self) { plan in
                PlanCard(plan: plan, isSelected: selectedPlan == plan)
                    .onTapGesture { selectedPlan = plan }
            }
        }
        .padding(.horizontal)
    }

    private var cta: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if let product = store.subscriptions.first(where: { $0.id == selectedPlan.productID }) {
                        await store.purchase(product)
                    } else {
                        print("⚠️ Product not found for \(selectedPlan.productID)")
                    }
                }
            } label: {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSelectedActive ? Color.gray : Color.green)
                    .cornerRadius(12)
            }
            .disabled(isSelectedActive)

            Text(subtitleText)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("After the 3-day free trial period, the subscription will automatically renew unless the user disables auto-renewal at least 24 hours before the trial concludes. Upon purchase confirmation, payment will be charged to the user's iTunes account.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button("Privacy Policy") {}
                Button("Restore") {
                    Task { await store.updatePurchasedProducts() }
                }
                Button("Terms of Use") {}
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }

    // MARK: - Computed properties

    private var isSelectedActive: Bool {
        store.currentPlan?.id == selectedPlan.productID
    }

    private var buttonTitle: String {
        isSelectedActive ? "Already Subscribed" : "START 3 DAYS FREE TRIAL"
    }

    private var subtitleText: String {
        switch selectedPlan {
        case .weekly: return "$7.99 per week"
        case .monthly: return "3 Days Free Trial, $14.99 per Month"
        case .yearly: return "$69.99 per Year"
        case .lifetime: return "Lifetime Access for $159.99"
        }
    }
}

// MARK: - Plan Enum

enum Plan: String, CaseIterable {
    case weekly, monthly, yearly, lifetime

    var title: String {
        switch self {
        case .weekly: return "WEEKLY"
        case .monthly: return "MONTHLY"
        case .yearly: return "YEARLY"
        case .lifetime: return "LIFE TIME"
        }
    }

    var productID: String {
        switch self {
        case .weekly: return "AI.Chatbot.weekly.subscription.mac.app"
        case .monthly: return "AI.Chatbot.monthly.subscription.mac.app"
        case .yearly: return "AI.Chatbot.yearly.subscription.mac.app"
        case .lifetime: return "AI.Chatbot.lifetime.subscription.mac.app"
        }
    }

    var price: String {
        switch self {
        case .weekly: return "$7.99"
        case .monthly: return "$14.99"
        case .yearly: return "$69.99"
        case .lifetime: return "$159.99"
        }
    }

    var oldPrice: String? {
        self == .lifetime ? "$319.98" : nil
    }

    var tag: String? {
        switch self {
        case .weekly: return "Popular"
        case .monthly: return "56% SAVE"
        case .yearly: return "83% SAVE"
        case .lifetime: return "50% OFF"
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: Plan
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
            }

            Text(plan.title)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)

            if plan == .lifetime {
                HStack(spacing: 4) {
                    Text("Was \(plan.oldPrice ?? "")")
                        .foregroundColor(.red)
                        .strikethrough()
                    Text("Now \(plan.price)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                .font(.footnote)
            } else {
                Text(plan.price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .black)
            }

            if let tag = plan.tag {
                Text(tag)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white : .gray)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isSelected ? Color.white.opacity(0.15) : Color.gray.opacity(0.1))
                    )
            }
        }
        .padding()
        .frame(width: 150, height: 180)
        .background(isSelected ? Color.black : Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
}
