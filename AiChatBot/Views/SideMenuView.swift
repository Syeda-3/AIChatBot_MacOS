//
//  SideMenuView.swift
//  ChatBot
//
//  Created by Simra Syed on 26/09/2025.
//

import SwiftUI

enum MenuItem: String {
    case chatWithAI = "Chat With AI"
    case aiTools = "AI Tools"
//    case settings = "Setting"
}

struct SideMenu: View {
    
    @Binding var selected: MenuItem?
    @Environment(\.openURL) private var openURL
    @ObservedObject var store = SubscriptionManager.shared
    
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack(alignment: .center, spacing: 2){
                Image("logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 55, height: 60)
                
                Text("AI Chatbot")
                    .font(.headline)
            }
            
            menuButton(title: "Chat With AI", systemImage: "chatwithai", item: .chatWithAI)
            menuButton(title: "Core AI", systemImage: "coreai", item: .aiTools)
            
            Spacer()
            
            if store.hasActivePlan == false {
                Button(action: {
                    store.showSubscription = true
                }) {
                    Label("Upgrade Pro", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.white)
                        .background(Color("PrimaryColor"))
                        .cornerRadius(20)
                    
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }

            VStack(alignment: .leading, spacing: 10) {
                // Support
                Button {
                    if let url = URL(string: "https://fli.so/AIchatbot-support") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Image("support")
                            .foregroundColor(Color("TextColor"))
                        Text("Support")
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .buttonStyle(.plain)
                
                // Terms & Conditions
                Button {
                    if let url = URL(string: "https://fli.so/terms-and-conditions") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Image("tac")
                            .foregroundColor(Color("TextColor"))
                        Text("Terms & Conditions")
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                // Privacy
                Button {
                    if let url = URL(string: "https://fli.so/privacy-policy") {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Image("privacy")
                            .foregroundColor(Color("TextColor"))
                        Text("Privacy")
                            .foregroundColor(Color("TextColor"))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
            }
            
        }
        .padding()
        .frame(minWidth: 200, maxWidth: 220, alignment: .topLeading)
        .background(Color("BgColor"))
        .sheet(isPresented: $store.showSubscription) {
            SubscriptionView(showSubscription: $store.showSubscription)
        }
    }
    
    private func menuButton(title: String, systemImage: String, item: MenuItem) -> some View {
        Button(action: {
            selected = item
        }) {
            Label(title, image: systemImage)
                .foregroundColor(selected == item ? Color.white : Color("TextColor"))
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selected == item ? Color.black : Color.clear)
                .cornerRadius(8)
                .contentShape(Rectangle()) // ✅ makes full area clickable
        }
        .buttonStyle(.plain)
    }
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
