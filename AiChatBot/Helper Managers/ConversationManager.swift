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
import StoreKit

class ConversationManager: ObservableObject {
    
    private let viewContext: NSManagedObjectContext
    
    @Published var conversations: [Conversation] = []
    @Published var activeConversation: Conversation?
    @Published var showSubscription: Bool = false
    private var currentRequest: DataRequest?
    
    let apiKey = Bundle.main.infoDictionary?["API_KEY"] ?? ""
    private let baseURL = "https://api.openai.com/v1"
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchAllConversations()
    }
    
    // MARK: - Subscription Gate
    private func hasActiveSubscription() -> Bool {
        return SubscriptionManager.shared.currentPlan != nil
    }
    
    private func totalUserMessagesCount() -> Int {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        request.predicate = NSPredicate(format: "isUser == true")
        return (try? viewContext.count(for: request)) ?? 0
    }
    
    private func canSendMessage() -> Bool {
        if hasActiveSubscription() { return true }
        return totalUserMessagesCount() < 5
    }
    
    private func handleSubscriptionLimit() -> Bool {
        if !canSendMessage() {
            DispatchQueue.main.async {
                self.showSubscription = true
            }
            return false
        }
        return true
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
    
    // MARK: - Message Save
//    @discardableResult
    func addMessage(to convo: Conversation,
                    text: String? = nil,
                    isUser: Bool,
                    fileURL: URL? = nil,
                    fileType: String? = nil) -> Message {

        let msg = Message(context: viewContext)
        msg.id = UUID()
        msg.text = text
        msg.isUser = isUser
        msg.timeStamp = Date()
        msg.conversation = convo

        if let fileURL = fileURL {
            msg.fileURL = fileURL.path
            msg.fileType = fileType
        }

        save()
        return msg
    }
    
    func resetConversation() {
        activeConversation = nil
    }
    
    // MARK: - Standard Chat (text + optional file)
    func sendMessage(
        inputText: String?,
        fileURL: URL? = nil,
        fileType: String? = nil,
        regenerateFor userMessage: Message? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let convo = activeConversation else {
            print("⚠️ No active conversation.")
            completion?()
            return
        }

        guard handleSubscriptionLimit() else {
            completion?()
            return
        }

        let url = "\(baseURL)/chat/completions"

        // MARK: - Build messages payload
        var messagesPayload: [[String: Any]] = convo.messagesArray.map { msg in
            [
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text ?? ""
            ]
        }

        var userContent: [[String: Any]] = [["type": "text", "text": inputText as Any]]

        // MARK: - Handle attachments for payload
        if let fileURL = fileURL {
            switch fileType {
            case "image":
                if let data = try? Data(contentsOf: fileURL) {
                    let base64 = data.base64EncodedString()
                    userContent.append([
                        "type": "image_url",
                        "image_url": ["url": "data:image/png;base64,\(base64)"]
                    ])
                }
            case "document":
                userContent.append([
                    "type": "text",
                    "text": "[Document attached: \(fileURL.lastPathComponent)]"
                ])
            default:
                break
            }
        }

        messagesPayload.append([
            "role": "user",
            "content": userContent
        ])

        let parameters: [String: Any] = [
            "model": "gpt-5-mini",
            "messages": messagesPayload
        ]

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        currentRequest?.cancel()

        // MARK: - Network Request
        currentRequest = AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .validate()
            .responseDecodable(of: OpenAIChatResponse.self) { response in
                defer { DispatchQueue.main.async { completion?() } }

                switch response.result {
                case .success(let result):
                    guard let reply = result.choices.first?.message.content else { return }

                    DispatchQueue.main.async {
                        if let userMessage = userMessage {
                            // 🔁 Regeneration: replace existing assistant reply
                            if let oldAssistant = convo.messagesArray.first(where: { msg in
                                msg.isUser == false &&
                                (msg.timeStamp ?? .distantPast) > (userMessage.timeStamp ?? .distantPast)
                            }) {
                                oldAssistant.text = reply
                                self.save()
                                self.fetchAllConversations()
                                return
                            }
                        }

                        // MARK: - Save user message properly
                        let userMsg = self.addMessage(
                            to: convo,
                            text: inputText,
                            isUser: true,
                            fileURL: fileURL,
                            fileType: fileType
                        )
                        
                        // Attach data depending on type
                        if let fileURL = fileURL, let fileType = fileType {
                            switch fileType {
                            case "image":
                                if let image = NSImage(contentsOf: fileURL),
                                   let tiff = image.tiffRepresentation,
                                   let bitmap = NSBitmapImageRep(data: tiff),
                                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                                    userMsg.fileData = jpegData
                                }

                            case "document":
                                userMsg.fileURL = fileURL.path

                            default:
                                break
                            }
                            self.save()
                        }
                        // Add assistant’s reply
                        self.addMessage(to: convo, text: reply, isUser: false)
                        self.fetchAllConversations()
                    }

                case .failure(let error):
                    if !error.isExplicitlyCancelledError {
                        print("❌ Alamofire error:", error.localizedDescription)
                    }
                }
            }
    }


    // MARK: - Cancel
    func cancelGeneration() {
        currentRequest?.cancel()
        currentRequest = nil
    }
    
    // MARK: - Regenerate

    func regenerateLastMessage(completion: (() -> Void)? = nil) {
        guard let convo = activeConversation,
              let lastUserMsg = convo.messagesArray.last(where: { $0.isUser }) else { return }

        sendMessage(
            inputText: lastUserMsg.text,
            fileURL: lastUserMsg.fileURL != nil ? URL(string: lastUserMsg.fileURL!) : nil,
            fileType: lastUserMsg.fileType,
            completion: completion
        )
    }


    // MARK: - Save Helper
    private func save() {
        do { try viewContext.save() }
        catch { print("❌ Core Data save error: \(error)") }
    }
    
    // MARK: - OpenAI Response Structs
    nonisolated(unsafe)
    struct OpenAIChatResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            let message: ChatMessage
        }
        struct ChatMessage: Codable, Sendable {
            let role: String
            let content: String?
            let contentParts: [ContentPart]?
            
            struct ContentPart: Codable, Sendable {
                let type: String
                let text: String?
                let image_url: ImageURL?
                struct ImageURL: Codable, Sendable { let url: String }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                role = try container.decode(String.self, forKey: .role)
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
extension Conversation {
    var messagesArray: [Message] {
        let set = messages as? Set<Message> ?? []
        return set.sorted { $0.timeStamp ?? Date() < $1.timeStamp ?? Date() }
    }
}
