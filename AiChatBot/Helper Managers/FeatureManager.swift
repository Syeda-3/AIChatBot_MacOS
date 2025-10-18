//
//  FeatureManager.swift
//  AiChatBot
//
//  Created by Simra Syed on 04/10/2025.
//

import Foundation
import Alamofire
import PDFKit

class APIHandler {
    
    static let shared = APIHandler()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    let apiKey = Bundle.main.infoDictionary?["API_KEY"] ?? ""

    func callFeatureAPI(systemPrompt: String, input: String, completion: @escaping (Result<String, Error>) -> Void) {
                
        let model = ModelManager.shared.selectedModelAPIName

        let params: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": input]
            ]
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json"
        ]
        print("param")
        print(params)
        print("???")

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
    
    func callImageUnderstandingAPI(systemPrompt: String, input: String, fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let model = ModelManager.shared.selectedModelAPIName
        let baseURL = "https://api.openai.com/v1/chat/completions"

        do {
            // Load image from disk
            guard let image = NSImage(contentsOf: fileURL) else {
                throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to load image"])
            }

            // Compress and resize before encoding
            guard let imageData = image.resizedAndCompressed(maxWidth: 800, compressionFactor: 0.7)
            else {
                throw NSError(domain: "ImageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to compress image"])
            }

            // Convert to Base64 string
            let base64String = imageData.base64EncodedString()


            let params: [String: Any] = [
                "model": "gpt-4o",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    [
                        "role": "user",
                        "content": [
                            ["type": "text", "text": input],
                            ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(base64String)"]]
                        ]
                    ]
                ]
            ]

            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
            print("param")
            print(params)
            print("???")
            AF.request(baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseDecodable(of: ChatCompletionResponse.self) { response in
                    switch response.result {
                    case .success(let result):
                        let text = result.choices.first?.message.content ?? "[No response]"
                        completion(.success(text))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        } catch {
            completion(.failure(error))
        }
    }
    
    func callDocumentUnderstandingAPI(systemPrompt: String, input: String, fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        
        let model = ModelManager.shared.selectedModelAPIName
        let baseURL = "https://api.openai.com/v1/chat/completions"

        do {
            var fileText = ""

            if fileURL.pathExtension.lowercased() == "pdf" {
                if let pdfDoc = PDFDocument(url: fileURL) {
                    fileText = pdfDoc.string ?? "[Unable to extract text from PDF]"
                } else {
                    fileText = "[Invalid PDF file]"
                }
            } else {
                let data = try Data(contentsOf: fileURL)
                fileText = String(data: data, encoding: .utf8) ?? "[Unreadable file content]"
            }

            // Combine user's input and file content together
            let combinedInput = """
            \(input)

            ----
            Below is the attached document content:
            \(fileText.prefix(8000))
            """

            let params: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": combinedInput]
                ]
            ]

            let headers: HTTPHeaders = [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": "application/json"
            ]
            print("param")
            print(params)
            print("???")  
            AF.request(baseURL, method: .post, parameters: params, encoding: JSONEncoding.default, headers: headers)
                .validate()
                .responseDecodable(of: ChatCompletionResponse.self) { response in
                    switch response.result {
                    case .success(let result):
                        let text = result.choices.first?.message.content ?? "[No response]"
                        completion(.success(text))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
        } catch {
            completion(.failure(error))
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
extension NSImage {
    func resizedAndCompressed(maxWidth: CGFloat = 800, compressionFactor: CGFloat = 0.7) -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        // Maintain aspect ratio
        let aspectRatio = size.height / size.width
        let newSize = NSSize(width: maxWidth, height: maxWidth * aspectRatio)
        
        // Draw resized version
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                  from: NSRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        resizedImage.unlockFocus()
        
        // Convert to JPEG
        guard let resizedTiff = resizedImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: resizedTiff),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
        else { return nil }
        
        return jpegData
    }
}
