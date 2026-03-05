//
//  addToCartToast.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-27.
//

import SwiftUI

struct AddToCartToast: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Added to cart!")
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))    }
}

#Preview {
    AddToCartToast()
}
