//
//  ConversationManager.swift
//  ChatBot
//
//  Created by Simra Syed on 28/09/2025.
//

import Foundation
import CoreData
import SwiftUI
import Combine
import Alamofire

class ConversationManager: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    private var currentRequest: DataRequest?
    
    let apiKey = Bundle.main.infoDictionary?["API_KEY"] ?? ""
    
    private let baseURL = "https://api.openai.com/v1"
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchAllConversations()
    }
    
    // MARK: - Fetch
    func fetchAllConversations() {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)]
        do {
            conversations = try viewContext.fetch(request)
        } catch {
            print("❌ Failed to fetch conversations: \(error)")
        }
    }
    
    func fetchConversation(by id: UUID) -> Conversation? {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    // MARK: - Create
    func createConversation(title: String? = nil) -> Conversation {
        let convo = Conversation(context: viewContext)
        convo.id = UUID()
        convo.createdAt = Date()
        convo.title = title ?? "New Conversation"
        save()
        fetchAllConversations()
        activeConversation = convo
        return convo
    }
    
    // MARK: - Delete
    func deleteConversation(_ convo: Conversation) {
        viewContext.delete(convo)
        save()
        fetchAllConversations()
        if activeConversation == convo {
            activeConversation = nil
        }
    }
    
    func deleteAllConversations() {
        conversations.forEach { viewContext.delete($0) }
        save()
        fetchAllConversations()
        activeConversation = nil
    }
    
    // MARK: - Update
    func renameConversation(_ convo: Conversation, newTitle: String) {
        convo.title = newTitle
        save()
        fetchAllConversations()
    }
    
    func addMessage(to convo: Conversation, text: String? = nil, isUser: Bool, fileURL: URL? = nil, fileType: String? = nil ) {
        let msg = Message(context: viewContext)
        msg.id = UUID()
        msg.text = text
        msg.isUser = isUser
        msg.timeStamp = Date()
        msg.conversation = convo

        if let fileURL = fileURL {
            msg.fileURL = fileURL.absoluteString
        }
        if let fileType = fileType {
            msg.fileType = fileType
        }

        save()
        fetchAllConversations()
    }

    func resetConversation() {
        activeConversation = nil
    }
    
    // MARK: - Send to OpenAI (Chat)
    func sendToOpenAI(text: String, completion: (() -> Void)? = nil) {
        guard let convo = activeConversation else {
            print("⚠️ No active conversation.")
            completion?()
            return
        }
        
        let model = ModelManager.shared.selectedModelAPIName

        addMessage(to: convo, text: text, isUser: true)
        
        let url = "\(baseURL)/chat/completions"
        let messagesPayload = convo.messagesArray.map { msg in
            [
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text ?? ""
            ]
        }
        
        let parameters: [String: Any] = [
            "model": model,
            "messages": messagesPayload
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        // Cancel previous request if running
        currentRequest?.cancel()
        
        currentRequest = AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .validate()
            .responseDecodable(of: OpenAIChatResponse.self) { response in
                defer { DispatchQueue.main.async { completion?() } }
                
                switch response.result {
                case .success(let result):
                    if let reply = result.choices.first?.message.content {
                        DispatchQueue.main.async {
                            self.addMessage(to: convo, text: reply, isUser: false)
                        }
                    }
                case .failure(let error):
                    if error.isExplicitlyCancelledError {
                        print("⚠️ Request cancelled")
                    }
                    else {
                        print("❌ Alamofire error:", error.localizedDescription)
                        if let data = response.data {
                            print("Response data:", String(data: data, encoding: .utf8) ?? "")
                        }
                    }
                }
            }
    }
    
    // MARK: - Audio Upload (Transcription)
    func sendAudio(fileURL: URL, completion: @escaping (String?) -> Void) {
        let endpoint = "\(baseURL)/audio/transcriptions"

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)"
        ]
        
        AF.upload(multipartFormData: { multipart in
            multipart.append(fileURL, withName: "file")
            multipart.append("whisper-1".data(using: .utf8)!, withName: "model")
        }, to: endpoint, headers: headers)
        .responseDecodable(of: TranscriptionResponse.self) { response in
            switch response.result {
            case .success(let result):
                completion(result.text)   // ✅ only text
            case .failure(let error):
                print("❌ Audio upload failed:", error.localizedDescription)
                completion(nil)
            }
        }
    }
    
    // MARK: - Helpers
    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("❌ Core Data save error: \(error)")
        }
    }
    
    func cancelGeneration() {
        currentRequest?.cancel()
        currentRequest = nil
    }
    
    nonisolated(unsafe)
    struct OpenAIChatResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            let message: ChatMessage
        }

        struct ChatMessage: Codable, Sendable {
            let role: String

            // For normal chat messages
            let content: String?

            // For multimodal messages (with image/document parts)
            let contentParts: [ContentPart]?

            struct ContentPart: Codable, Sendable {
                let type: String              // "text" or "image_url"
                let text: String?             // when type == "text"
                let image_url: ImageURL?      // when type == "image_url"

                struct ImageURL: Codable, Sendable {
                    let url: String
                }
            }

            // Custom decoder for backward compatibility
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                role = try container.decode(String.self, forKey: .role)
                // Try to decode text-only or structured array content
                if let textContent = try? container.decode(String.self, forKey: .content) {
                    content = textContent
                    contentParts = nil
                } else {
                    content = nil
                    contentParts = try? container.decode([ContentPart].self, forKey: .content)
                }
            }
        }

        let choices: [Choice]
    }

    nonisolated(unsafe)
    struct TranscriptionResponse: Codable, Sendable {
        let text: String
    }
}

