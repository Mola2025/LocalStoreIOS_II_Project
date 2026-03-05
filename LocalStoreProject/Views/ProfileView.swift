//
//  ProfileView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-07.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI
import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var currentUser: User? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView{
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    if let user = currentUser {
                        VStack(spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {
                                
                                WebImage(
                                    url: URL(string: user.profileImageURL ?? "")
                                )
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(user.displayName)
                                        .font(.system(size: 26))
                                        .bold()
                                    Text(user.email ?? "No email")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 4)
                            
                            Divider()
                        }
                        
                        // Buttons
                        
                        HStack(spacing: 12) {
                            
                            NavigationLink(destination: EditProfileView()) {
                                Text("Edit Profile")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            
                            Button(role: .destructive) {
                                signOut()
                            } label: {
                                Text("Sign Out")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(30)
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                }
                
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadUser()
            }
        }
    }
    private func loadUser(){
        if let user = authManager.currentUser{
            self.currentUser = user
        }
    }
    
    private func signOut() {
        authManager.signOut { result in
            switch result {
            case .success():
                self.errorMessage = nil
                print("Successfully Logout")

            case .failure(let error):
                self.errorMessage = error.localizedDescription
                print("Sign Out Error: \(error.localizedDescription)")
            }
        }
    }
}
#Preview {
    ProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(
            AuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
