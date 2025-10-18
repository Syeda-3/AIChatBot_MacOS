//
//  Untitled.swift
//  AiChatBot
//
//  Created by Simra Syed on 12/10/2025.
//

import SwiftUI
import Combine

struct FeatureSidebar: View {
    
    @Binding var selectedFeature: CoreAIFeature?
    @Binding var selectedSubFeature: SubFeature?
    @ObservedObject var convoManager: ConversationManager
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Features")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(CoreAIFeature.allCases, id: \.id) { feature in
                        VStack(alignment: .leading, spacing: 6) {
                            FeatureCellView(
                                isSelected: selectedFeature == feature,
                                title: feature.rawValue.capitalized
                            ) {
                                withAnimation(.easeInOut) {
                                    if selectedFeature == feature {
                                    } else {
                                        selectedFeature = feature
                                        selectedSubFeature = nil
                                        convoManager.resetConversation()
                                    }
                                }
                            }
                    }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 250)
        .background(Color("BgColor"))
        .cornerRadius(12)
        .padding(.vertical, 8)
    }
}
