//
//  ToastView.swift
//  TwittClone
//
//  Created by David Molano on 2025-11-22.
//

import SwiftUI

struct ToastView: View {
    
    var message: String
    var isError: Bool = false
    
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .bold))

            Text(message)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
        .cornerRadius(14)
        .shadow(radius: 6)
    }
}

#Preview {
    ToastView(
        message: "Mensaje"
    )
}
