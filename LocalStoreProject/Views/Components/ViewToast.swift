//
//  ViewToast.swift
//  TwittClone
//
//  Created by David Molano on 2025-11-22.
//


// We’ll also add a helper function that links the view modifier and our Toast struct instance.

import SwiftUI

extension View {
    func toast(isPresented: Binding<Bool>, message: String, isError: Bool = false) -> some View {
        self.modifier(ToastModifier(isPresented: isPresented, message: message, isError: isError))
    }
}
