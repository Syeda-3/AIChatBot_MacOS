//
//  FeatureManager.swift
//  AiChatBot
//
//  Created by Simra Syed on 04/10/2025.
//

import Foundation
import Alamofire

class APIHandler {
    static let shared = APIHandler()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    let apiKey = Bundle.main.infoDictionary?["API_KEY"] ?? ""

    func callFeatureAPI(feature: CoreAIFeature, input: String, completion: @escaping (Result<String, Error>) -> Void) {
        let systemPrompt: String
        
        switch feature {
            case .summarization:
                systemPrompt = "Quickly condense long articles, PDFs, or chats into key points."
            case .paraphrasing:
                systemPrompt = "Rephrase or rewrite text with better clarity and tone."
            case .grammar:
                systemPrompt = "Check and refine your grammar, spelling, and style."
            case .translation:
                systemPrompt = "Translate text into english language accurately."
            case .contentGen:
                systemPrompt =  "Generate blog posts, captions, or creative writing."
            case .codeAssist:
                systemPrompt = "Get help writing, explaining, or fixing your code."
            case .imageUnderstanding:
                systemPrompt = "Analyze or describe image content."
            case .documentUnderstanding:
                systemPrompt = "Understand and extract insights from long documents."
            }
                
        let model = ModelManager.shared.selectedModelAPIName

        let params: [String: Any] = [
            "model": model,   // or gpt-4
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ]
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        AF.request(baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: headers)
            .validate()
            .responseDecodable(of: ChatCompletionResponse.self) { response in
                switch response.result {
                case .success(let result):
                    let text = result.choices.first?.message.content ?? "[No response]"
                    print(text)
                    print("???")
                    completion(.success(text))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    nonisolated(unsafe)
    struct ChatCompletionResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            struct Message: Codable, Sendable {
                let role: String
                let content: String
            }
            let index: Int
            let message: Message
        }
        let choices: [Choice]
    }

}
