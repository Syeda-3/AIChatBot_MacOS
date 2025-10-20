//
//  Untitled.swift
//  AiChatBot
//
//  Created by Simra Syed on 19/10/2025.
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isActive: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer()
                bubbleContent
                    .background(Color.clear)
                    .foregroundColor(Color("TextColor"))
                    .cornerRadius(12)
            }
            else {
                ZStack(alignment: .bottomTrailing) {
                    VStack(alignment: .trailing, spacing:1) {
                        // Message text
                        if let text = message.text, !text.isEmpty {
                            Text(text)
                                .font(.system(size: 15))
                                .padding(10)
                                .background(Color("mainBG"))
                                .foregroundColor(Color("TextColor"))
                                .cornerRadius(12)
                        }
                        
                        // Copy button BELOW message
                        if let text = message.text, !text.isEmpty {
                            Button(action: {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(text, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color("TextColor"))
                                    .padding(6)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing,0)
                        }
                    }
                }
            }
        }
        .opacity(isActive ? 1 : 0.6)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let filePath = message.fileURL {
                let url = URL(fileURLWithPath: filePath)
                
                if message.fileType == "image" {
                    if let data = message.fileData,
                       let image = NSImage(data: data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 180)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundColor(.gray)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(Color("TextColor"))
                            .lineLimit(1)
                    }
                    .padding()
                    .frame(width: 180, height: 180)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            
            if let text = message.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundColor(Color("TextColor"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
    }
}
