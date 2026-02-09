//
//  LoginPage.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import CoreData
import SwiftUI
import FirebaseFirestore

struct LoginPage: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var vendorAuthManager: VendorAuthManager

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showSignUp: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    // User Type Selection
    @State private var selectedLoginType: UserType = .customer

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)

                // User Type Selection
                VStack(spacing: 15) {
                    Text("Are you?")
                        .font(.headline)
                        .foregroundColor(.gray)
                    HStack(spacing: 15) {
                        ForEach(UserType.allCases, id: \.self) { userType in
                            UserTypeButton(
                                userType: userType,
                                isSelected: selectedLoginType == userType
                            ) {
                                withAnimation {
                                    selectedLoginType = userType
                                    errorMessage = nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }.padding(.bottom, 20)

                Divider()

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
                    login()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(
                                CircularProgressViewStyle(tint: .white)
                            )
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSignUp) {
                RegisterPage()
                    .environmentObject(authManager)
            }
        }
    }

    private func login() {
        // Clear previous errors
        errorMessage = nil
        isLoading = true

        switch selectedLoginType {
        case .customer:
            loginCustomer()
        case .vendor:
            loginVendor()
        }
    }

    private func loginCustomer() {
        
        checkIfVendorAccount(email: email){
            isVendor in
            if isVendor{
                isLoading = false
                errorMessage = "Account Not Found"
                return
            }
            
            authManager
                .login(email: email, password: password) {
                    result in
                    isLoading = false
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

    private func loginVendor() {
        
        checkIfCustomerAccount(email: email){
            isVendor in
            if isVendor{
                isLoading = false
                errorMessage = "Account Not Found"
                return
            }
            vendorAuthManager
                .login(email: email, password: password) {
                    result in
                    isLoading = false
                    switch result {
                    case .success(let success):
                        print("Vendor Logged In ")
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        print("\(error.localizedDescription)")
                    }
                }
        }
    }

    private func checkIfVendorAccount(
        email: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("vendors")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print(
                        "Error checking vendor account: \(error.localizedDescription)"
                    )
                    completion(false)
                    return
                }

                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }

    private func checkIfCustomerAccount(
        email: String,
        completion: @escaping (Bool) -> Void
    ) {
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print(
                        "Error checking customer account: \(error.localizedDescription)"
                    )
                    completion(false)
                    return
                }

                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
}

#Preview {
    LoginPage()
        .environmentObject(
            AuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
