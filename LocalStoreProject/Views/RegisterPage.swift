//
//  RegisterPage.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-07.
//

import CoreData
import FirebaseAuth
import SwiftUI

struct RegisterPage: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vendorAuthManager: VendorAuthManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmpassword: String = ""
    @State private var name: String = ""
    @State private var vendorDescription: String = ""

    // User Type Selection
    @State private var selectedUserType: UserType = .customer

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {

                    // Header
                    VStack(spacing: 15) {
                        Image(systemName: selectedUserType.icon)
                            .font(.system(size: 80))
                            .foregroundColor(.primary)

                        Text("Create Your Account")
                            .font(.largeTitle)
                            .foregroundColor(.primary)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 30)

                    // User Type Selection
                    VStack(spacing: 15) {
                        Text("What are you going to be?")
                            .font(.headline)
                            .foregroundColor(.gray)
                        HStack(spacing: 15) {
                            ForEach(UserType.allCases, id: \.self) { userType in
                                UserTypeButton(
                                    userType: userType,
                                    isSelected: selectedUserType == userType
                                ) {
                                    withAnimation {
                                        selectedUserType = userType
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    VStack(spacing: 16) {

                        // If Vendor is choosed, show desc field
                        if selectedUserType == .vendor{
                            TextField("Enter your bussiness name", text: $name)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)
                        }
                        
                        // If Vendor is choosed, show desc field
                        if selectedUserType == .customer{
                            TextField("Enter your name", text: $name)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)
                        }

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
                        
                        // If Vendor is choosed, show desc field
                        if selectedUserType == .vendor{
                            TextField(
                                "Describe your bussiness",
                                text: $vendorDescription
                            )
                                .autocapitalization(.sentences)
                                .padding()
                                .background(Color(.lightGray))
                                .cornerRadius(10)
                        }

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
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .white)
                                )
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
        
        switch selectedUserType {
        case .customer:
            registerCustomer()
        case .vendor:
            registerVendor()
        }
    }
    
    private func registerCustomer(){
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
    
    private func registerVendor(){
        vendorAuthManager.registerNewVendor(
            email: email,
            password: password,
            name: name,
            description: vendorDescription,
            profileImage: nil/// Create the user without profile picture for the start // After can be updated in profile view
        ) { result in
            switch result {
            case .success(let user):
                print("Vendor Registered: \(user.email ?? "No email")")
                dismiss()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Registration error: \(error.localizedDescription)")
            }
        }
    }

    func isValidForm() -> Bool {
        return
            User
            .isAllFieldValid(
                name: name,
                email: email,
                password: password
            ) && password == confirmpassword
    }
}

#Preview {
    RegisterPage()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(
            AuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
