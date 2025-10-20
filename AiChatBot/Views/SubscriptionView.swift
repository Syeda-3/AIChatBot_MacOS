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
    @State private var selectedPlan: Plan? = .weekly
    @StateObject private var store = SubscriptionManager.shared

    // Custom initializer
    init() {
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
        .task {
            await store.fetchProducts()
        }
        .onChange(of: selectedPlan) { newValue in
            UserDefaults.standard.set(newValue?.productID, forKey: "activePlanID")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("Powered By")
                .font(.subheadline)
                .foregroundColor(Color("TextColor"))
            Text("ChatGPT API")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color("TextColor"))
            Label("Powered By OpenAI", systemImage: "bolt.fill")
                .font(.subheadline)
                .foregroundColor(Color("TextColor"))
        }
    }

    // MARK: - Highlights

    private var highlights: some View {
        VStack(spacing: 10) {
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Unlimited usage for one month")
                    Text("• Enjoy the Ad-Free experience")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Powered by GPT-4O & GPT-5")
                    Text("• 99% Up-Time Guaranteed")
                }
            }
            .font(.footnote)
            .foregroundColor(Color("TextColor"))
            .multilineTextAlignment(.leading)
        }
    }

    // MARK: - Plans

    private var plans: some View {
        HStack(spacing: 20) {
            ForEach(Plan.allCases, id: \.self) { plan in
                PlanCard(plan: plan, isSelected: selectedPlan == plan)
                    .onTapGesture { selectedPlan = plan }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - CTA

    private var cta: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    if let product = store.subscriptions.first(where: { $0.id == selectedPlan?.productID }) {
                        await store.purchase(product)
                    }
                    else {
                        print("⚠️ Product not found for \(selectedPlan?.productID)")
                    }
                }
            } label: {
                Text(buttonTitle)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isSelectedActive ? Color.gray.opacity(0.4) : Color.green)
                    .cornerRadius(30)
                    .foregroundColor(.black)
                    .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 80)
            .disabled(isSelectedActive)

            Text(subtitleText)
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            Text("After the 3-day free trial period, the subscription will automatically renew unless canceled at least 24 hours before the trial concludes. Upon purchase confirmation, payment will be charged to the user's iTunes account.")
                .font(.caption2)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 24) {
                Button("Privacy Policy") {
                    
                }
                .buttonStyle(.plain)
                Button("Restore") {
                    Task {        try? await AppStore.sync()
                        await store.updatePurchasedProducts()
                        }
                }
                .buttonStyle(.plain)
                Button("Terms of Use") {
                    
                }
                .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
    }

    // MARK: - Computed properties

    private var isSelectedActive: Bool {
        store.currentPlan?.id == selectedPlan?.productID
    }

    private var buttonTitle: String {
        isSelectedActive ? "Already Subscribed" : "CONTINUE"
    }

    private var subtitleText: String {
        switch selectedPlan {
        case .weekly: return "$7.99 per Week"
        case .monthly: return "3 Days Free Trial, $14.99 per Month"
        case .yearly: return "$69.99 per Year"
        case .lifetime: return "Lifetime Access for $159.99"
        case .none:
            return "no plan"
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
        VStack(spacing: 12) {
            HStack {
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                }
            }

            Text(plan.title)
                .font(.headline)
                .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))

            if plan == .lifetime {
                HStack(spacing: 6) {
                    Text("Was \(plan.oldPrice ?? "")")
                        .foregroundColor(.red)
                        .strikethrough()
                    Text("Now \(plan.price)")
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
                .font(.footnote)
            }
            else {
                Text(plan.price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? Color("TextColorOp") : Color("TextColor"))
            }

            if let tag = plan.tag {
                Text(tag)
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                    )
            }
        }
        .padding()
        .frame(width: 160, height: 190)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color("TextColor") : Color("TextColorOp"))
        )
        
//        .overlay(
//            RoundedRectangle(cornerRadius: 16)
//                .stroke(isSelected ? Color("TextColor") : Color("TextColorOp"), lineWidth: 1)
//        )
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
}
