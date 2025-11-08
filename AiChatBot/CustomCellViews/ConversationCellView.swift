//
//  ChatCellView.swift
//  ChatBot
//
//  Created by Simra Syed on 02/10/2025.
//

import SwiftUI

struct ConversationCellView: View {
    
    @ObservedObject var convo: Conversation
    var isSelected: Bool
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onRenameStart: (Conversation?) -> Void   // <-- make it optional
    var isRenaming: Bool
    @Binding var tempTitle: String
    @FocusState var focusField: Bool

    var body: some View {
        HStack {
            if isRenaming {
                TextField("Rename", text: $tempTitle)
                    .focused($focusField)
                    .foregroundColor(isSelected ? Color.white :  Color("TextColor"))
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                    .onAppear {
                        tempTitle = convo.title ?? ""
                        DispatchQueue.main.async { focusField = true }
                    }
                    .onSubmit {
                        // save
                        convo.title = tempTitle
                        try? convo.managedObjectContext?.save()
                        // exit rename mode
                        focusField = false
                        onRenameStart(nil)
                    }
            }
            else {
                Text(convo.title ?? "Untitled")
                    .foregroundColor(isSelected ? Color.white :  Color("TextColor"))
                    .lineLimit(1)
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Menu {
                Button("Rename") { onRenameStart(convo) }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
            }
            .frame(width: 15)
            .menuStyle(.borderlessButton)
            .colorScheme(.dark)
        }
        .background(
            (isSelected ? Color.black : Color("BgColor"))
                .cornerRadius(8)
        )
        .onTapGesture {
            onSelect()
        }
    }
}
