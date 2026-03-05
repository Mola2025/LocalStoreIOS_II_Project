//
//  CartHolder.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-27.
//

import Foundation
import CoreData
import FirebaseAuth
import Combine
import FirebaseFirestore

final class CartHolder: ObservableObject {
    @Published var cartItems: [CartItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let db = Firestore.firestore()
    private var currentUser: User?
    
    init(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    //MARK: To refresh user's cart
    func setupForUser(_ user: User) {
        self.currentUser = user
        refreshCart(context)
    }
    
    func fetchCart(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser,
              let firebaseUUID = user.firebaseUUID else {
            completion(.failure(SimpleError("No user logged in")))
            return
        }
        
        db.collection("users")
            .document(firebaseUUID)
            .collection("cart")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success(()))
                    return
                }
                
                self.context.perform {
                    for document in documents {
                        let data = document.data()
                        let cartItemId = document.documentID
                        
                        //create String to UUID for CoreData
                        guard let cartItemUUID = UUID(uuidString: cartItemId) else {
                            print("Invalid UUID string: \(cartItemId)")
                            return
                        }
                        
                        //check if cart exists in CoreData
                        let request: NSFetchRequest<CartItem> = CartItem.fetchRequest()
                        request.predicate = NSPredicate(format: "id == %@", cartItemUUID as CVarArg)
                        request.fetchLimit = 1
                        
                        do {
                            let results = try self.context.fetch(request)
                            
                            if let existingItem = results.first {
                                self.updateCartItemFromFirestore(data, item: existingItem, user: user)
                            } else {
                                self.createCartItemFromFirestore(data, id: cartItemUUID, user: user)
                            }
                        } catch {
                            print("Error processing cart item: \(error)")
                        }
                    }
                    
                    do {
                        try self.context.save()
                        DispatchQueue.main.async {
                            self.refreshCart(self.context)
                            completion(.success(()))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }
    }
    
    private func createCartItemFromFirestore(_ data: [String: Any], id: UUID, user: User) {
        let item = CartItem(context: context)
        item.id = id
        updateCartItemFromFirestore(data, item: item, user: user)
    }
    
    private func updateCartItemFromFirestore(_ data: [String: Any], item: CartItem, user: User) {
        item.quantity = data["quantity"] as? Int32 ?? 1
        if let timestamp = data["createdAd"] as? Timestamp {
            item.createdAt = timestamp.dateValue()
        }
        item.user = user
        
        //link to product
        if let productIdString = data["productId"] as? String,
           let productUUID = UUID(uuidString: productIdString) {
            let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
            productRequest.predicate = NSPredicate(format: "id == %@", productUUID as CVarArg)
            productRequest.fetchLimit = 1
            
            do {
                let results = try context.fetch(productRequest)
                item.product = results.first
            } catch {
                print("Error fetching product: \(error)")
            }
        }
    }
    
    //MARK: - Refresh
    func refreshCart(_ context: NSManagedObjectContext) {
        guard let user = currentUser else {
            cartItems = []
            return
        }
        cartItems = fetchCartItems(context, for: user)
    }
    
    //MARK: - Fetcher
    func fetchCartItems(_ context: NSManagedObjectContext, for user: User) -> [CartItem] {
        let request: NSFetchRequest<CartItem> = CartItem.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CartItem.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching cart items: \(error)")
            return []
        }
    }
    
    // MARK: - Cart Methods
    func addToCart(product: Product, quantity: Int32, completion: @escaping (Result<Void, Error>) -> Void) {
        if currentUser == nil {
            completion(.failure(SimpleError("Please open the cart first to initialize")))
            return
        }
        
        guard let user = currentUser,
              let userFirebaseUUID = user.firebaseUUID,
              let productId = product.id else {
            completion(.failure(SimpleError("User not logged in or invalid product")))
            return
        }
        
        isLoading = true
        
        //check if product exists in cart
        if let existingItem = cartItems.first(where: { $0.product?.id == product.id }) {
            // Update quantity
            let newQuantity = existingItem.quantity + quantity
            updateQuantity(for: existingItem, newQuantity: newQuantity, completion: completion)
            return
        }
        
        //create new cart item
        let cartItemId = UUID()
        let cartItemIdString = cartItemId.uuidString
        
        let cartItemData: [String: Any] = [
            "id": cartItemIdString,
            "productId": productId.uuidString,
            "productName": product.name ?? "",
            "productPrice": product.price,
            "quantity": quantity,
            "createdAt": Timestamp(date: Date()),
            "vendorId": product.vendor?.firebaseUUID ?? ""
        ]
        
        //save to Firestore
        db.collection("users")
            .document(userFirebaseUUID)
            .collection("cart")
            .document(cartItemIdString)
            .setData(cartItemData) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        completion(.failure(error))
                    }
                    return
                }
                
