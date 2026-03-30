//
//  CheckOutView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-27.
//
import SwiftUI
import FirebaseFirestore

struct CheckoutView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var cartHolder: CartHolder
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var isProcessingOrder = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(cartHolder.cartItems) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.product?.name ?? "Product")
                                        .font(.headline)
                                    Text("Qty: \(item.quantity)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Text((item.product?.price ?? 0) * Double(item.quantity), format: .currency(code: "CAD"))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total:")
                                .font(.title3)
                                .fontWeight(.bold)
                            Spacer()
                            Text(cartHolder.totalPrice, format: .currency(code: "CAD"))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Button(action: placeOrder) {
                        HStack {
                            Spacer()
                            Text("Place Order")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(isProcessingOrder ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessingOrder || cartHolder.cartItems.isEmpty)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Order Placed!", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your order has been successfully placed.")
            }
        }
    }
    
    private func placeOrder() {
        guard let user = authManager.currentUser,
              let userFirebaseUUID = user.firebaseUUID else {
            errorMessage = "User not logged in"
            return
        }
        
        guard !cartHolder.cartItems.isEmpty else {
            errorMessage = "Cart is empty"
            return
        }
        
        isProcessingOrder = true
        errorMessage = nil
        
        //create Order ID
        let orderId = UUID()
        let orderIdString = orderId.uuidString
        
        //prepare order data
        let orderData: [String: Any] = [
            "id": orderIdString,
            "userId": userFirebaseUUID,
            "orderDate": Timestamp(date: Date()),
            "status": "pending",
            "total": cartHolder.totalPrice,
            "itemCount": cartHolder.cartItems.count
        ]
        
        //create order in Firestore
        db.collection("users")
            .document(userFirebaseUUID)
            .collection("orders")
            .document(orderIdString)
            .setData(orderData) { error in
                if let error = error {
                    self.isProcessingOrder = false
                    self.errorMessage = "Failed to create order: \(error.localizedDescription)"
                    return
                }
                
                //create order items
                self.createOrderItems(orderId: orderIdString, userFirebaseUUID: userFirebaseUUID)
            }
    }
    
    private func createOrderItems(orderId: String, userFirebaseUUID: String) {
        guard let user = authManager.currentUser else {
            self.isProcessingOrder = false
            self.errorMessage = "User not logged in"
            return
        }
        
        //batch allows that all order items are saved for both the user and the vendor at the same time.
        // changes happen together
        let batch = db.batch()

        //user order reference from firebase
        let userOrderRef = db.collection("users")
            .document(userFirebaseUUID)
            .collection("orders")
            .document(orderId)

        //refrence to the subcollection of user/orders
        let userItemsRef = userOrderRef.collection("items")

        for cartItem in cartHolder.cartItems {
            guard let product = cartItem.product,
                  let productId = product.id,
                  let vendor = product.vendor,
                  let vendorId = vendor.firebaseUUID else { continue }

            let orderItemId = UUID().uuidString

            let orderItemData: [String: Any] = [
                "id": orderItemId,
                "productId": productId.uuidString,
                "productName": product.name ?? "",
                "productPrice": product.price,
                "quantity": cartItem.quantity,
                "vendorId": vendorId,
                "vendorName": vendor.name ?? "",
                "userId": userFirebaseUUID,
                "userName": user.name ?? ""
            ]

            //add order item data to the user in Firestore
            let userItemRef = userItemsRef.document(orderItemId)
            batch.setData(orderItemData, forDocument: userItemRef)

            //copy info for vendor collection
            let vendorOrderRef = db.collection("vendors")
                .document(vendorId)
                .collection("orders")
                .document(orderId)

            let vendorOrderData: [String: Any] = [
                "id": orderId,
                "userId": userFirebaseUUID,
                "orderDate": Timestamp(date: Date()),
                "status": "pending",
                "total": product.price * Double(cartItem.quantity),
                "itemCount": 1
            ]

            //merge the vendor order data into Firestore
            batch.setData(vendorOrderData, forDocument: vendorOrderRef, merge: true)

            //add same order item under subcollection items, this time for VENDOR
            let vendorItemRef = vendorOrderRef
                .collection("items")
                .document(orderItemId)

            batch.setData(orderItemData, forDocument: vendorItemRef)
        }

        batch.commit { error in
            if let error = error {
                self.isProcessingOrder = false
                self.errorMessage = "Failed to create order items: \(error.localizedDescription)"
                return
            }

            self.clearCartAfterOrder()
        }
    }
    
    private func clearCartAfterOrder() {
        cartHolder.clearCart { result in
            self.isProcessingOrder = false
            
            switch result {
            case .success:
                self.showSuccessAlert = true
            case .failure(let error):
                self.errorMessage = "Order placed but failed to clear cart: \(error.localizedDescription)"
                self.showSuccessAlert = true
            }
        }
    }
}
