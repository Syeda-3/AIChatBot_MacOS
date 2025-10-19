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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            HStack(spacing: 0) {
                
                if convoManager.activeConversation == nil {
                    // Welcome screen
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
                            .padding(.top, 12)
                        messageBox
//                            .frame(height: editorHeight)
                            .padding(.horizontal, 60)
//                            .onChange(of: inputText) { _ in
//                                recalcHeight()
//                            }
                        
                        Spacer()
                    }
                    .background(Color("BgColor"))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                else {
                    Spacer()
                    // Active chat
                    VStack(spacing: 0) {
                        // Chat history sidebar
                        VStack(spacing: 0) {
                            Text("Chat History")
                                .font(.headline)
                                .foregroundColor(.white)
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
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .padding(.vertical, 12)
                            
                            Button(action: addNewChat) {
                                Image(systemName: "plus")
                                    .foregroundColor(.white)
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
//                                    .padding(.vertical)
                                }
                                .onChange(of: convoManager.activeConversation?.messagesArray.count) { _ in
                                    scrollToBottom(proxy)
                                }
                                .onAppear {
                                    scrollToBottom(proxy)
                                }
                            }
                                                    
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
                                        .padding(.vertical, 6)
                                        .foregroundColor(.red)
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
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
                                            DispatchQueue.main.async { isGenerating = false }
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
                                        .background(Color.black)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Message box
                            messageBox
//                                .frame(height: editorHeight)
                                .padding(10)
//                                .onChange(of: inputText) { _ in recalcHeight() }
                        }
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding(.vertical)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            if convoManager.activeConversation == nil {
                convoManager.activeConversation = conversations.last
            }
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
                        VStack( spacing: 8) {
                            Image(systemName: "doc.text")
                                .resizable()
                                .foregroundColor(.gray)
                                .frame(width: 30, height: 30)

                            Text(file.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
            
            //            if showWaveform {
            //                // 🎤 Recording state
            //                VStack {
            //                    WaveformView(levels: recorder.levels)
            //                        .frame(height: 30)
            //                        .padding(.top, 15)
            //
            //                    HStack {
            //                        Button(action: {
            //                            recorder.stop()
            //                            showWaveform = false
            //                        }) {
            //                            Image(systemName: "xmark")
            //                                .font(.system(size: 20, weight: .bold))
            //                                .foregroundColor(.red)
            //                        }
            //                        .buttonStyle(.plain)
            //
            //                        Spacer()
            //
            //                        Button(action: {
            //                            recorder.stop()
            //                            showWaveform = false
            //
            //                            if let url = recorder.lastRecordingURL {
            //                                convoManager.sendAudio(fileURL: url) { text in
            //                                    if let text = text {
            //                                        print(text)
            //                                        self.inputText = text
            //                                        self.sendMessage()
            //                                    }
            //                                    else {
            //                                        self.inputText = "[transcription failed]"
            //                                    }
            //                                }
            //                            }
            //                        }
            //                        ) {
            //                            Image(systemName: "checkmark")
            //                                .font(.system(size: 20, weight: .bold))
            //                                .foregroundColor(.green)
            //                        }
            //                        .buttonStyle(.plain)
            //                    }
            //                }
            //            }
            //            else {
            
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
            //            }
            
            // Bottom row of buttons
            HStack(spacing: 16) {
                Button(action: {
                    openFilePicker()
                }) {
                    Image("link").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                //                Button(action: {}) {
                //                    Image("image").foregroundColor(.gray)
                //                }
                //                .buttonStyle(.plain)
                
                //                Button(action: {
                //                    if recorder.isRecording {
                //                        recorder.stop()
                //                        showWaveform = false
                //                    }
                //                    else {
                //                        recorder.requestAndStart()
                //                        showWaveform = true
                //                    }
                //                }) {
                //                    Image("voice")
                //                        .foregroundColor(showWaveform ? .red : .gray)
                //                }
                //                .buttonStyle(.plain)
                
                
                //                Divider()
                //                    .frame(height: 20)
                //                    .background(Color.white)
                
                Button(action: {sendMessage()}) {
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
    
    
    // MARK: - Functions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Create a conversation if none exists yet
        if convoManager.activeConversation == nil {
            convoManager.activeConversation = convoManager.createConversation(title: text)
        }

        isGenerating = true

        // Send message (with or without file)
        convoManager.sendMessage(
            inputText: text,
            fileURL: selectedFile,
            fileType: selectedFileType
        ) {
            DispatchQueue.main.async {
                isGenerating = false
            }
        }

        // Reset after sending
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
        if convoManager.activeConversation == convo { convoManager.activeConversation = nil }
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
    
    private func recalcHeight() {
        let lineCount = max(1, inputText.split(separator: "\n").count)
        let newHeight = CGFloat(30 * lineCount + 100)
        editorHeight = min(max(145, newHeight), 400)
    }
    
    private func resetMessageBox() {
        inputText = ""
        selectedFile = nil
        imagePreview = nil
        selectedFileType = nil
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
