//
//  FeatureCellView.swift
//  AiChatBot
//
//  Created by Simra Syed on 04/10/2025.
//

import SwiftUI

struct FeatureCellView: View {
    
    var isSelected: Bool
    var title =  ""
    var onSelect: () -> Void

    var body: some View {
        HStack {
                Text(title)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        onSelect()
                    }
            }
        .background(
            (isSelected ? Color.black : Color("BgColor"))
                .cornerRadius(8)
        )
    }
}
