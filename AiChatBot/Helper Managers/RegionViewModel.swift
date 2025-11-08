//
//  RegionViewModel.swift
//  AiChatBot
//
//  Created by Simra Syed on 04/11/25.
//

import SwiftUI
import Combine
import Alamofire

@MainActor
final class PriceConversionViewModel: ObservableObject {
    
    // MARK: - Published
    @Published var regionCode: String = "US"
    @Published var currencyCode: String = "USD"
    @Published var symbol: String = "$"
    @Published var convertedPrices: [String: String] = [:]
    
    // MARK: - API Setup
    private let baseURL = "https://api.openai.com/v1"
    let apiKey = Bundle.main.infoDictionary?["API_KEY"] ?? ""

    // MARK: - Init
    init() {
        detectRegion()
    }
    
    // MARK: - Region Detection
    func detectRegion() {
        if let region = Locale.current.region?.identifier,
           let currency = Locale.current.currency?.identifier {
            regionCode = region
            currencyCode = currency
            symbol = Locale.current.currencySymbol ?? "$"
            print("🌍 Region detected:", regionCode, currencyCode, symbol)
        }
    }
    
    // MARK: - Price Conversion Logic
    struct PlanPrice: Codable {
        let id: String
        let price: String
    }
    
    func convertPrices(plans: [PlanPrice], completion: (() -> Void)? = nil) {
        let systemPrompt = "You are a precise price converter that outputs JSON only."
        
        let userPrompt = """
        Convert the following subscription prices into equivalent values for region \(regionCode) (\(currencyCode)).
        Include correct currency symbol (\(symbol)).
        Maintain realistic exchange rates.
        
        Input (JSON): \(plans)
        
        Output JSON only, for example:
        {
            "basic_plan": "SAR 18.99",
            "pro_plan": "SAR 29.99"
        }
        """
        
        let url = "\(baseURL)/chat/completions"
        let parameters: [String: Any] = [
            "model": "gpt-5-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        
        AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: OpenAIChatResponse.self) { response in
            switch response.result {
            case .success(let data):
                if let text = data.choices.first?.message.content,
                   let jsonData = text.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode([String: String].self, from: jsonData) {
                    DispatchQueue.main.async {
                        self.convertedPrices = parsed
                        print("✅ Converted Prices:", parsed)
                        completion?()
                    }
                } else {
                    print("⚠️ Could not parse GPT response")
                    completion?()
                }
            case .failure(let error):
                print("❌ Price conversion failed:", error)
                completion?()
            }
        }
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
