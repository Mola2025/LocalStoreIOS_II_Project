//
//  VendorProfileView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SDWebImageSwiftUI
import SwiftUI


struct VendorProfileView: View {
    
    @EnvironmentObject var vendorAuthManager: VendorAuthManager
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var currentVendor: Vendor? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView{
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    if let vendor = currentVendor {
                        VStack(spacing: 20) {
                            HStack(alignment: .top, spacing: 16) {
                                
                                WebImage(
                                    url: URL(string: vendor.profileImageURL ?? "")
                                )
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack{
                                        Image(systemName: "storefront.fill")
                                        Text(vendor.displayName)
                                            .font(.system(size: 26))
                                            .bold()
                                    }

                                    Text(vendor.email ?? "No email")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    
                                    if let description = vendor.vendorDescription, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .lineLimit(3)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top, 4)
                            
                            Divider()
                        }
                        
                        // Buttons
                        
                        HStack(spacing: 12) {
                            
                            NavigationLink(destination: EditVendorProfileView()) {
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
                        
                        // TODO: Add section for products management
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Products")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)
                            
                            Text("Product management coming soon...")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
                
            }            .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.large)
            .onAppear{
                loadVendor()
            }
        }
    }
    private func loadVendor(){
        if let vendor = vendorAuthManager.currentVendor{
            self.currentVendor = vendor
        }
    }
    
    private func signOut() {
        vendorAuthManager.signOut { result in
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
    VendorProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(
            VendorAuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
