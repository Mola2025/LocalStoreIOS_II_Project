//
//  RegisterPage.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-07.
//

import SwiftUI
import FirebaseAuth
import CoreData

struct RegisterPage: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmpassword: String = ""
    @State private var name: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {

                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.primary)

                        Text("Create Your Account")
                            .font(.largeTitle)
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 30)

                    VStack(spacing: 16) {
                            
                            TextField("Enter your name", text: $name)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)
                            
                            TextField("Enter your email", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)

                            SecureField("Enter your password", text: $password)
                                .autocapitalization(.none)
                                .textContentType(.password)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)

                            SecureField(
                                "Confirm password",
                                text: $confirmpassword
                            )
                            .autocapitalization(.none)
                            .textContentType(.password)
                            .padding()
                            .background(Color(.lightGray))
                            .cornerRadius(10)
                        
                        //Validations
                        if !password.isEmpty && password != confirmpassword {
                            Text("Password dont match")
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                    }
                    .padding(.horizontal, 25)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 25)
                    }

                    Button {
                        registerUser()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Register")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    .disabled(!isValidForm() || isLoading)
                    .padding(.horizontal)

                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func registerUser() {

        // Clear previous errors
        errorMessage = nil
        
        // Set loading state
        isLoading = true

        authManager.registerNewUser(
            email: email,
            password: password,
            name: name,
            profileImage: nil/// Create the user without profile picture for the start // After can be updated in profile view
        ) { result in
            switch result {
            case .success(let user):
                print("User Registered: \(user.email ?? "No email")")
                dismiss()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Registration error: \(error.localizedDescription)")
            }
        }
    }
    
    func isValidForm() -> Bool {
        return User
            .isAllFieldValid(
                name: name,
                email: email,
                password: password
            ) && password == confirmpassword
    }
}

#Preview {
    RegisterPage()
        .environmentObject(AuthManager(viewContext: PersistenceController.preview.container.viewContext))
}
