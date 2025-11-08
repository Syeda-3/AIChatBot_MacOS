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

    // 👇 Persistent instance — created once for the lifetime of the app
    @StateObject private var convoManager = ConversationManager(
        context: PersistenceController.shared.container.viewContext
    )

    var body: some Scene {
        WindowGroup {
            MainContainer()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(ConversationManager(context: persistenceController.container.viewContext))
                       .onAppear {
                           // Make window full screen on launch
                           if let window = NSApplication.shared.windows.first {
                               window.setFrame(NSScreen.main?.visibleFrame ?? .zero, display: true)
                           }
                       }
        }
       
        
    }
}
