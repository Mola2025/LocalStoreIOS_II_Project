//
//  OrderHolder.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-03-01.
//

import Foundation
import CoreData
import FirebaseFirestore
import Combine
import FirebaseAuth

final class OrderHolder: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let context: NSManagedObjectContext
    private let db = Firestore.firestore()
    private var currentUser: User?
    private var currentVendor: Vendor?
    
    init(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    //to get user's order
    func setupForUser(_ user: User?) {
        self.currentUser = user
        if user != nil {
            refreshUserOrders()
        } else {
            orders = []
        }
    }
    
    // to get vendor's orders
    func setupForVendor(_ vendor: Vendor?) {
        self.currentVendor = vendor
        if vendor != nil {
            refreshVendorOrders()
        } else {
            orders = []
        }
    }
    
    func fetchUsersOrdersFromFirestore(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser,
              let firebaseUUID = user.firebaseUUID else {
            completion(.failure(SimpleError("No user logged in")))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("users")
            .document(firebaseUUID)
            .collection("orders")
            .order(by: "orderDate", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(.success(()))
                    }
                    return
                }
                
                let group = DispatchGroup()
                var fetchError: Error?
                
                for document in documents {
                    group.enter()
                    let data = document.data()
                    let orderId = document.documentID
                    
                    // Create or update order in CoreData
                    self.context.perform {
                        do {
                            // Check if order exists
                            let orderRequest: NSFetchRequest<Order> = Order.fetchRequest()
                            orderRequest.predicate = NSPredicate(format: "id == %@", orderId)
                            orderRequest.fetchLimit = 1
                            
                            let results = try self.context.fetch(orderRequest)
                            let order: Order
                            
                            if let existingOrder = results.first {
                                order = existingOrder
                            } else {
                                order = Order(context: self.context)
                                order.id = UUID(uuidString: orderId) ?? UUID()
                                order.user = user
                            }
                            
                            // Update order data
                            order.orderDate = (data["orderDate"] as? Timestamp)?.dateValue() ?? Date()
                            order.status = data["status"] as? String ?? "pending"
                            order.total = data["total"] as? Double ?? 0.0
                            
                            // Fetch order items
                            self.fetchUserOrderItems(userId: firebaseUUID, orderId: orderId, order: order) {
                                group.leave()
                            }
                        } catch {
                            fetchError = error
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = fetchError {
                        self.isLoading = false
                        completion(.failure(error))
                    } else {
                        self.saveContext(completion: completion)
                    }
                }
            }
    }
    
    func fetchVendorOrdersFromFirestore(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let vendorId = currentVendor,
              let firebaseUUID = vendorId.firebaseUUID else {
            completion(.failure(SimpleError("No vendor logged in")))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("vendors")
            .document(firebaseUUID)
            .collection("orders")
            .order(by: "orderDate", descending: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(.success(()))
                    }
                    return
                }
                
                let group = DispatchGroup()
                var fetchError: Error?
                
                for document in documents {
                    group.enter()
                    let data = document.data()
                    let orderId = document.documentID
                    
                    self.context.perform {
                        do {
                            let request: NSFetchRequest<Order> = Order.fetchRequest()
                            request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: orderId)! as CVarArg)
                            request.fetchLimit = 1
                            
                            let results = try self.context.fetch(request)
                            let order: Order
                            
                            if let existingOrder = results.first {
                                order = existingOrder
                            } else {
                                order = Order(context: self.context)
                                order.id = UUID(uuidString: orderId) ?? UUID()
                            }
                            
                            order.orderDate = (data["orderDate"] as? Timestamp)?.dateValue() ?? Date()
                            order.status = data["status"] as? String ?? "pending"
                            order.total = data["total"] as? Double ?? 0.0
                            
                            self.fetchVendorOrderItems(vendorId: firebaseUUID, orderId: orderId, order: order) {
                                group.leave()
                            }
                        } catch {
                            fetchError = error
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    if let error = fetchError {
                        self.isLoading = false
                        completion(.failure(error))
                    } else {
                        self.saveContext(completion: completion)
                    }
                }
            }
    }
    
    private func fetchUserOrderItems(userId: String, orderId: String, order: Order, completion: @escaping () -> Void) {
        db.collection("users")
            .document(userId)
            .collection("orders")
            .document(orderId)
            .collection("items")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    completion()
                    return
                }
                
                self.context.perform {
                    //clear items that exist already
                    if let existingItems = order.orderItems as? Set<OrderItem> {
                        for item in existingItems {
                            self.context.delete(item)
                        }
                    }
                    
                    //create new items
                    for document in documents {
                        let data = document.data()
                        let itemId = document.documentID
                        
                        let orderItem = OrderItem(context: self.context)
                        orderItem.id = UUID(uuidString: itemId) ?? UUID()
                        orderItem.productId = data["productId"] as? String ?? ""
                        orderItem.productName = data["productName"] as? String ?? ""
                        orderItem.productPrice = data["productPrice"] as? Double ?? 0.0
                        orderItem.quantity = data["quantity"] as? Int32 ?? 0
                        orderItem.vendorId = data["vendorId"] as? String ?? ""
                        orderItem.vendorName = data["vendorName"] as? String ?? ""
                        orderItem.order = order
                    }
                    
                    completion()
                }
            }
    }
    
    private func fetchVendorOrderItems(vendorId: String, orderId: String, order: Order, completion: @escaping () -> Void) {
        db.collection("vendors")
            .document(vendorId)
            .collection("orders")
            .document(orderId)
            .collection("items")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    completion()
                    return
                }
                
                self.context.perform {
                    if let existingItems = order.orderItems as? Set<OrderItem> {
                        for item in existingItems {
                            self.context.delete(item)
                        }
                    }
                    
                    for document in documents {
                        let data = document.data()
                        let itemId = document.documentID
                        
                        let orderItem = OrderItem(context: self.context)
                        orderItem.id = UUID(uuidString: itemId) ?? UUID()
                        orderItem.productId = data["productId"] as? String ?? ""
                        orderItem.productName = data["productName"] as? String ?? ""
                        orderItem.productPrice = data["productPrice"] as? Double ?? 0.0
                        orderItem.quantity = data["quantity"] as? Int32 ?? 0
                        orderItem.userId = data["userId"] as? String ?? ""
                        orderItem.userName = data["userName"] as? String ?? ""
                        orderItem.vendorId = vendorId
                        orderItem.order = order
                    }
                    
                    completion()
                }
            }
    }
    
    // MARK: - Refresh
    func refreshUserOrders() {
        guard let user = currentUser else {
            orders = []
            return
        }
        orders = fetchUserOrders(for: user)
    }
    
    func refreshVendorOrders() {
        guard let vendor = currentVendor else {
            orders = []
            return
        }
        orders = fetchVendorOrders(for: vendor)
    }
    
    // MARK: - Fetcher
    func fetchUserOrders(for user: User) -> [Order] {
        let request: NSFetchRequest<Order> = Order.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Order.orderDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching orders: \(error)")
            return []
        }
    }
    
    func fetchVendorOrders(for vendor: Vendor) -> [Order] {
        let request: NSFetchRequest<Order> = Order.fetchRequest()
        request.predicate = NSPredicate(format: "vendor == %@", vendor)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Order.orderDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching orders: \(error)")
            return []
        }
    }
    
    // MARK: - Computed Properties
    var activeOrders: [Order] {
        orders.filter { $0.status != "delivered" && $0.status != "cancelled" }
    }
    
    var completedOrders: [Order] {
        orders.filter { $0.status == "delivered" }
    }
    
    func formattedDate(_ order: Order) -> String {
        guard let date = order.orderDate else { return "Unknown date" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Order Items
    func items(for order: Order) -> [OrderItem] {
        let set = order.orderItems as? Set<OrderItem> ?? []
        return set.sorted { ($0.productName ?? "") < ($1.productName ?? "") }
    }
    
    // MARK: - Save
    private func saveContext(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try context.save()
            DispatchQueue.main.async {
                self.isLoading = false
                if self.currentUser != nil {
                    self.refreshUserOrders()
                } else if self.currentVendor != nil {
                    self.refreshVendorOrders()
                }
                completion(.success(()))
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - SimpleError
    struct SimpleError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { return message }
    }
}
