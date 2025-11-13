//
//  MainContainer.swift
//  AiChatBot
//
//  Created by Simra Syed on 03/10/2025.
//

import SwiftUI

struct MainContainer: View {
    @State private var selected: MenuItem? = .chatWithAI
    @State private var showSubscription = false

    var body: some View {
        HStack(spacing: 0) {
            SideMenu(selected: $selected)
                .frame(width: 220)
                .background(Color("BgColor"))
            
            Divider()
            
            switch selected {
            case .chatWithAI:
                ChatWithAIView()
            case .aiTools:
                CoreAIView()
//            case .settings:
//                ChatWithAIView()
            case .none:
                Text("Select a menu")
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(12)
        .padding(.vertical, 8)
        
    }
}
