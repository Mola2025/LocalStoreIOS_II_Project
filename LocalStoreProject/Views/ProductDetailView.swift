//
//  ProductDetailView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-26.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseAuth

struct ProductDetailView: View {
    let product: Product
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var vendorAuthManager: VendorAuthManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var cartHolder: CartHolder
    @State private var quantity: Int32 = 1
    @State private var showAddedToCartToast = false
    @State private var showEditSheet = false
    @State private var isAddingToCart = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let imageUrl = product.imageUrl, !imageUrl.isEmpty {
                        WebImage(url: URL(string: imageUrl))
                            .resizable()
                            .indicator(.activity)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 300)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        //who's the vendor?
                        if let vendor = product.vendor {
                            HStack {
                                Image(systemName: "storefront.fill")
                                    .foregroundColor(.blue)
                                Text(vendor.name ?? "Local Vendor")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 8)
                        }
                        
                        //title and price
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name ?? "")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                if let category = product.category?.name {
                                    Text(category)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Spacer()
                            
                            Text(product.price, format: .currency(code: "CAD"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Divider()
                        
                        //stock status
                        HStack {
                            Image(systemName: product.stock > 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(product.stock > 0 ? .green : .red)
                            Text(product.stock > 0 ? "In Stock (\(product.stock) available)" : "Out of Stock")
                                .font(.subheadline)
                        }
                        
                        //description
                        if let desc = product.desc, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                Text(desc)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                            
                        //add to cart button
                        Button(action: addToCart) {
                            HStack {
                                Image(systemName: "cart.badge.plus")
                                Text("Add to Cart")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isAddingToCart ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isAddingToCart)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if vendorAuthManager.isAuthenticated && product.isOwnedByCurrentVendor() {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") {
                            showEditSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                AddEditProductView(productToEdit: product)
            }
            .overlay(
                //toast notification
                Group {
                    if showAddedToCartToast {
                        AddedToCartToast()
                    }
                }
                .animation(.spring(), value: showAddedToCartToast)
            )
        }
        .onAppear {
            //to make sure cart is set up for the current user
            if let user = authManager.currentUser {
                cartHolder.setupForUser(user)
            }
        }
    }
    
    private func addToCart() {
        guard authManager.currentUser != nil else {
            errorMessage = "Please log in to add items to cart"
            return
        }
        
        isAddingToCart = true
        errorMessage = nil
        
        cartHolder.addToCart(product: product, quantity: quantity) { result in
            isAddingToCart = false
            
            switch result {
            case .success:
                showAddedToCartToast = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    showAddedToCartToast = false
                    dismiss()
                }
                
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
