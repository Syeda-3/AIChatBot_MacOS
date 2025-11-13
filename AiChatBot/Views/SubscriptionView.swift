//
//  SubscriptionView.swift
//  AiChatBot
//
//  Created by Simra Syed on 13/10/2025.
//

import SwiftUI
import StoreKit
import Combine

struct SubscriptionView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: Plan? = .monthly
    @StateObject private var store = SubscriptionManager.shared
    
    // MARK: - Computed
    private var isSelectedActive: Bool {
        store.currentPlan?.id == selectedPlan?.productID
    }

    private var buttonTitle: String {
        isSelectedActive ? "Already Subscribed" : "CONTINUE"
    }

    private var subtitleText: String {
        if let product = store.subscriptions.first(where: { $0.id == selectedPlan?.productID }) {
            return product.displayPrice
        } else {
            return ""
        }
    }
    
    init(showSubscription: Binding<Bool>) {
           if let savedID = UserDefaults.standard.string(forKey: "activePlanID"),
              let plan = Plan.allCases.first(where: { $0.productID == savedID }) {
               _selectedPlan = State(initialValue: plan)
           }
       }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {

            Color("BgColor").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                        header
                        highlights
                        plans
                        cta
                        footer
                    }
                    .padding()
                    .frame(maxWidth: 800)
                    .padding(.top, 60)
                }

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("TextColor"))
                    .padding(10)
                    .padding()
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            Task {
                await SubscriptionManager.shared.loadProducts()
            }
        }
        .onChange(of: selectedPlan) { newValue in
            UserDefaults.standard.set(newValue?.productID, forKey: "activePlanID")
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text("Powered By")
                .font(.custom("Inter-Medium", size: 25))
                .foregroundColor(Color("TextColor"))
            Text("ChatGPT API")
                .font(.custom("Inter-Bold", size: 55))
                .foregroundColor(Color("TextColor"))
            HStack {
                Text("Powered By")
                    .font(.custom("Inter-Medium", size: 28)) 
                    .foregroundColor(Color("TextColor"))

                Image("chat-gpt")
                    .foregroundColor(Color("TextColor"))
                Text("OpenAI")
                    .font(.custom("Inter-Medium", size: 28)) // or .system(size: 16, weight: .semibold)
                    .foregroundColor(Color("TextColor"))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("TextColor"), lineWidth: 1.5)
            )
            .padding(.top, 8)
        }
    }

    // MARK: - Highlights
    private var highlights: some View {
        VStack(spacing: 10) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Unlimited usage")
                    Text("• Enjoy the Ad-Free experience")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Powered by GPT-4O & GPT-5")
                    Text("• 99% Up-Time Guaranteed")
                }
            }
            .font(.custom("Inter-Medium", size: 16))
            .foregroundColor(Color("TextColor"))
            .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Plans

    private var plans: some View {
        HStack(spacing: 20) {
            ForEach(Plan.allCases, id: \.self) { plan in
                // Try to match this plan with a fetched StoreKit product
                let product = store.subscriptions.first { $0.id == plan.productID }

                PlanCard(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    displayPrice: product?.displayPrice ?? "—"
                )
                .onTapGesture {
                    selectedPlan = plan
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: store.currentPlan) { newValue in
            if let productID = newValue?.id {
                selectedPlan = Plan.allCases.first { $0.productID == productID }
            } else {
                selectedPlan = nil
            }
        }
    }

    // MARK: - CTA
    private var cta: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Secured by Apple, Cancel anytime.")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)

            Button {
                Task {
                    if let product = store.subscriptions.first(where: { $0.id == selectedPlan?.productID }) {
                        await store.purchase(product)
                    }
                    else {
                        print("⚠️ Product not found for \(selectedPlan?.productID ?? "")")
                    }
                }
            } label: {
                Text( selectedPlan == .monthly ? "Avail 3 days free trial" : buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("PrimaryColor"))
                    .cornerRadius(30)
                    .foregroundColor(.black)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 80)
            .disabled(isSelectedActive)

        }
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 8) {
            Text("After the 3-day free trial period, the subscription will automatically renew unless canceled at least 24 hours before renewal. Payment will be charged to your iTunes account upon confirmation of purchase.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 24) {
                Button("Privacy Policy") {}
                    .buttonStyle(.plain)
                Button("Restore") {
                    Task {
                        await store.updatePurchasedProducts()
                    }
                }
                .buttonStyle(.plain)
                Button("Terms of Use") {}
                    .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundColor(.blue)
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
        case .lifetime: return "LIFETIME"
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

    var tag: String? {
        switch self {
        case .weekly: return "Basic"
        case .monthly: return "Popular"
        case .yearly: return "Big save"
        case .lifetime: return "Mega save"
        }
    }
}

// MARK: - PlanCard

struct PlanCard: View {
    
    let plan: Plan
    let isSelected: Bool
    let displayPrice: String?
    
    var body: some View {
        let backgroundColor = isSelected ? Color.white : Color.black
        let borderColor = isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.3)
        let textColor = isSelected ? Color.black : Color.white
        
        VStack(spacing: 14) {
            // MARK: - Checkmark
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor)
                Spacer()
            }
            
            // MARK: - Title
            Text(plan.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // MARK: - Price
            if let price = displayPrice {
                Text(price)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.top, 8)
            }
            
            // MARK: - Divider
            Rectangle()
                .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))
                .frame(height: 1)
                .padding(.top, 6)
            
            // MARK: - Tag
            if let tag = plan.tag {
                Text(tag)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color("capsuleop") : Color("capsule"))
                    )
                    .padding(.top, 4)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 160, height: 190)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color("TextColor") : Color("TextColorOp"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

