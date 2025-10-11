//
//  ModelView.swift
//  AiChatBot
//
//  Created by Simra Syed on 11/10/2025.
//

import SwiftUI
import Combine

import SwiftUI

class ModelManager: ObservableObject {
    
    @AppStorage("selectedModel")
    var selectedModel: String = "Chatbot 4.o" 
    static let shared = ModelManager()
    
    private let modelMapping: [String: String] = [
        "Chatbot 3.5": "gpt-3.5-turbo",
        "Chatbot 4.o": "gpt-4",
        "Chatbot 4.5": "gpt-4.5",
        "Chatbot 5.o": "gpt-5-mini"
    ]
    
    var selectedModelAPIName: String {
        modelMapping[selectedModel] ?? "gpt-4"
    }
}

struct ModelSelectorView: View {
    @ObservedObject var modelManager = ModelManager.shared
    
    let models = ["Chatbot 3.5", "Chatbot 4.o", "Chatbot 4.5", "Chatbot 5.o"]
    
    var body: some View {
        HStack(spacing: 10) {
            Text(modelManager.selectedModel)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Menu {
                ForEach(models, id: \.self) { model in
                    Button {
                        modelManager.selectedModel = model
                    } label: {
                        HStack {
                            Text(model)
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.vertical, 4)
                    }
                }
            } label: {
            }
            .frame(width: 15)
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.darkGray).opacity(0.5))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }
}
