//
//  SideMenuView.swift
//  ChatBot
//
//  Created by Simra Syed on 26/09/2025.
//

import SwiftUI

enum MenuItem: String {
    case chatWithAI = "Chat With AI"
    case aiTools = "AI Tools"
    case settings = "Setting"
}

struct SideMenu: View {
    
    @Binding var selected: MenuItem?
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .center, spacing: 2){
                Image("logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                
                Text("Chatbot")
                    .font(.headline)
            }
            
            menuButton(title: "Chat With AI", systemImage: "chatwithai", item: .chatWithAI)
            menuButton(title: "Core AI", systemImage: "coreai", item: .aiTools)
            
            Spacer()
            
            Button(action: {
                // subscriptiiion
                
            }) {
                Label("Upgrade Pro", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(Color("PrimaryColor"))
                    .cornerRadius(20)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Setting", systemImage: "gear")
                Label("Support", systemImage: "questionmark.circle")
                Label("Term & Conditions", systemImage: "doc.plaintext")
                Label("Privacy", systemImage: "lock.shield")
            }
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 220, alignment: .topLeading)
        .background(Color("BgColor"))
    }
    
    private func menuButton(title: String, systemImage: String, item: MenuItem) -> some View {
        Button(action: {
            selected = item
        }) {
            Label(title, image: systemImage)
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selected == item ? Color.black : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
