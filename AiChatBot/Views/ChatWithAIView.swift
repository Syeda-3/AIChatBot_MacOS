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

struct ChatWithAIView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var convoManager: ConversationManager
    @State private var isGenerating: Bool = false
    @State private var renamingConversation: Conversation?
    @State private var tempTitle: String = ""
    @StateObject private var recorder = AudioRecorder()
    @State private var showWaveform = false
    
    // Fetch all conversations (sorted by date)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)],
        animation: .default
    )
    private var conversations: FetchedResults<Conversation>
    
    @State private var inputText: String = ""
    @State private var editorHeight: CGFloat = 145
    
    @State private var newTitle: String = ""
    
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
                            .frame(height: editorHeight)
                            .padding(.horizontal, 60)
                            .onChange(of: inputText) { _ in
                                recalcHeight()
                            }
                        
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
                                                } else {
                                                    Text(msg.text ?? "")
                                                        .padding()
                                                        .background(Color.black)
                                                        .foregroundColor(.white)
                                                        .cornerRadius(12)
                                                    Spacer()
                                                }
                                            }
                                            .id(msg.id) 
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
                        .background(Color("BgColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
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
        VStack(spacing: 12) {
            
            if showWaveform {
                // 🎤 Recording state
                VStack {
                    WaveformView(levels: recorder.levels)
                        .frame(height: 30)
                        .padding(.top, 15)
                    
                    HStack {
                        Button(action: {
                            recorder.stop()
                            showWaveform = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            recorder.stop()
                            showWaveform = false
                            
                            if let url = recorder.lastRecordingURL {
                                convoManager.sendAudio(fileURL: url) { text in
                                    if let text = text {
                                        print(text)
                                        self.inputText = text
                                        self.sendMessage()
                                    }
                                    else {
                                        self.inputText = "[transcription failed]"
                                    }
                                }
                            }
                        }
                        ) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            else {
                // 📝 Normal typing state
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
            }
            
            // Bottom row of buttons
            HStack(spacing: 16) {
                Button(action: {}) {
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
        
        if convoManager.activeConversation == nil {
            convoManager.activeConversation = convoManager.createConversation(title: text)
        }
        
        isGenerating = true
        convoManager.sendToOpenAI(text: text) {
            isGenerating = false
        }
        
        inputText = ""
        recalcHeight()
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
}
