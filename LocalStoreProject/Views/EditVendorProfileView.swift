//
//  EditVendorProfileView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import CoreData
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import SDWebImageSwiftUI
import SwiftUI

struct EditVendorProfileView: View {
    @EnvironmentObject var vendorAuthManager: VendorAuthManager
    @Environment(\.managedObjectContext) private var viewContext

    // This variable is for handling te return to the previous page after making an update to the profile or making an update into the DB
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var vendorDescription: String = ""

    @State private var currentVendor: Vendor? = nil
    @State private var errorMessage: String? = nil

    // For the image
    @State var data: UIImage?
    @State var selectedItem: [PhotosPickerItem] = []

    // For the Toast
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .center) {
                    if let currentVendor = currentVendor {
                        if let url = currentVendor.profileImageURL {
                            WebImage(
                                url: URL(string: url)
                            )
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                        } else {
                            Image(systemName: "person.circle.fill.dark")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .foregroundColor(.gray)
                        }

                        Text(currentVendor.email ?? "No Email")
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top)

                Divider()

                VStack {
                    // Preview of selected image
                    if let image = data {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .clipShape(Circle())
                    }

                    Text("New Profile Image")
                        .font(Font.headline.bold())
                        .padding(.horizontal, 150)

                    // Image
                    PhotosPicker(
                        selection: $selectedItem,
                        maxSelectionCount: 1,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Select a New Profile Image")
                        }
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .onChange(of: selectedItem) { newValue in
                        guard let item = newValue.first else { return }
                        item.loadTransferable(type: Data.self) { result in
                            switch result {
                            case .success(let data):
                                if let data = data,
                                    let uiImage = UIImage(data: data)
                                {
                                    self.data = uiImage
                                }
                            case .failure(let failure):
                                print("Error: \(failure.localizedDescription)")
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                Divider()

                // Form Fields to change profile info

                VStack(alignment: .leading, spacing: 20) {

                    Group {
                        Text("Bussiness Name")
                            .foregroundColor(.gray)
                        TextField("Name", text: $name)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }

                    Group {
                        Text("Email")
                            .foregroundColor(.gray)
                        TextField("Email", text: $email)
                            .disabled(true)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    Group {
                        Text("Bussiness Description")
                            .foregroundColor(.gray)
                        TextField("Description", text: $vendorDescription)
                            .padding()
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }

                }
                .padding(.horizontal)

                // Error message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // Buttons

                HStack(spacing: 12) {

                    Button {
                        updateProfile()
                    } label: {
                        Text("Update Profile")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")

                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(30)
                    }
                }
                .padding(.horizontal)
            }
        }
        .toast(
            isPresented: $showToast,
            message: toastMessage,
            isError: toastIsError
        )
        .onAppear {
            loadVendor()
        }
    }

    private func loadVendor() {
        if let vendor = vendorAuthManager.currentVendor {
            self.currentVendor = vendor

            self.name = vendor.displayName
            self.email = vendor.email ?? ""
            self.vendorDescription = vendor.vendorDescription ?? ""
        }
    }

    private func updateProfile() {
        guard let vendor = currentVendor else { return }

        // Update in CoreData
        if !name.trimmingCharacters(in: .whitespaces).isEmpty {
            vendor.name = name
        }
        
        if !vendorDescription.trimmingCharacters(in: .whitespaces).isEmpty {
            vendor.vendorDescription = vendorDescription
        }

        // Save in CoreData
        do {
            try viewContext.save()

            // Update with AuthManager (Upload Image and Sync With Firestore)
            vendorAuthManager.updateProfile(
                name: name,
                description: vendorDescription,
                profileImage: data,
            ) { result in
                switch result {
                case .success():
                    self.vendorAuthManager.currentVendor = self.vendorAuthManager.currentVendor
                    self.showSuccess("Profile Updated Successfully")

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }

                case .failure(let error):
                    self.showError(
                        "Error updating profile: \(error.localizedDescription)"
                    )
                }
            }

        } catch {
            self.showError("Error saving: \(error.localizedDescription)")
        }
    }

    // Toast Functions

    private func showSuccess(_ message: String) {
        toastMessage = message
        toastIsError = false
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    private func showError(_ message: String) {
        toastMessage = message
        toastIsError = true
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }
}

#Preview {
    EditVendorProfileView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(
            VendorAuthManager(
                viewContext: PersistenceController.preview.container.viewContext
            )
        )
}
