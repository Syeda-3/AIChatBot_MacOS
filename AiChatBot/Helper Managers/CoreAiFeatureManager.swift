//
//  CoreAiFeatureModel.swift
//  AiChatBot
//
//  Created by Simra Syed on 12/10/2025.
//

import SwiftUI

enum CoreAIFeature: String, CaseIterable, Identifiable {
    case summarization
    case paraphrasing
    case grammar
    case contentGen
    case codeAssist
    case translation
    case imageUnderstanding
    case documentUnderstanding

    var id: String { rawValue }

    // MARK: - Title & description
    var title: String {
        switch self {
        case .summarization: return "Summarization"
        case .paraphrasing: return "Paraphrasing"
        case .grammar: return "Grammar Check"
        case .contentGen: return "Content Generation"
        case .codeAssist: return "Code Assistant"
        case .imageUnderstanding: return "Image Understanding"
        case .documentUnderstanding: return "Document Understanding"
        case .translation: return "Translation"
        }
    }

    var description: String {
        switch self {
        case .summarization:
            return "Condense long articles into concise key points."
        case .paraphrasing:
            return "Reword content while keeping the meaning intact."
        case .grammar:
            return "Fix spelling, grammar, and tone for clarity."
        case .contentGen:
            return "Create blog posts, product descriptions, or social content."
        case .codeAssist:
            return "Explain, debug, or improve your code."
        case .imageUnderstanding:
            return "Analyze and describe image content."
        case .documentUnderstanding:
            return "Extract insights or summaries from complex documents."
        case .translation:
            return "Translate text between multiple languages accurately."
        }
    }

    // MARK: - Default prompt for the feature
    var basePrompt: String {
        switch self {
        case .summarization:
            return "Summarize the given text into concise bullet points."
        case .paraphrasing:
            return "Rewrite the following text in a clear and engaging way."
        case .grammar:
            return "Correct grammar and improve writing style."
        case .contentGen:
            return "Generate creative marketing content."
        case .codeAssist:
            return "Analyze or fix this code snippet."
        case .imageUnderstanding:
            return "Describe what’s happening in the image."
        case .documentUnderstanding:
            return "Extract key insights from the provided document."
        case .translation:
            return "Translate the following text accurately into the selected language."
        }
    }

    // MARK: - Sub-features with their own prompts
    var subFeatures: [SubFeature] {
        switch self {
  
        case .summarization:
            return [
                .init(title: "Article Summary", prompt: "Summarize this article into key points."),
                .init(title: "Meeting Notes", prompt: "Summarize this meeting transcript."),
                .init(title: "Research Summary", prompt: "Condense a research paper into main findings.")
            ]
            
        case .paraphrasing:
            return [
                  .init(
                      title: "Formal",
                      prompt: "Rephrase the text using professional and academic language, ensuring clarity and a polished tone."
                  ),
                  .init(
                      title: "Casual",
                      prompt: "Reword the text in a friendly, conversational tone that feels natural and approachable."
                  ),
                  .init(
                      title: "Creative",
                      prompt: "Reimagine the text with expressive language, storytelling flair, and original phrasing while keeping the meaning intact."
                  ),
                  .init(
                      title: "SEO-Friendly",
                      prompt: "Rewrite the text to sound natural while optimizing for SEO—include relevant keywords and maintain readability."
                  )
              ]
            
        case .grammar:
            return [
                .init(title: "Product Description", prompt: "Write a compelling, SEO-friendly product description."),
                .init(title: "Marketing Email", prompt: "Draft a persuasive marketing email for customers."),
                .init(title: "Blog Post", prompt: "Write a full blog post with title, introduction, and conclusion."),
                .init(title: "Social Caption", prompt: "Create catchy and engaging social-media captions.")
            ]
        
        case .contentGen:
            return [
                   .init(
                       title: "Captions",
                       prompt: "Write short, catchy, and context-appropriate captions that grab attention and reflect the tone or theme of the content."
                   ),
                   .init(
                       title: "Product Description",
                       prompt: "Craft a persuasive and SEO-friendly product description that highlights key features, benefits, and emotional value."
                   ),
                   .init(
                       title: "Email",
                       prompt: "Compose a clear, natural, and goal-oriented email suited to the situation — professional, personal, or informational."
                   ),
                   .init(
                       title: "Blog Post",
                       prompt: "Generate a complete blog post with a strong title, engaging introduction, informative body, and cohesive conclusion written in a consistent tone."
                   )
               ]
            
        case .codeAssist:
            return [
                   .init(
                       title: "Explain Code",
                       prompt: "Read the provided code and explain what it does, how it works, and any key logic or patterns involved in simple, clear terms."
                   ),
                   .init(
                       title: "Generate Code Snippet",
                       prompt: "Write a clean, efficient, and well-commented code snippet that solves the described problem or implements the requested feature."
                   ),
                   .init(
                       title: "Debug Code",
                       prompt: "Analyze the given code for errors or inefficiencies, describe the issue clearly, and suggest a corrected or optimized version."
                   )
               ]

        case .imageUnderstanding:
            return [
                    .init(
                        title: "Image Description",
                        prompt: "Look at the image and describe it in detail — include objects, people, setting, colors, and the overall mood or context."
                    ),
                    .init(
                        title: "Object Recognition",
                        prompt: "Identify and list all visible objects in the image, specifying their types, approximate positions, and any relationships between them."
                    ),
                    .init(
                        title: "Text Extraction (OCR)",
                        prompt: "Extract all readable text from the image accurately, preserving layout where possible and ignoring decorative or irrelevant elements."
                    )
                ]
            
        case .documentUnderstanding:
            
            return [
                    .init(
                        title: "Answer / Question",
                        prompt: "Read the provided document and accurately answer questions about its content, citing relevant parts when needed."
                    ),
                    .init(
                        title: "Summarize",
                        prompt: "Summarize the document clearly and concisely, capturing the key ideas, tone, and important details while removing redundancy."
                    )
                ]
            
        case .translation:
            return LanguageLoader.loadLanguages()

        default:
            return []
        }
    }
}

// MARK: - SubFeature model
struct SubFeature: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let prompt: String
}

// MARK: - Loader for languages
struct LanguageData: Codable {
    let name: String
    let prompt: String
}

class LanguageLoader {
    
    static func loadLanguages() -> [SubFeature] {
        guard let url = Bundle.main.url(forResource: "languages", withExtension: "json") else {
            print("❌ languages.json not found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([LanguageData].self, from: data)
            return decoded.map { SubFeature(title: $0.name, prompt: $0.prompt) }
        } catch {
            print("❌ Failed to decode languages.json: \(error)")
            return []
        }
    }
}