                //save to CoreData
                let cartItem = CartItem(context: self!.context)
                cartItem.id = cartItemId
                cartItem.product = product
                cartItem.quantity = quantity
                cartItem.user = user
                cartItem.createdAt = Date()
                
                self?.saveContext(completion: completion)
            }
    }
    
    func updateQuantity(for cartItem: CartItem, newQuantity: Int32, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser,
              let userFirebaseUUID = user.firebaseUUID,
              let cartItemId = cartItem.id else {
            completion(.failure(SimpleError("Invalid cart item")))
            return
        }
        
        let showLoadingDelay = 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + showLoadingDelay) {
            if !self.isLoading {
                self.isLoading = true
            }
        }
        
        let cartItemIdString = cartItemId.uuidString
        
        //update in Firestore
        db.collection("users")
            .document(userFirebaseUUID)
            .collection("cart")
            .document(cartItemIdString)
            .updateData(["quantity": newQuantity]) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        completion(.failure(error))
                    }
                    return
                }
                
                //update in CoreData
                cartItem.quantity = newQuantity
                self?.saveContext(completion: completion)
            }
    }
    
    func removeFromCart(_ cartItem: CartItem, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser,
              let userFirebaseUUID = user.firebaseUUID,
              let cartItemId = cartItem.id else {
            completion(.failure(SimpleError("Invalid cart item")))
            return
        }
        
        isLoading = true
        
        let cartItemIdString = cartItemId.uuidString
        
        //delete from Firestore
        db.collection("users")
            .document(userFirebaseUUID)
            .collection("cart")
            .document(cartItemIdString)
            .delete { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        completion(.failure(error))
                    }
                    return
                }
                
                //delete from CoreData
                self?.context.delete(cartItem)
                self?.saveContext(completion: completion)
            }
    }
    
    func clearCart(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser,
              let userFirebaseUUID = user.firebaseUUID else {
            completion(.failure(SimpleError("User not logged in")))
            return
        }
        
        isLoading = true
        
        //get all cart item IDs
        let batch = db.batch()
        let cartRef = db.collection("users").document(userFirebaseUUID).collection("cart")
        
        for item in cartItems {
            if let itemId = item.id?.uuidString {
                let itemRef = cartRef.document(itemId)
                batch.deleteDocument(itemRef)
            }
        }
        
        //commit batch delete
        batch.commit { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    completion(.failure(error))
                }
                return
            }
            
            //delete from CoreData
            for item in self?.cartItems ?? [] {
                self?.context.delete(item)
            }
            
            self?.saveContext(completion: completion)
        }
    }
    
    // MARK: - Computed Properties
    var totalPrice: Double {
        cartItems.reduce(0) { total, item in
            total + (item.product?.price ?? 0) * Double(item.quantity)
        }
    }
    
    var itemCount: Int {
        cartItems.count
    }
    
    // MARK: - Save
    private func saveContext(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try context.save()
            DispatchQueue.main.async {
                self.isLoading = false
                self.refreshCart(self.context)
                completion(.success(()))
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                completion(.failure(error))
            }
        }
    }
    
    struct SimpleError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { return message }
    }
}
