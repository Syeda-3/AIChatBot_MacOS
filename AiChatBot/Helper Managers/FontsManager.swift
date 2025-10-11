//
//  FontsManager.swift
//  EaseFixWorker
//
//  Created by Simra Syed on 22/09/2025.
//

import SwiftUI

enum InterFontWeight: String {
    case regular = "Inter-Regular"
    case medium = "Inter-Medium"
    case semibold = "Inter-SemiBold"
    case bold = "Inter-Bold"
    case light = "Inter-Light"
}

extension View {
    func inter(_ weight: InterFontWeight, _ size: CGFloat) -> some View {
        self.font(.custom(weight.rawValue, size: size))
    }
}
