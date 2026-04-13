//
//  ProductHolder.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-25.
//
import Foundation
import CoreData
import FirebaseFirestore
import Combine
import FirebaseAuth

final class ProductHolder: ObservableObject {
    @Published var selectedCategory: Category? = nil
    @Published var selectedVendor: Vendor? = nil
    @Published var searchProduct: String = ""

    @Published var products: [Product] = []
    @Published var categories: [Category] = []
    @Published var vendors: [Vendor] = []
    
    private let context: NSManagedObjectContext
    private let db = Firestore.firestore()
    private var currentVendor: Vendor?
    
    func setupForVendor(_ vendor: Vendor){
        self.currentVendor = vendor
        refreshProducts(context)
        refreshCategories(context)
        refreshVendors(context)
    }
    
    func setupForCustomer() {
        self.currentVendor = nil
        refreshProducts(context)
        refreshCategories(context)
        refreshVendors(context)
    }
    
    init(_ context: NSManagedObjectContext) {
        self.context = context
    }
    
    func fetchProducts(completion: @escaping (Result<Void, Error>) -> Void) {
        if let vendor = currentVendor, let firebaseUUID = vendor.firebaseUUID {
            // Vendor mode - fetch only this vendor's products
            fetchProductsForVendor(firebaseUUID: firebaseUUID, completion: completion)
        } else {
            // Customer mode - fetch ALL products from ALL vendors
            fetchAllProducts(completion: completion)
        }
    }
    
    private func fetchProductsForVendor(firebaseUUID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("vendors")
            .document(firebaseUUID)
            .collection("products")
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
                        let productId = document.documentID
                        
                        guard let productUUID = UUID(uuidString: productId) else {
                            print("Invalid UUID string: \(productId)")
                            continue
                        }
                        
                        let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
                        productRequest.predicate = NSPredicate(format: "id == %@", productUUID as CVarArg)
                        
                        do {
                            let results = try self.context.fetch(productRequest)
                            
                            if let existingProduct = results.first {
                                self.updateProductFromFirestore(data, product: existingProduct)
                            } else {
                                self.createProductFromFirestore(data, id: productUUID)
                            }
                        } catch {
                            print("Error processing product: \(error)")
                        }
                    }
                    
