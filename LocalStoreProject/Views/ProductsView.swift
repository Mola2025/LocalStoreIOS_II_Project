//
//  ProductsView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-26.
//

import SwiftUI
import CoreData
import FirebaseAuth

struct ProductsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var productHolder: ProductHolder
//    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var vendorAuthManager: VendorAuthManager
    @EnvironmentObject private var cartHolder: CartHolder
    @State private var searchProduct = ""
    @State private var selectedProduct: Product?
    @State private var productToEdit: Product?
    
    private var isVendor: Bool {
        vendorAuthManager.isAuthenticated
    }
        
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search products...", text: $searchProduct)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    if !searchProduct.isEmpty {
                        Button(action: { searchProduct = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: searchProduct) { _, newValue in
                    productHolder.setSearch(newValue, context)
                }
                
                if !productHolder.categories.isEmpty {
                    categoriesBar
                }
                
                // Products grid
                if productHolder.products.isEmpty {
                    emptyStateView
                } else {
                    productsGrid
                }
            }
            .navigationTitle("Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isVendor, let currentVendor = vendorAuthManager.currentVendor {
                            Button("My Products") {
                                productHolder.setVendor(currentVendor, context)
                            }
                        }
                        
                        else {
                            Button("All Vendors") {
                                productHolder.setVendor(nil, context)
                            }
                            
                            ForEach(productHolder.vendors) { vendor in
                                Button(vendor.name ?? "Vendor") {
                                    productHolder.setVendor(vendor, context)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if isVendor, let currentVendor = vendorAuthManager.currentVendor {
                                Text("My Products")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            else {
                                Text(productHolder.selectedVendor?.name ?? "")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if vendorAuthManager.isAuthenticated {
                        NavigationLink(destination: AddEditProductView(productToEdit: nil)) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
            .onAppear {
                if let vendor = vendorAuthManager.currentVendor {
                    productHolder.setupForVendor(vendor)
                    productHolder.fetchProducts { result in
                        switch result {
                        case .success:
                            print("Products for that vendor are shown")
                        case .failure(let error):
                            print("Error loading vendors: \(error.localizedDescription)")
                        }
                    }
                } else {
                    productHolder.refreshVendors(context)
                    productHolder.refreshProducts(context)
                }
                
                //to display the categories
                productHolder.seedCategories()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
                    .environmentObject(cartHolder)
            }
            .sheet(item: $productToEdit) { product in
                AddEditProductView(productToEdit: product)
            }
        }
    }
    
    private func handleProductTap(_ product: Product) {
        if vendorAuthManager.isAuthenticated,
           let vendorFirebaseUUID = product.vendor?.firebaseUUID,
           let currentUID = Auth.auth().currentUser?.uid,
           vendorFirebaseUUID == currentUID {
            productToEdit = product
        } else {
            selectedProduct = product
        }
    }
    
    private var categoriesBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryChip(
                    name: "All",
                    isSelected: productHolder.selectedCategory == nil
                ) {
                    productHolder.setCategory(nil, context)
                }

                ForEach(productHolder.categories) { category in
                    CategoryChip(
                        name: category.name ?? "Category",
                        isSelected: productHolder.selectedCategory == category
                    ) {
                        productHolder.setCategory(category, context)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private var productsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(productHolder.products) { product in
                    ProductCard(product: product)
                        .onTapGesture {
                            handleProductTap(product)
                        }
                }
            }
            .padding()
        }
    }

    private var emptyStateView: some View {
        Group {
            //just if vendors have no products
            if isVendor && productHolder.products.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No products yet")
                        .font(.headline)
                    
                    Text("Start adding your products to your store")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    NavigationLink(destination: AddEditProductView(productToEdit: nil)) {
                        Text("Add Your First Product")
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                //for customers or vendors with no filters
                VStack(spacing: 20) {
                    Image(systemName: "bag")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No products found")
                        .font(.headline)
                    
                    Text("Try changing your search or filters")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Button("Clear Filters") {
                        productHolder.setCategory(nil, context)
                        productHolder.setVendor(nil, context)
                        productHolder.setSearch("", context)
                        searchProduct = ""
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
