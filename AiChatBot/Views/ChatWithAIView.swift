//
//  ChatWithAIView.swift
//  ChatBot
//
//  Created by Simra Syed on 26/09/2025.
//

import SwiftUI
import CoreData
import Combine
import AVFoundation
import UniformTypeIdentifiers
import AppKit

struct ChatWithAIView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var convoManager: ConversationManager
    @State private var isGenerating: Bool = false
    @State private var renamingConversation: Conversation?
    @State private var tempTitle: String = ""
    @StateObject private var recorder = AudioRecorder()
    @State private var showWaveform = false
    @State private var showSubscription: Bool = false
    @State private var lastShiftPressed = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)],
        animation: .default
    )
    
    private var conversations: FetchedResults<Conversation>
    
    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 145
    
    @State private var newTitle: String = ""
    @State private var selectedFile: URL?
    @State private var imagePreview: NSImage?
    @State private var selectedFileType: String? = nil
    @State private var isShiftPressed = false
    @FocusState private var focusEditor: Bool

    var body: some View {
        ZStack {
            Color("mainBG").ignoresSafeArea()
            
            HStack(spacing: 0) {
                
                if convoManager.activeConversation == nil {
                    // Welcome screen
                    VStack {
                        HStack {
                            Spacer()
                            ModelSelectorView()
                                .frame(width: 200)
                                .padding(.trailing, 16)
                                .padding(.top,8)
                        }
                        VStack {
                            Spacer()
                            
                            Image("greencircle")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                            
                            Text("Ask anything, anytime — your AI is here to help")
                                .font(.title2)
                                .padding(.top, 20)
                            messageBox
                                .padding(.horizontal, 60)
                            Spacer()
                        }
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding()
                    }
                }
                else {
                    Spacer()
                    // Active chat
                    VStack(spacing: 0) {
                        // Chat history sidebar
                        VStack(spacing: 0) {
                            Text("Chat History")
                                .font(.headline)
                                .foregroundColor(Color("TextColor"))
                                .padding()
                            
                            Spacer()
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(conversations) { convo in
                                        ConversationCellView(
                                            convo: convo,
                                            isSelected: convoManager.activeConversation == convo,
                                            onSelect: { convoManager.activeConversation = convo },
                                            onDelete: { deleteConversation(convo) },
                                            onRenameStart: { renamingConversation = $0 },
                                            isRenaming: renamingConversation == convo,
                                            tempTitle: $tempTitle
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        
                        Spacer()
                        HStack {
                            // Clear all button
                            Button(action: deleteAllConversations) {
                                Text("Clear all chats")
                                    .foregroundColor(Color("TextColor"))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .padding(.vertical, 12)
                            
                            Button(action: addNewChat) {
                                Image(systemName: "plus")
                                    .foregroundColor(Color("TextColor"))
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 12)
                        }
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
                        
                        // Messages area
                        VStack(spacing: 10) {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ForEach(convoManager.activeConversation?.messagesArray ?? [], id: \.id) { msg in
                                            MessageBubbleView(
                                                message: msg,
                                                isActive: convoManager.activeConversation != nil
                                            )
                                            .id(msg.id)
                                        }
                                    }
                                    .id(convoManager.messagesVersion)
                                }
                                .onAppear {
                                    scrollToBottom(proxy)
                                }
                                .onChange(of: convoManager.messagesVersion) {
                                    scrollToBottom(proxy)
                                }
                            }

                                                    
                            // Buttons row
                            HStack(spacing: 12) {
                                if isGenerating {
                                    VStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)

                                        Button(action: {
                                            convoManager.cancelGeneration()
                                            isGenerating = false
                                        }) {
                                            HStack {
                                                Image(systemName: "stop.circle")
                                                Text("Stop Generating")
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .foregroundColor(.red)
                                            .background(Color("mainBG"))
                                            .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                else if convoManager.activeConversation != nil {
                                    Button(action: {
                                        guard let convo = convoManager.activeConversation,
                                              let lastUserMsg = convo.messagesArray.last(where: { $0.isUser }) else { return }
                                        
                                        isGenerating = true
                                        convoManager.sendMessage(
                                            inputText: lastUserMsg.text,
                                            regenerateFor: lastUserMsg
                                        ) {
                                            DispatchQueue.main.async {
                                                isGenerating = false
                                            }
                                        }
                                    }
                                    ) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Regenerate")
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 6)
                                        .foregroundColor(.green)
                                        .background(Color("mainBG"))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Message box
                            messageBox
                                .padding(10)
                        }
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding(.bottom, 8)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            if convoManager.activeConversation == nil {
                convoManager.activeConversation = conversations.last
            }
            SubscriptionManager.shared.clearCachedPlan()
            UserDefaults.standard.removePersistentDomain(forName: "AI.chatbot.Mac.App.AI")

        }
        .sheet(isPresented: $convoManager.showSubscription) {
            SubscriptionView()
        }
    }

    // MARK: - Message Box
    private var messageBox: some View {
        VStack(spacing: 8) {
            // MARK: - File Preview
            if let file = selectedFile {
                ZStack(alignment: .topLeading) {
                    if let image = imagePreview {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 180)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                    else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 30, height: 30)

                            Text(file.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(Color("TextColor"))
                                .lineLimit(1)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(12)
                    }
                    
                    Button {
                        selectedFile = nil
                        imagePreview = nil
                        selectedFileType = nil
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
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, 8)
                    .frame(minHeight: 40, maxHeight: 120)
                    .background(Color.clear)
                    .foregroundColor(Color("TextColor"))
                    .onChange(of: inputText) { newValue in
                        handleTextChange(newValue)
                    }
                    .focused($focusEditor) // focus here

                if inputText.isEmpty {
                    Text("Write your message ...")
                        .foregroundColor(.gray)
                        .padding(.leading, 6)
                        .padding(.vertical, 8)
                }
            }
            .contentShape(Rectangle()) 
            .onTapGesture {
                focusEditor = true // focuses the TextEditor when tapped
            }
            .background(KeyboardMonitor(isShiftPressed: $isShiftPressed))

            // MARK: - Bottom buttons
            HStack(spacing: 16) {
                Button(action: openFilePicker) {
                    Image("link").foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: sendMessage) {
                    Image("sent")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("mainBG"))
        .cornerRadius(16)
    }

    // MARK: - Functions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if convoManager.activeConversation == nil {
            convoManager.activeConversation = convoManager.createConversation(title: text)
        }

        isGenerating = true
        convoManager.sendMessage(
            inputText: text,
            fileURL: selectedFile,
            fileType: selectedFileType) {
            DispatchQueue.main.async {
                isGenerating = false
            }
        }
        resetMessageBox()
    }

    // MARK: - add new chat
    
    private func addNewChat() {
        convoManager.activeConversation = nil
        sendMessage()
    }
    
    // MARK: - Save Helper
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("❌ Error saving Core Data: \(error)")
        }
    }
    
    private func deleteConversation(_ convo: Conversation) {
        viewContext.delete(convo)
        saveContext()
        if conversations.isEmpty {
            convoManager.activeConversation = nil
        }
    }
    
    private func deleteAllConversations() {
        conversations.forEach { viewContext.delete($0) }
        saveContext()
        convoManager.activeConversation = nil
    }
    
    private func renameConversation(_ convo: Conversation) {
        renamingConversation = convo
        newTitle = convo.title ?? ""
    }
    
    private func resetMessageBox() {
        inputText = ""
        selectedFile = nil
        imagePreview = nil
        selectedFileType = nil
    }
    
    private func handleTextChange(_ newValue: String) {
        guard newValue.hasSuffix("\n") else { return }

        if isShiftPressed {
            return  // allow newline
        } else {
            inputText = newValue.trimmingCharacters(in: .newlines)
            sendMessage()
        }
    }

    private func openFilePicker() {
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        
        panel.title = "Select Image or Document"
        panel.allowedContentTypes = [.png, .jpeg, .pdf, .text,
                                     UTType(filenameExtension: "doc")!,
                                     UTType(filenameExtension: "docx")!]
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFile = url

            if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                if type.conforms(to: .image) {
                    imagePreview = NSImage(contentsOf: url)
                    selectedFileType = "image"
                }
                else {
                    imagePreview = nil
                    selectedFileType = "document"
                }
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = convoManager.activeConversation?.messagesArray.last?.id {
            DispatchQueue.main.async {
                withAnimation {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
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

struct KeyboardMonitor: NSViewRepresentable {
    @Binding var isShiftPressed: Bool

    class KeyView: NSView {
        @Binding var isShiftPressed: Bool
        init(isShiftPressed: Binding<Bool>) {
            _isShiftPressed = isShiftPressed
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }

        override func flagsChanged(with event: NSEvent) {
            isShiftPressed = event.modifierFlags.contains(.shift)
        }
    }

    func makeNSView(context: Context) -> NSView {
        KeyView(isShiftPressed: $isShiftPressed)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
