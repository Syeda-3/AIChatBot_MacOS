//
//  ToastManager.swift
//  EaseFixWorker
//
//  Created by Simra Syed on 15/09/2025.
//

import SwiftUI
import Combine

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var message: String = ""
    @Published var isShowing: Bool = false
    
    private var timer: AnyCancellable?
    
    private init() {}
    
    func show(_ message: String, duration: TimeInterval = 2.0) {
        self.message = message
        self.isShowing = true
        
        timer?.cancel()
        timer = Just(())
            .delay(for: .seconds(duration), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.isShowing = false
            }
    }
}

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.custom("Poppins-Medium", size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(8)
            .padding(.bottom, 40)
    }
}
