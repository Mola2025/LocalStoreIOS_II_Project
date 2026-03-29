//
//  AddEditProductView.swift
//  LocalStoreProject
//
//  Created by Alvaro Limaymanta Soria on 2026-02-26.
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct AddEditProductView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var productHolder: ProductHolder
    @Environment(\.dismiss) var dismiss
    
    //if nil, the product will be created
    let productToEdit: Product?
    
    //Form fields
    @State private var name = ""
    @State private var price: Double = 0.0
    @State private var desc = ""
    @State private var stock: Int32 = 0
    @State private var selectedCategory: Category?
    
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var imageUrl = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product Information") {
                    TextField("Product Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                HStack {
                    TextField("Price", value: $price, format: .currency(code: "CAD"))
                        .keyboardType(.decimalPad)
                }

                Stepper("Stock: \(stock)", value: $stock, in: 0...100)

                TextField("Description", text: $desc, axis: .vertical)
                    .lineLimit(3...6)

                Section("Category") {
                    if productHolder.categories.isEmpty {
                        Text("No categories available")
                            .foregroundColor(.gray)
                    } else {
                        Picker("Select Category", selection: $selectedCategory) {
                            Text("None").tag(Category?.none)
                            ForEach(productHolder.categories) { category in
                                Text(category.name ?? "Category")
                                    .tag(Category?.some(category))
                            }
                        }
                    }
                }

                Section("Product Image") {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Select Image")
                        }
                    }

                    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    } else if !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                        //show current image selection
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }

                //delete button (just for editing)
                if productToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Product")
                                Spacer()
                            }
                        }
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(productToEdit == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProduct()
                    }
                    .disabled(!Product.isAllFieldValid(name: name, price: price, stock: stock) || isLoading)
                }
            }
            .alert("Delete Product", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProduct()
                }
            } message: {
                Text("Are you sure you want to delete this product? This action cannot be undone.")
            }
            .onAppear {
                productHolder.fetchProducts { result in
                    switch result {
                    case .success:
                        print("Product details fetched")
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                
                //load existing product data if editing
                if let product = productToEdit {
                    name = product.name ?? ""
                    price = product.price
                    desc = product.desc ?? ""
                    stock = product.stock
                    selectedCategory = product.category
                    imageUrl = product.imageUrl ?? ""
                }
                
                //to display the categories
                productHolder.seedCategories()
            }
            .onChange(of: selectedImage) { _, newValue in
                Task {
                    guard let data = try? await newValue?.loadTransferable(type: Data.self) else {
                        return
                    }
                    
                    selectedImageData = data
                    isLoading = true
                    
                    //image to Firebase
                    uploadImage(data) { result in
                        switch result {
                        case .success (let downloadURL):
                            imageUrl = downloadURL
                            isLoading = false
                            
                        case .failure (let error):
                        errorMessage = error.localizedDescription
                        isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    private func uploadImage(_ imageData: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let compressedData = UIImage(data: imageData)?.jpegData(compressionQuality: 0.5) else {
            completion(.failure(SimpleError("Failed to compress image")))
            return
        }

        //unique filename
        let filename: String
        if let productId = productToEdit?.id?.uuidString {
            filename = productId + ".jpg"
        } else {
            filename = UUID().uuidString + ".jpg"
        }
        
        let productImageRef = Storage.storage().reference().child("product_image/\(filename)")
        
        //ensure it's an image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        productImageRef.putData(compressedData, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(SimpleError("Error uploading the image: \(error.localizedDescription)")))
                return
            }
            
            productImageRef.downloadURL { (url, error) in
                if let error = error {
                    completion(
                        .failure(
                            SimpleError(
                                "Error getting download the URL: \(error.localizedDescription)"
                            )
                        )
                    )
                    return
                }
                
                let urlString = url?.absoluteString ?? ""
                                print("URL obtained: \(urlString)")
                                completion(.success(urlString))
                
            }
        }

    }
    
    private func saveProduct() {
        isLoading = true
        
        if let product = productToEdit {
            productHolder.updateProduct(
                product: product,
                name: name,
                price: price,
                desc: desc,
                category: selectedCategory,
                stock: stock,
                imageUrl: imageUrl
            ) { result in
                isLoading = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            productHolder.createProduct(
                name: name,
                price: price,
                desc: desc,
                category: selectedCategory,
                stock: stock,
                imageUrl: imageUrl
            ) { result in
                isLoading = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteProduct() {
        guard let product = productToEdit else { return }
        
        isLoading = true
        productHolder.deleteProduct(product) { result in
            isLoading = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    struct SimpleError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { return message }
    }
}
