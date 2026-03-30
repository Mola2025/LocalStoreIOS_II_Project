//
//  CartView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-27.
//

import SwiftUI

struct CartView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var cartHolder: CartHolder
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showCheckout = false
    @State private var showDeleteConfirmation = false
    @State private var updatingItemIds = Set<UUID>()
    
    var body: some View {
        NavigationStack {
            Group {
                if cartHolder.cartItems.isEmpty {
                    emptyCartView
                } else {
                    cartContentView
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !cartHolder.cartItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .alert("Clear Cart", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    clearCart()
                }
            } message: {
                Text("Are you sure you want to remove all items from your cart?")
            }
            .sheet(isPresented: $showCheckout) {
                CheckoutView()
            }
            .onAppear {
                if let user = authManager.currentUser {
                    cartHolder.setupForUser(user)
                    cartHolder.fetchCart { result in
                        switch result {
                        case .success:
                            return
                        case .failure(let error):
                            print("Error loading cart: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    private var emptyCartView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Your cart is empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Browse products in Products Tab and add items to your cart")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var cartContentView: some View {
        VStack(spacing: 0) {
            //cart items List
            List {
                ForEach(cartHolder.cartItems, id: \.id) { item in
                    CartItemRow(
                        item: item,
                        isUpdating: updatingItemIds.contains(item.id ?? UUID()),
                        onUpdateQuantity: { newQuantity in
                            updateQuantity(for: item, newQuantity: newQuantity)
                        }
                    )
                    .id(item.id)
                }
                .onDelete(perform: delete)
            }
            .listStyle(PlainListStyle())
            
            //bottom bar
            VStack(spacing: 16) {
                Divider()
                
                HStack {
                    Text("Total:")
                        .font(.headline)
                    Spacer()
                    Text(cartHolder.totalPrice, format: .currency(code: "CAD"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                Button(action: {
                    showCheckout = true
                }) {
                    HStack {
                        Text("Proceed to Checkout")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color(.systemBackground))
        }
    }
    
    private func updateQuantity(for item: CartItem, newQuantity: Int32) {
        guard let itemId = item.id else { return }
        
        updatingItemIds.insert(itemId)
        
        cartHolder.updateQuantity(for: item, newQuantity: newQuantity) { result in
            DispatchQueue.main.async {
                self.updatingItemIds.remove(itemId)
                
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Error updating quantity: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearCart() {
        cartHolder.clearCart { result in
            switch result {
            case .success:
                print("Cart cleared")
            case .failure(let error):
                print("Error clearing cart: \(error.localizedDescription)")
            }
        }
    }
    
    private func delete(at offsets: IndexSet) {
        offsets.forEach { index in
            let cartItem = cartHolder.cartItems[index]
            cartHolder.removeFromCart(cartItem) { result in
                switch result {
                case .success:
                    break
                case .failure(let error):
                    print("Error removing item: \(error.localizedDescription)")
                }
            }
        }
    }
}
