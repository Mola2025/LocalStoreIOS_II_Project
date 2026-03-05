//
//  ProductsViews.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-26.
//

import SwiftUI
import CoreData

struct ProductsViews: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var productHolder: ProductHolder
    @State private var searchDraft = "" //MARK: ?????????????????????????
    @State private var selectedProduct: Product?
    
    var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search products...", text: $searchDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        if !searchDraft.isEmpty {
                            Button(action: { searchDraft = "" }) {
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
                    .onChange(of: searchDraft) { _, newValue in
                        productHolder.setSearch(newValue, context)
                    }
                    
                    // Categories horizontal scroll
                    if !productHolder.categories.isEmpty {
                        categoriesBar
                    }
                    
                    // Vendors filter (optional - you can add a menu later)
                    if !productHolder.vendors.isEmpty {
                        vendorsFilter
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
                            Button("All Vendors") {
                                productHolder.setVendor(nil, context)
                            }
                            ForEach(productHolder.vendors) { vendor in
                                Button(vendor.name ?? "Vendor") {
                                    productHolder.setVendor(vendor, context)
                                }
                            }
                        } label: {
                            HStack {
                                Text(productHolder.selectedVendor?.name ?? "Vendors")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .onAppear {
                    productHolder.refreshProducts(context)
                }
                .sheet(item: $selectedProduct) { product in
                    ProductDetailView(product: product)
                }
            }
        }
        
        private var categoriesBar: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "All" button
                    CategoryChip(
                        name: "All",
                        isSelected: productHolder.selectedCategory == nil
                    ) {
                        productHolder.setCategory(nil, context)
                    }
                    
                    // Category buttons
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
        
        private var vendorsFilter: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(productHolder.vendors) { vendor in
                        Button(vendor.name ?? "Vendor") {
                            productHolder.setVendor(vendor, context)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            productHolder.selectedVendor == vendor
                            ? Color.blue
                            : Color(.systemGray5)
                        )
                        .foregroundColor(
                            productHolder.selectedVendor == vendor
                            ? .white
                            : .primary
                        )
                        .cornerRadius(15)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
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
                                selectedProduct = product
                            }
                    }
                }
                .padding()
            }
        }
        
        private var emptyStateView: some View {
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
                    searchDraft = ""
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct CategoryChip: View {
        let name: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isSelected ? .white : .primary)
                    .cornerRadius(20)
            }
        }
    }
