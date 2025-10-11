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
    
    var body: some Scene {
        WindowGroup {
            MainContainer()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(
                    ConversationManager(context: persistenceController.container.viewContext)
                )
        }
    }
}
