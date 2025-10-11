//
//  CoreAiView.swift
//  AiChatBot
//
//  Created by Simra Syed on 03/10/2025.
//

import SwiftUI
import Combine

struct CoreAIView: View {
    
    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 145
    @State private var isGenerating = false
    @State private var selectedFeature: CoreAIFeature = .summarization
    
    @EnvironmentObject var convoManager: ConversationManager
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                Spacer()
                // Sidebar
                VStack(spacing: 0) {
                    Text("Features")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(CoreAIFeature.allCases) { feature in
                                FeatureCellView(
                                    isSelected: selectedFeature == feature,
                                    title: feature.rawValue
                                ) {
                                    selectedFeature = feature
                                    convoManager.resetConversation()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(width: 250)
                .background(Color("BgColor"))
                .cornerRadius(12)
                .padding(.vertical, 8)
                
                VStack {
                HStack {
                    Spacer()
                    ModelSelectorView()
                        .frame(width: 200)
                        .padding(.trailing, 16)
                        .padding(.vertical,8)
                }
                    if convoManager.activeConversation == nil {
                        // Welcome screen
                        VStack(alignment: .center){
                            Spacer()
                            Image("greencircle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                            
                            Text(selectedFeature.rawValue)
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            Text(selectedFeature.description)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            messageBox
                                .frame(height: editorHeight)
                                .padding(.horizontal, 60)
                                .onChange(of: inputText) { _ in
                                    recalcHeight()
                                }
                            
                            Spacer()
                        }
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding(.bottom, 8)
                        .padding(.horizontal)
                    }
                    else {
                        Spacer()
                        // Messages area
                        VStack {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(convoManager.activeConversation?.messagesArray ?? [], id: \.id) { msg in
                                            HStack {
                                                if msg.isUser {
                                                    Spacer()
                                                    Text(msg.text ?? "")
                                                        .padding()
                                                        .foregroundColor(.white)
                                                        .cornerRadius(12)
                                                }
                                                else {
                                                    Text(msg.text ?? "")
                                                        .padding()
                                                        .background(Color.black)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(12)
                                                    Spacer()
                                                }
                                            }
                                            .id(msg.id) // important for scrolling
                                        }
                                    }
                                    .padding()
                                }
                                .onChange(of: convoManager.activeConversation?.messagesArray.count) { _ in
                                    if let lastId = convoManager.activeConversation?.messagesArray.last?.id {
                                        withAnimation {
                                            proxy.scrollTo(lastId, anchor: .bottom)
                                        }
                                    }
                                }
                                .onAppear {
                                    if let lastId = convoManager.activeConversation?.messagesArray.last?.id {
                                        DispatchQueue.main.async {
                                            proxy.scrollTo(lastId, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Buttons row
                            HStack(spacing: 12) {
                                if isGenerating {
                                    Button(action: {
                                        convoManager.cancelGeneration()
                                        isGenerating = false
                                    }) {
                                        HStack {
                                            Image(systemName: "stop.circle")
                                            Text("Stop Generating")
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.red)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                else if convoManager.activeConversation != nil {
                                    Button(action: {
                                        if let lastUserMsg = convoManager.activeConversation?.messagesArray.last(where: { $0.isUser })?.text {
                                            isGenerating = true
                                            convoManager.sendToOpenAI(text: lastUserMsg) {
                                                isGenerating = false
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Regenerate")
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .foregroundColor(.green)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 4)
                            
                            // Message box
                            messageBox
                                .frame(height: editorHeight)
                                .padding()
                                .onChange(of: inputText) { _ in recalcHeight() }
                        }
                        .padding()
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
            }
        }
        .onAppear {
            convoManager.resetConversation()
        }
    }
    
    // MARK: - Message Box
    private var messageBox: some View {
        VStack(spacing: 12) {
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .frame(minHeight: 40, maxHeight: 120, alignment: .center)
                    .background(Color.clear)
                    .foregroundColor(.white)
                
                if inputText.isEmpty {
                    Text("Write your message ...")
                        .foregroundColor(.gray)
                        .padding(.leading, 6)
                        .padding(.vertical, 8)
                }
            }
            
            // Bottom row of buttons
            HStack(spacing: 16) {
                Button(action: {}) {
                    Image("link").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {}) {
                    Image("image").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white)
                
                Button(action: {sendMessage(feature: selectedFeature)}) {
                    Image("sent")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black)
        .cornerRadius(16)
    }
    
    private func sendMessage(feature: CoreAIFeature) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        isGenerating = true
        
        // Check if there’s an active conversation for this feature
        if convoManager.activeConversation == nil {
            // Create a new conversation
            convoManager.startNewConversation(for: feature, in: viewContext)
            // Set the title as the first message
            convoManager.activeConversation?.title = text
        }
        
        // Add the user message
        convoManager.addMessageToActiveConversation(text, isUser: true)
        
        // Call the AI feature
        convoManager.callFeatureAPI(feature: feature, input: text) {
            isGenerating = false
        }
    }
    
    private func recalcHeight() {
        let lineCount = max(1, inputText.split(separator: "\n").count)
        let newHeight = CGFloat(30 * lineCount + 100)
        editorHeight = min(max(145, newHeight), 400)
    }
}

enum CoreAIFeature: String, CaseIterable, Identifiable {
    case summarization = "Text Summarization"
    case paraphrasing = "Paraphrasing & Rewriting"
    case grammar = "Grammar & Style Checking"
    case translation = "Language Translation"
    case contentGen = "Content Generation"
    case codeAssist = "Code Assistance"
    case imageUnderstanding = "Image Understanding"
    case documentUnderstanding = "Document Understanding"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .summarization:
            return "Quickly condense long articles, PDFs, or chats into key points."
        case .paraphrasing:
            return "Rephrase or rewrite text with better clarity and tone."
        case .grammar:
            return "Check and refine your grammar, spelling, and style."
        case .translation:
            return "Translate text across multiple languages accurately."
        case .contentGen:
            return "Generate blog posts, captions, or creative writing."
        case .codeAssist:
            return "Get help writing, explaining, or fixing your code."
        case .imageUnderstanding:
            return "Analyze or describe image content."
        case .documentUnderstanding:
            return "Understand and extract insights from long documents."
        }
    }
}

