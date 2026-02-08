//
//  LoginPage.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import SwiftUI

struct LoginPage: View {
    @EnvironmentObject var authManager: AuthManager
       
       @State private var email: String = ""
       @State private var password: String = ""
       @State private var showSignUp: Bool = false
       @State private var errorMessage: String?
       @State private var isLoading: Bool = false
       
       var body: some View {
           NavigationView {
               VStack(spacing: 20) {
                   Text("Sign In")
                       .font(.largeTitle)
                       .fontWeight(.bold)
                       .padding(.top, 50)
                   
                   //                   Image(){
//
//                   }
                
                   
                   // Fields
                   VStack(spacing: 16) {
                       TextField("Email", text: $email)
                           .autocapitalization(.none)
                           .padding()
                           .background(Color(.lightGray))
                           .cornerRadius(10)
                       
                       SecureField("Password", text: $password)
                           .textContentType(.password)
                           .padding()
                           .background(Color(.lightGray))
                           .cornerRadius(10)
                   }
                   .padding(.horizontal)
                   
                   // Error
                   if let error = errorMessage {
                       Text(error)
                           .foregroundColor(.red)
                           .font(.caption)
                           .padding(.horizontal)
                   }
                   
                   // Botón Sign In
                   Button(action: {
                       isLoading = true
                       login()
                   }) {
                       if isLoading {
                           ProgressView()
                               .progressViewStyle(CircularProgressViewStyle(tint: .white))
                       } else {
                           Text("Sign In")
                               .fontWeight(.semibold)
                               .foregroundColor(.white)
                       }
                   }
                   .frame(maxWidth: .infinity)
                   .padding()
                   .background(Color.blue)
                   .cornerRadius(10)
                   .disabled(email.isEmpty || password.isEmpty || isLoading)
                   .padding(.horizontal)
                   
                   // Register Option (Sheet)
                   Button(action: {
                       showSignUp = true
                   }) {
                       Text("Don't have an account? Sign Up")
                           .foregroundColor(.blue)
                   }
                   .padding(.top, 10)
                   
                   Spacer()
               }
               .navigationTitle("Welcome to LocalMarket App")
               .sheet(isPresented: $showSignUp) {
                RegisterPage()
               }
           }
       }
    
    private func login(){
        authManager
            .login(email: email, password: password) {
                result in
                switch result {
                case .success(let success):
                    print("User Logged In ")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    print("\(error.localizedDescription)")
                }
            }
    }
}

#Preview {
    LoginPage()
}
