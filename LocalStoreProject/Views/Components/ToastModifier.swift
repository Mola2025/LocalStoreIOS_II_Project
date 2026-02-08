//
//  ToastModifier.swift
//  TwittClone
//
//  Created by David Molano on 2025-11-22.
//

// create a view modifier for displaying and dismissing the toast

import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
        var message: String
        var isError: Bool = false

        func body(content: Content) -> some View {
            ZStack {
                content

                if isPresented {
                    VStack {
                        Spacer()
                        ToastView(message: message, isError: isError)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(), value: isPresented)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
}

#Preview {
    Color.clear
        .modifier(
            ToastModifier(
                isPresented: .constant(true),
                message: "Mensaje",
                isError: false
            )
        )
}
