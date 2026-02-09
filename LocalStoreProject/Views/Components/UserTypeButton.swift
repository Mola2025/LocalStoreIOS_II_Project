//
//  UserTypeButton.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import SwiftUI

struct UserTypeButton: View {
    let userType: UserType
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 12) {
                    Image(systemName: userType.icon)
                        .font(.system(size: 40))
                        .foregroundColor(isSelected ? .white : .blue)
                    
                    Text(userType.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(userType.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
}