// MARK: - Feature-Based Conversations
extension ConversationManager {
    
    func startNewConversation(for feature: CoreAIFeature, in context: NSManagedObjectContext) {
        let convo = Conversation(context: context)
        convo.id = UUID()
        convo.title = ""
        activeConversation = convo
        save()
    }

    func addMessageToActiveConversation(_ text: String, isUser: Bool) {
        guard let convo = activeConversation else {
            print("⚠️ No active conversation found.")
            return
        }
        let msg = Message(context: viewContext)
        msg.id = UUID()
        msg.text = text
        msg.isUser = isUser
        msg.timeStamp = Date()
        msg.conversation = convo
        save()
    }
    
    func callFeatureAPI(systemPrompt: String, input: String, completion: @escaping () -> Void) {
        APIHandler.shared.callFeatureAPI(systemPrompt: systemPrompt, input: input) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.addMessageToActiveConversation(output, isUser: false)
                case .failure(let error):
                    self.addMessageToActiveConversation("❌ Error: \(error.localizedDescription)", isUser: false)
                }
                completion()
            }
        }
    }
    
    func callImageUnderstandingAPI(systemPrompt: String, input: String, fileURL: URL, completion: @escaping () -> Void) {
        APIHandler.shared.callImageUnderstandingAPI(systemPrompt: systemPrompt, input: input, fileURL: fileURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.addMessageToActiveConversation(output, isUser: false,)
                case .failure(let error):
                    self.addMessageToActiveConversation("❌ Error: \(error.localizedDescription)", isUser: false)
                }
                completion()
            }
        }
    }

    func callDocumentUnderstandingAPI(systemPrompt: String, input: String, fileURL: URL, completion: @escaping () -> Void) {
        APIHandler.shared.callDocumentUnderstandingAPI(systemPrompt: systemPrompt, input: input, fileURL: fileURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let output):
                    self.addMessageToActiveConversation(output, isUser: false)
                case .failure(let error):
                    self.addMessageToActiveConversation("❌ Error: \(error.localizedDescription)", isUser: false)
                }
                completion()
            }
        }
    }

}

// MARK: - Data Appending for Multipart
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

extension Conversation {
    var messagesArray: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted { $0.timeStamp ?? Date() < $1.timeStamp ?? Date() }
    }
}
