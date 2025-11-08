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
    @Published var messagesVersion = 0

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
        return totalUserMessagesCount() < 100
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
    @discardableResult
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

        var userMsg: Message?
        if let text = inputText, userMessage == nil {
            userMsg = addMessage(
                to: convo,
                text: text,
                isUser: true,
                fileURL: fileURL,
                fileType: fileType
            )
            

            if let fileURL = fileURL, let fileType = fileType {
                switch fileType {
                case "image":
                    if let image = NSImage(contentsOf: fileURL),
                       let tiff = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                        userMsg?.fileData = jpegData
                    }

                case "document":
                    userMsg?.fileURL = fileURL.path

                default:
                    break
                }
                save()
            }

            fetchAllConversations()
        }

        var allMessages = convo.messagesArray

        if let userMessage = userMessage {
            if let index = allMessages.firstIndex(of: userMessage) {
                allMessages = Array(allMessages[...index])
            }
        }

        allMessages = allMessages.filter { msg in
            !(msg.text?.contains("Message generation cancelled.") ?? false)
        }


        var messagesPayload: [[String: Any]] = allMessages.map { msg in
            [
                "role": msg.isUser ? "user" : "assistant",
                "content": msg.text ?? ""
            ]
        }

        var userContent: [[String: Any]] = [["type": "text", "text": inputText as Any]]

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

        currentRequest = AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: OpenAIChatResponse.self) { response in
            defer { DispatchQueue.main.async { completion?() } }

            switch response.result {
            case .success(let result):
                guard let reply = result.choices.first?.message.content else { return }

                DispatchQueue.main.async {
                    // 🔁 Handle regeneration replacement if needed
                    if let userMessage = userMessage {
                        if let oldAssistant = convo.messagesArray.first(where: { msg in
                            msg.isUser == false &&
                            (msg.timeStamp ?? .distantPast) > (userMessage.timeStamp ?? .distantPast)
                        }) {
                            oldAssistant.text = reply
                            self.save()
                            self.refreshActiveConversation()   // 👈 added line only
                            return
                        }
                    }

                    self.fetchAllConversations()
                }

            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    if error.localizedDescription == "URLSessionTask failed with error: The request timed out." || error.localizedDescription == "URLSessionTask failed with error: The network connection was lost." {
                        self.internetLoss()
                    }
                    print("❌ Alamofire error:", error.localizedDescription)
                }
            }
        }
    }

    private func refreshActiveConversation() {
        if let convoID = activeConversation?.objectID {
            activeConversation = try? viewContext.existingObject(with: convoID) as? Conversation
        }
        objectWillChange.send()
        messagesVersion += 1
    }


    // MARK: - Cancel
    func cancelGeneration() {
        currentRequest?.cancel()
        currentRequest = nil
        
        guard let convo = activeConversation else { return }

        if convo.messagesArray.contains(where: { $0.isUser == true }) {
            if let lastAssistant = convo.messagesArray.last(where: { $0.isUser == false }) {
                lastAssistant.text = "Message generation cancelled."
            }
            else {
                _ = addMessage(to: convo, text: "Message generation cancelled.", isUser: false)
            }
        }
        
        fetchAllConversations()
    }

    
    func internetLoss() {
        currentRequest?.cancel()
        currentRequest = nil
        
        guard let convo = activeConversation else { return }

        if convo.messagesArray.contains(where: { $0.isUser == true }) {
            if let lastAssistant = convo.messagesArray.last(where: { $0.isUser == false }) {
                lastAssistant.text = "Network connection lost. Attempting to reconnect…."
            }
            else {
                _ = addMessage(to: convo, text: "Network connection lost. Attempting to reconnect.", isUser: false)
            }
        }
        
        fetchAllConversations()
    }

    // MARK: - Save Helper
    private func save() {
        do { try viewContext.save() }
        catch { print("❌ Core Data save error: \(error)") }
        messagesVersion += 1
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
// MARK: - Core Feature APIs
extension ConversationManager {
    
    // MARK: - Feature API
    func callFeatureAPI(
        systemPrompt: String,
        input: String,
        regenerateFor userMessage: Message? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let convo = activeConversation else {
            completion?()
            return
        }
        
        guard handleSubscriptionLimit() else {
            completion?()
            return
        }

        if userMessage == nil {
            DispatchQueue.main.async {
                self.addMessage(to: convo, text: input, isUser: true)
                self.save() // ✅ ensure persistence
                self.fetchAllConversations()
            }
        }

        var allMessages = convo.messagesArray
        if let userMessage = userMessage,
           let index = allMessages.firstIndex(of: userMessage) {
            allMessages = Array(allMessages[...index])
        }

        
        let url = "\(baseURL)/chat/completions"
        let parameters: [String: Any] = [
            "model": "gpt-5-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ]
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        currentRequest?.cancel()
        currentRequest = AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: OpenAIChatResponse.self) { response in
            defer { DispatchQueue.main.async { completion?() } }

            switch response.result {
            case .success(let result):
                guard let reply = result.choices.first?.message.content else { return }

                DispatchQueue.main.async {
                    if let userMessage = userMessage {
                        // 🔁 Replace old assistant message
                        if let oldAssistant = convo.messagesArray.first(where: { msg in
                            !msg.isUser &&
                            (msg.timeStamp ?? .distantPast) > (userMessage.timeStamp ?? .distantPast)
                        }) {
                            oldAssistant.text = reply
                            self.save()
                            self.refreshActiveConversation()
                            return
                        }
                    }
                    // 🆕 Otherwise add new AI message
                    _ = self.addMessage(to: convo, text: reply, isUser: false)
                    self.fetchAllConversations()
                }

            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    if error.localizedDescription == "URLSessionTask failed with error: The request timed out." || error.localizedDescription == "URLSessionTask failed with error: The network connection was lost." {
                        self.internetLoss()
                    }
                    print("❌ Feature API error:", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Image Understanding
    func callImageUnderstandingAPI(
        systemPrompt: String,
        input: String,
        fileURL: URL,
        regenerateFor userMessage: Message? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let convo = activeConversation else {
            completion?()
            return
        }

        guard handleSubscriptionLimit() else {
            completion?()
            return
        }

        // 🟢 Add user message only if new
        if userMessage == nil {
            DispatchQueue.main.async {
                let userMsg = self.addMessage(to: convo, text: input, isUser: true, fileURL: fileURL, fileType: "image")
                if let image = NSImage(contentsOf: fileURL),
                   let tiff = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                    userMsg.fileData = jpegData
                    self.save()
                }
                self.fetchAllConversations()
            }
        }

        // 🧹 Trim history if regenerating
        var allMessages = convo.messagesArray
        if let userMessage = userMessage,
           let index = allMessages.firstIndex(of: userMessage) {
            allMessages = Array(allMessages[...index])
        }

        let base64 = (try? Data(contentsOf: fileURL))?.base64EncodedString() ?? ""
       
        let parameters: [String: Any] = [
                    "model": "gpt-5-mini",
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": [
                            ["type": "text", "text": input],
                            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64)"]]
                        ]]
                    ]
                    ]
                    
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]

        currentRequest?.cancel()
        currentRequest = AF.request(
            "\(baseURL)/chat/completions",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: OpenAIChatResponse.self) { response in
            defer { DispatchQueue.main.async { completion?() } }

            switch response.result {
            case .success(let result):
                guard let reply = result.choices.first?.message.content else { return }

                DispatchQueue.main.async {
                    if let userMessage = userMessage {
                        if let oldAssistant = convo.messagesArray.first(where: { msg in
                            !msg.isUser &&
                            (msg.timeStamp ?? .distantPast) > (userMessage.timeStamp ?? .distantPast)
                        }) {
                            oldAssistant.text = reply
                            self.save()
                            self.refreshActiveConversation()
                            return
                        }
                    }
                    _ = self.addMessage(to: convo, text: reply, isUser: false)
                    self.fetchAllConversations()
                }

            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    if error.localizedDescription == "URLSessionTask failed with error: The request timed out." || error.localizedDescription == "URLSessionTask failed with error: The network connection was lost." {
                        self.internetLoss()
                    }
                    print("❌ Image Understanding API error:", error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Document Understanding
    func callDocumentUnderstandingAPI(
        systemPrompt: String,
        input: String,
        fileURL: URL,
        regenerateFor userMessage: Message? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let convo = activeConversation else {
            completion?()
            return
        }

        guard handleSubscriptionLimit() else {
            completion?()
            return
        }

        if userMessage == nil {
            DispatchQueue.main.async {
                self.addMessage(to: convo, text: input, isUser: true, fileURL: fileURL, fileType: "document")
                self.fetchAllConversations()
            }
        }

        var allMessages = convo.messagesArray
        if let userMessage = userMessage,
           let index = allMessages.firstIndex(of: userMessage) {
            allMessages = Array(allMessages[...index])
        }

        var messagesPayload: [[String: Any]] = allMessages.map { msg in
            [
                "role": "system",
                "content": systemPrompt
            ]
        }

        messagesPayload.append([
            "role": "user",
            "content": "\(input)\n\n[Document attached: \(fileURL.lastPathComponent)]"
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
        currentRequest = AF.request(
            "\(baseURL)/chat/completions",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: OpenAIChatResponse.self) { response in
            defer { DispatchQueue.main.async { completion?() } }

            switch response.result {
            case .success(let result):
                guard let reply = result.choices.first?.message.content else { return }

                DispatchQueue.main.async {
                    if let userMessage = userMessage {
                        if let oldAssistant = convo.messagesArray.first(where: { msg in
                            !msg.isUser &&
                            (msg.timeStamp ?? .distantPast) > (userMessage.timeStamp ?? .distantPast)
                        }) {
                            oldAssistant.text = reply
                            self.save()
                            self.refreshActiveConversation()
                            return
                        }
                    }
                    _ = self.addMessage(to: convo, text: reply, isUser: false)
                    self.fetchAllConversations()
                }

            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    if error.localizedDescription == "URLSessionTask failed with error: The request timed out." || error.localizedDescription == "URLSessionTask failed with error: The network connection was lost." {
                        self.internetLoss()
                    }
                    print("❌ Document Understanding API error:", error.localizedDescription)
                }
            }
        }
    }
}
