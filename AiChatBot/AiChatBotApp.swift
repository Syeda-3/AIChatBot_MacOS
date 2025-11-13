//
//  AiChatBotApp.swift
//  AiChatBot
//
//  Created by Simra Syed on 03/10/2025.
//

import SwiftUI
import CoreData

@main
struct AiChatBotApp: App {
    let persistenceController = PersistenceController.shared

    @StateObject private var convoManager = ConversationManager(
        context: PersistenceController.shared.container.viewContext
    )

    var body: some Scene {
        WindowGroup {
            MainContainer()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(convoManager)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.setFrame(NSScreen.main?.visibleFrame ?? .zero, display: true)
                    }
                }
                .task {
                    let subManager = SubscriptionManager.shared
                    await subManager.detectRegion()
                    subManager.loadCachedPlan()
                    await subManager.loadProducts()
                    await subManager.updatePurchasedProducts()
                }
        }
    }
}