                    do {
                        try self.context.save()
                        DispatchQueue.main.async {
                            self.refreshProducts(self.context)
                            self.refreshCategories(self.context)
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
        
//    func fetchProducts(completion: @escaping (Result<Void, Error>) -> Void) {
//        guard let vendor = currentVendor,
//              let firebaseUUID = vendor.firebaseUUID else {
//            completion(.failure(SimpleError("No vendor logged in")))
//            return
//        }
//        
//        db.collection("vendors")
//            .document(firebaseUUID)
//            .collection("products")
//            .getDocuments { [weak self] snapshot, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                completion(.failure(error))
//                return
//            }
//            
//            guard let documents = snapshot?.documents else {
//                completion(.success(()))
//                return
//            }
//            
//            self.context.perform {
//                for document in documents {
//                    let data = document.data()
//                    let productId = document.documentID
//                    
//                    //create String to UUID for CoreData
//                    guard let productUUID = UUID(uuidString: productId) else {
//                        print("Invalid UUID string: \(productId)")
//                        return
//                    }
//                    
//                    //check if product exists in Firestore
//                    let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
//                    productRequest.predicate = NSPredicate(format: "id == %@", productUUID as CVarArg)
//                    
//                    do {
//                        let results = try self.context.fetch(productRequest)
//                        
//                        if let existingProduct = results.first {
//                            self.updateProductFromFirestore(data, product: existingProduct)
//                        } else {
//                            self.createProductFromFirestore(data, id: productUUID)
//                        }
//                    } catch {
//                        print("Error processing product: \(error)")
//                    }
//                }
//                
//                //save and refresh on main thread
//                do {
//                    try self.context.save()
//                    DispatchQueue.main.async {
//                        self.refreshProducts(self.context)
//                        self.refreshCategories(self.context)
//                        completion(.success(()))
//                    }
//                } catch {
//                    DispatchQueue.main.async {
//                        completion(.failure(error))
//                    }
//                }
//            }
//        }
//    }
    
    private func fetchAllProducts(completion: @escaping (Result<Void, Error>) -> Void) {
        // First get all vendors
        db.collection("vendors").getDocuments { [weak self] vendorSnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let vendorDocuments = vendorSnapshot?.documents else {
                completion(.success(()))
                return
            }
            
            let group = DispatchGroup()
            var fetchError: Error?
            
            for vendorDoc in vendorDocuments {
                let vendorId = vendorDoc.documentID
                
                group.enter()
                
                self.db.collection("vendors")
                    .document(vendorId)
                    .collection("products")
                    .getDocuments { snapshot, error in
                        defer { group.leave() }
                        
                        if let error = error {
                            fetchError = error
                            return
                        }
                        
                        guard let documents = snapshot?.documents else { return }
                        
                        self.context.perform {
                            for document in documents {
                                let data = document.data()
                                let productId = document.documentID
                                
                                guard let productUUID = UUID(uuidString: productId) else {
                                    print("Invalid UUID string: \(productId)")
                                    continue
                                }
                                
                                let productRequest: NSFetchRequest<Product> = Product.fetchRequest()
                                productRequest.predicate = NSPredicate(format: "id == %@", productUUID as CVarArg)
                                
                                do {
                                    let results = try self.context.fetch(productRequest)
                                    
                                    if let existingProduct = results.first {
                                        self.updateProductFromFirestore(data, product: existingProduct)
                                    } else {
                                        self.createProductFromFirestore(data, id: productUUID)
                                    }
                                } catch {
                                    print("Error processing product: \(error)")
                                }
                            }
                        }
                    }
            }
            
            group.notify(queue: .main) {
                if let error = fetchError {
                    completion(.failure(error))
                } else {
                    do {
                        try self.context.save()
                        self.refreshProducts(self.context)
                        self.refreshCategories(self.context)
                        self.refreshVendors(self.context)
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    private func createProductFromFirestore(_ data: [String: Any], id: UUID) {
        let product = Product(context: context)
        product.id = id
        updateProductFromFirestore(data, product: product)
    }
    
    private func updateProductFromFirestore(_ data: [String: Any], product: Product) {
        product.name = data["name"] as? String ?? ""
        product.price = data["price"] as? Double ?? 0.0
        product.desc = data["desc"] as? String ?? ""
        product.stock = data["stock"] as? Int32 ?? 0
        product.imageUrl = data["imageUrl"] as? String ?? ""
        if let timestamp = data["createdAt"] as? Timestamp {
            product.createdAt = timestamp.dateValue()
        }
        
        //Category
        if let categoryIdString = data["categoryId"] as? String {
            let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "id == %@", categoryIdString)

            do {
                let results = try context.fetch(categoryRequest)
                product.category = results.first
            } catch {
                print("Error fetching categories: \(error)")
            }
        }

        //this helps the vendor get the product UUID and be able to edit their own product
        if let vendorIdString = data["vendorId"] as? String {
            let vendorRequest: NSFetchRequest<Vendor> = Vendor.fetchRequest()
            vendorRequest.predicate = NSPredicate(format: "firebaseUUID == %@", vendorIdString)
            
            do {
                let results = try context.fetch(vendorRequest)
                if let vendor = results.first {
                    product.vendor = vendor
                }
            } catch {
                print("Error fetching vendor: \(error)")
            }
        }

        //save context
        do {
            try context.save()
        } catch {
            print("Error saving the product from Firestore: \(error)")
        }
    }
    
    func seedCategories() {
        let categoryNames = [
            ("fruits_vegetables", "Fruits & Vegetables"),
            ("meat_fish", "Meat & Fish"),
            ("bakery", "Bakery"),
            ("dairy", "Dairy"),
            ("beverages", "Beverages"),
            ("homemade", "Homemade"),
            ("household", "Household")
        ]

        for (id, categoryName) in categoryNames {
            let request: NSFetchRequest<Category> = Category.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id)
            
            if let existingCategory = try? context.fetch(request).first,
               existingCategory != nil {
                continue
            }
            
            let category = Category(context: context)
            category.id = id
            category.name = categoryName
        }
            
        do {
            try context.save()
            refreshCategories(context)
        } catch {
            print("Error seeding categories: \(error)")
        }
    }

    func refreshProducts(_ context: NSManagedObjectContext){
        products = fetchProducts(context)
    }
    
    func refreshCategories(_ context: NSManagedObjectContext) {
        categories = fetchCategories(context)
    }
    
    func refreshVendors(_ context: NSManagedObjectContext){
        vendors = fetchVendors(context)
    }
    
    //MARK: - Fetchers
    func fetchCategories(_ context: NSManagedObjectContext) -> [Category] {
        do { return try context.fetch(categoriesFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }
    
    func fetchProducts(_ context: NSManagedObjectContext) -> [Product] {
        do { return try context.fetch(productsFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }
    
    func fetchVendors(_ context: NSManagedObjectContext) -> [Vendor] {
        do { return try context.fetch(vendorIdFetch()) }
        catch { fatalError("Unresolved error \(error)") }
    }
    
    //MARK: - Fetch requests
    func categoriesFetch() -> NSFetchRequest<Category> {
        let request = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        return request
    }
    
    func productsFetch() -> NSFetchRequest<Product> {
        let request = Product.fetchRequest()
        
        //newest first
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Product.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \Product.name, ascending: true)
        ]
        
        request.predicate = productsPredicate()
        return request
    }
    
    func vendorIdFetch() -> NSFetchRequest<Vendor> {
        let request = Vendor.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Vendor.name, ascending: true)]
        return request
    }
    
    //MARK: - Predicate (filtering)
    func productsPredicate() -> NSPredicate? {
        let trimmed = searchProduct.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [NSPredicate] = []

        if let currentVendor = currentVendor {
            parts.append(NSPredicate(format: "vendor == %@", currentVendor))
        }
        
        if let category = selectedCategory {
            parts.append(NSPredicate(format: "category == %@", category))
        }
        
        if let vendor = selectedVendor {
            parts.append(NSPredicate(format: "vendor == %@", vendor))
        }

        if !trimmed.isEmpty {
            // search in name OR details (case/diacritic insensitive)
            parts.append(NSPredicate(format: "name CONTAINS[cd] %@", trimmed))
        }

        if parts.isEmpty { return nil }
        if parts.count == 1 { return parts[0] }

        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }
    
    // MARK: - Filter Controls
    func setCategory(_ category: Category?, _ context: NSManagedObjectContext) {
        selectedCategory = category
        refreshProducts(context)
    }

    func setSearch(_ text: String, _ context: NSManagedObjectContext) {
        searchProduct = text
        refreshProducts(context)
    }
    
    func setVendor(_ vendor: Vendor?, _ context: NSManagedObjectContext) {
        selectedVendor = vendor
        refreshProducts(context)
    }
    
    // MARK: - Logic Methods
    func createCategory(name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }

        let c = Category(context: context)
        c.id = String()
        c.name = n

        saveContext(completion: completion)
    }

    func deleteCategory(_ category: Category, completion: @escaping (Result<Void, Error>) -> Void) {
        if selectedCategory == category {
            selectedCategory = nil
        }
        context.delete(category)
        saveContext(completion: completion)
    }

    func createProduct(
        name: String,
        price: Double,
        desc: String?,
        category: Category?,
        stock: Int32,
        imageUrl: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        //check if user is authenticated
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(SimpleError("No user logged in.")))
            return
        }
        
//        //Convert uid string to UUID for CoreData predicate
//        guard let vendorUUID = UUID(uuidString: uid) else {
//            completion(.failure(SimpleError("Invalid vendor ID format")))
//            return
//        }
        
        //Get the vendor from CoreData using the UUID
        let vendorRequest: NSFetchRequest<Vendor> = Vendor.fetchRequest()
        vendorRequest.predicate = NSPredicate(format: "firebaseUUID == %@", uid)
        
        var vendor: Vendor!
        
        do {
            let results = try context.fetch(vendorRequest)
            if let existingVendor = results.first {
                vendor = existingVendor
            } else {

                vendor = Vendor(context: context)
                vendor.id = UUID()
                vendor.firebaseUUID = uid
                vendor.name = "Vendor"
                vendor.email = Auth.auth().currentUser?.email ?? ""
                try context.save()
            }
        } catch {
            completion(.failure(error))
            return
        }
        
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else {
            completion(.failure(SimpleError("Product name cannot be empty")))
            return
        }

        //productId for CoreData
        let productId = UUID()
        
        //productId for Firestore
        let productIdString = productId.uuidString
        
        //prepare the data in Firestore
        let productData: [String: Any] = [
            "id": productIdString,
            "name": n,
            "price": price,
            "description": desc ?? "",
            "stock": stock,
            "imageUrl": imageUrl,
            "createdAt": Timestamp(date: Date()),
            "categoryId": category?.id ?? "",
            "categoryName": category?.name ?? "",
            "vendorId": uid,
            "vendorName": vendor.name ?? ""
        ]
        
        //save it to Firestore
        db.collection("vendors")
            .document(uid)
            .collection("products")
            .document(productIdString)
            .setData(productData) { [ weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let self = self else { return }
                    
            let product = Product(context: self.context)
            product.id = productId
            product.name = n
            product.price = price
            product.desc = desc
            product.category = category
            product.stock = stock
            product.vendor = vendor
            product.imageUrl = imageUrl
            product.createdAt = Date()
            
            do {
                try self.context.save()
                self.refreshProducts(self.context)
                self.refreshVendors(self.context)
                self.refreshCategories(self.context)
                completion(.success(()))
            } catch {
                completion(.failure((error)))
            }
        }
    }
    
    func updateProduct(
        product: Product,
        name: String,
        price: Double,
        desc: String?,
        category: Category?,
        stock: Int32,
        imageUrl: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        //check if user is authenticated
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(SimpleError("No user logged in.")))
            return
        }
        
//        //Convert uid string to UUID for CoreData predicate
//        guard let vendorUUID = UUID(uuidString: uid) else {
//            completion(.failure(SimpleError("Invalid vendor ID format")))
//            return
//        }
//
        //Get the vendor from CoreData using the UUID
        let vendorRequest: NSFetchRequest<Vendor> = Vendor.fetchRequest()
        vendorRequest.predicate = NSPredicate(format: "firebaseUUID == %@", uid)
        
        guard let vendor = try? context.fetch(vendorRequest).first else {
            completion(.failure(SimpleError("Vendor not found in local firestore")))
            return
        }
        
        //check if product exists
        guard let productId = product.id else {
            completion(.failure(SimpleError("Product doesn't exist")))
            return
        }
        
        //Convert UUID to String for Firestore
        let productIdString = productId.uuidString
        
        //prepare the data in Firestore
        let productData: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "price": price,
            "description": desc ?? "",
            "stock": stock,
            "imageUrl": imageUrl,
            "categoryId": category?.id ?? "",
            "categoryName": category?.name ?? "",
        ]
        
        db.collection("vendors")
            .document(uid)
            .collection("products")
            .document(productIdString)
            .updateData(productData) { [ weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            //update coreData
            product.name = name
            product.price = price
            product.desc = desc
            product.category = category
            product.stock = stock
            product.vendor = vendor
            product.imageUrl = imageUrl
            
            self?.saveContext(completion: completion)
        }
    }

    func deleteProduct(_ product: Product, completion: @escaping (Result<Void, Error>) -> Void) {
        //check if user is authenticated
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(SimpleError("No user logged in.")))
            return
        }
        
        //check if product exists
        guard let productId = product.id else {
            completion(.failure(SimpleError("Product doesn't exist")))
            return
        }
        
        //Convert UUID to String for Firestore
        let productIdString = productId.uuidString
        
        db.collection("vendors")
            .document(uid)
            .collection("products")
            .document(productIdString)
            .delete() { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            //delete from CoreData
            self?.context.delete(product)
            self?.saveContext(completion: completion)
        }
    }
    
    // MARK: - Save
    func saveContext(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try context.save()
            DispatchQueue.main.async {
                self.refreshProducts(self.context)
                self.refreshCategories(self.context)
                self.refreshVendors(self.context)
                completion(.success(()))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    struct SimpleError: LocalizedError {
        let message: String
        
        init(_ message: String) {
            self.message = message
        }
        
        var errorDescription: String? {
            return message
        }
    }
}
