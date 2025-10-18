//
//  CoreAiView.swift
//  AiChatBot
//
//  Created by Simra Syed on 03/10/2025.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit

struct CoreAIView: View {
    
    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 145
    @State private var isGenerating = false
    @State private var selectedFeature: CoreAIFeature? = .summarization
    @State private var selectedSubFeature: SubFeature? = nil
    
    @EnvironmentObject var convoManager: ConversationManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showSubscription = false
    @State private var selectedFile: URL?
    @State private var imagePreview: NSImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                Spacer()
                // Sidebar
                FeatureSidebar(selectedFeature: $selectedFeature,
                               selectedSubFeature: $selectedSubFeature,
                               convoManager: convoManager)
                
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
                            
                            Text(selectedFeature?.rawValue ?? "")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            Text(selectedFeature?.description ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            HStack {
                                Spacer()
                                subFeatureMenu
                                    .frame(width: 230)
                                    .padding(.trailing, 16)
                                    .padding(.vertical,4)
                            }
                            
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
                            HStack {
                                Spacer()
                                subFeatureMenu
                                    .frame(width: 230)
                                    .padding(.trailing, 16)
                                    .padding(.vertical,4)
                            }
                            
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
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .onChange(of: selectedFeature) { _ in
            resetMessageBox()
        }
    }
    
    private var subFeatureMenu: some View {
        HStack(spacing: 10) {
            Spacer()
            if let feature = selectedFeature {
                Menu {
                    ForEach(feature.subFeatures, id: \.self) { sub in
                        Button(sub.title) {
                            selectedSubFeature = sub
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSubFeature?.title ?? "Select")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.vertical, 4)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background(Color(.darkGray).opacity(0.5))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Message Box
    private var messageBox: some View {
        VStack(spacing: 12) {
            
            // MARK: - File Preview
            if let file = selectedFile {
                ZStack(alignment: .topTrailing) {
                    if let image = imagePreview {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 180)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 36))
                                .foregroundColor(.gray)
                            Text(file.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding()
                        .frame(width: 180, height: 180)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    Button {
                        selectedFile = nil
                        imagePreview = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .offset(x: -8, y: 8)
                    .buttonStyle(.plain)
                }
                .transition(.opacity)
            }
            
            // MARK: - Text Input
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .frame(minHeight: 40, maxHeight: 120)
                    .background(Color.clear)
                    .foregroundColor(.white)
                
                if inputText.isEmpty {
                    Text("Write your message ...")
                        .foregroundColor(.gray)
                        .padding(.leading, 6)
                        .padding(.vertical, 8)
                }
            }
            
            // MARK: - Buttons Row
            HStack(spacing: 16) {
                
                // Only show link button for Image & Document Understanding
                if selectedFeature == .imageUnderstanding || selectedFeature == .documentUnderstanding {
                    Button(action: openFilePicker) {
                        Image("link").foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: {
                    sendMessage(feature: selectedFeature ?? .summarization)
                }) {
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
        .animation(.easeInOut, value: selectedFile)
    }
    
    private func sendMessage(feature: CoreAIFeature) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || selectedFile != nil else { return } // allow empty text for image/doc uploads
        
        // Reset typing state
        inputText = ""
        isGenerating = true
        
        // Ensure conversation context
        if convoManager.activeConversation == nil {
            convoManager.startNewConversation(for: feature, in: viewContext)
            convoManager.activeConversation?.title = text.isEmpty ? feature.title : text
        }
        
        // Add user message if text is present
        if !text.isEmpty {
            convoManager.addMessageToActiveConversation(text, isUser: true)
        }
        
        // MARK: - Select proper prompt
        var systemPrompt: String
        if let sub = selectedSubFeature {
            systemPrompt = sub.prompt
        } else {
            systemPrompt = feature.basePrompt
        }
        
        // MARK: - Route based on feature type
        switch feature {
        case .imageUnderstanding:
            guard let fileURL = selectedFile else {
                print("⚠️ No image selected")
                isGenerating = false
                return
            }
            convoManager.callImageUnderstandingAPI(
                systemPrompt: systemPrompt, input: text,
                fileURL: fileURL
            ) {
                isGenerating = false
            }

        case .documentUnderstanding:
            guard let fileURL = selectedFile else {
                print("⚠️ No document selected")
                isGenerating = false
                return
            }
            convoManager.callDocumentUnderstandingAPI(
                systemPrompt: systemPrompt, input: text,
                fileURL: fileURL
            ) {
                isGenerating = false
            }

        default:
            // Normal text-based flow
            convoManager.callFeatureAPI(
                systemPrompt: systemPrompt,
                input: text
            ) {
                isGenerating = false
            }
        }
    }
    
    private func recalcHeight() {
        let lineCount = max(1, inputText.split(separator: "\n").count)
        let newHeight = CGFloat(30 * lineCount + 100)
        editorHeight = min(max(145, newHeight), 400)
    }
    
    private func resetMessageBox() {
        inputText = ""
        selectedFile = nil
        imagePreview = nil
    }
    
    private func openFilePicker() {
        guard let selectedFeature else { return }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        
        switch selectedFeature {
        case .imageUnderstanding:
            panel.title = "Select Image"
            panel.allowedContentTypes = [.png, .jpeg]
            
        case .documentUnderstanding:
            panel.allowedContentTypes = [.pdf, .text,
                                         UTType(filenameExtension: "doc")!,
                                         UTType(filenameExtension: "docx")!]
            
        default:
            return // do nothing for other features
        }
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFile = url
            if selectedFeature == .imageUnderstanding, let image = NSImage(contentsOf: url) {
                imagePreview = image
            } else {
                imagePreview = nil
            }
        }
    }
    
    private func loadImagePreview(from url: URL) {
        if let image = NSImage(contentsOf: url),
           let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
           type.conforms(to: .image) {
            imagePreview = image
        } else {
            imagePreview = nil
        }
    }
    
}
