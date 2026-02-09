//
//  VendorAuthManager.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import Combine  // Observable Pattern // Donde los componentes estaran notificados si alguna data o variable cambia en la app
import CoreData
// Como un state en React
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

class VendorAuthManager: ObservableObject{
    
    @Published var user: FirebaseAuth.User?  // user only for the auth from firebase
    @Published var currentVendor: Vendor?  // Este user es para mantener el user durante toda la app // coredata

    private let db = Firestore.firestore()
    private let viewContext: NSManagedObjectContext

    var isAuthenticated: Bool {
        return user != nil && currentVendor != nil
    }

    init(viewContext: NSManagedObjectContext) {

        self.viewContext = viewContext

        self.user = Auth.auth().currentUser  // Guardara el usuario para tenerlo presente en toda la app
        if let currentUser = self.user {
            fetchVendorData(uid: currentUser.uid, completion: { _ in })
        }
    }
    
    // Fetch3 Data

    private func fetchVendorData(
        uid: String,
        completion: @escaping (Result<Vendor?, Error>) -> Void
    ) {

        // First search in CoreData
        let request: NSFetchRequest<Vendor> = Vendor.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUUID == %@", uid)
        request.fetchLimit = 1

        do {
            let vendors = try viewContext.fetch(request)
            if let localVendor = vendors.first {
                DispatchQueue.main.async {
                    self.currentVendor = localVendor
                }
                completion(.success(localVendor))
                return
            }
        } catch {
            print("Error searching in CoreData: \(error.localizedDescription)")
        }

        // If not exists in CoreData, search in Firebase

        db.collection("vendors").document(uid).getDocument {
            snapshot,
            error in
            if let error = error {
                print("Error fetching vendor data: \(error)")
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.currentVendor = nil
                }
                completion(.success(nil))
                return
            }

            DispatchQueue.main.async {
                let newVendor = Vendor(context: self.viewContext)
                newVendor.id =
                    UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
                newVendor.firebaseUUID = uid
                newVendor.name = data["name"] as? String
                newVendor.email = data["email"] as? String
                newVendor.vendorDescription = data["vendorDescription"] as? String
                newVendor.profileImageURL = data["profileImageURL"] as? String

                do {
                    try self.viewContext.save()
                    self.currentVendor = newVendor
                    completion(.success(newVendor))
                } catch {
                    print(
                        "Error saving user data in CoreData: \(error.localizedDescription)"
                    )
                    completion(.failure(error))
                }
            }

        }
    }

    // Register Method For Auth and Creating at the same time calling the method to create the user in the Firestore

    func registerNewVendor(
        email: String,
        password: String,
        name: String,
        description: String,
        profileImage: UIImage? = nil,
        completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void
    ) {

        Auth.auth().createUser(withEmail: email, password: password) {
            (result, error) in
            if let error = error {
                print(error.localizedDescription)
                completion(.failure(error))
                return
            } else if let firebaseUser = result?.user {
                self.user = firebaseUser

                self.createVendorFirestore(
                    userId: firebaseUser.uid,
                    email: email,
                    name: name,
                    description: description,
                    profileImage: profileImage,
                    completion: completion
                )

            }
        }
    }

    // CreateUserFirestore Method (This method is to create the user in the firestore using the same id as the Auth)

    private func createVendorFirestore(
        userId: String,
        email: String,
        name: String,
        description: String,
        profileImage: UIImage?,
        completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void
    ) {

        self.uploadProfileImage(userId: userId, image: profileImage) { result in
            switch result {
            case .success(let imageUrl):
                // Create the user in CoreData
                DispatchQueue.main.async {
                    let newVendor = Vendor(context: self.viewContext)
                    newVendor.id = UUID()
                    newVendor.firebaseUUID = userId
                    newVendor.name = name
                    newVendor.email = email
                    newVendor.vendorDescription = description
                    newVendor.profileImageURL = imageUrl.isEmpty ? nil : imageUrl

                    do {
                        try self.viewContext.save()
                        self.currentVendor = newVendor

                        self.createVendorCollection(vendor: newVendor) {
                            error in
                            if let error = error {
                                completion(.failure(error))
                            } else {
                                completion(.success((self.user!)))
                            }

                        }
                    } catch {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))

            }
        }
    }

    // UploadProfileImage Method (This method allows me to insert and save an image in the firestore storage for the UserPictureProfile)

    private func uploadProfileImage(
        userId: String,
        image: UIImage?,
        completion:
            @escaping (
                Result<String, Error>
            ) -> Void
    ) {
        guard let image = image,
            let imageData = image.jpegData(compressionQuality: 0.5)
        else {
            completion(.success(""))
            return
        }

        let storageRef = Storage.storage().reference()
        let profileImageRef = storageRef.child("vendorProfileImages/\(userId).jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        profileImageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(SimpleError("Error uploading the image: \(error.localizedDescription)")))
                return
            }
            
            profileImageRef.downloadURL { (url, error) in
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
                                print("✅ Download URL obtained: \(urlString)")
                                completion(.success(urlString))
                
            }
        }
    }

    // createUserCollection Method to push into the firestore the user that is created first in CoreData

    private func createVendorCollection(
        vendor: Vendor,
        completion: @escaping (Error?) -> Void
    ) {

        guard let firebaseUID = vendor.firebaseUUID else {
            completion(SimpleError("User does not have a firebase UUID"))
            return
        }

        var vendorData: [String: Any] = [
            "id": vendor.id?.uuidString ?? "",
            "firebaseUUID": firebaseUID,
            "name": vendor.name ?? "",
            "email": vendor.email ?? "",
            "vendorDescription": vendor.vendorDescription ?? "",
            "profileImageURL": vendor.profileImageURL ?? "",

        ]
        db
            .collection("vendors")
            .document(firebaseUID).setData(vendorData) {
                error in
                if let error = error {
                    print(
                        "Error syncing to Firestore: \(error.localizedDescription)"
                    )
                    completion(error)
                } else {
                    completion(nil)
                }
            }
    }

    // Login Method

    func login(
        email: String,
        password: String,
        completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void
    ) {
        Auth.auth().signIn(withEmail: email, password: password) {
            (result, error) in

            if let error = error {
                completion(.failure(error))
                return
            } else if let firebaseUser = result?.user {
                self.user = firebaseUser
                self.fetchVendorData(uid: firebaseUser.uid) { result in
                    switch result {
                    case .success(_):
                        completion(.success(firebaseUser))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // SignOut Method

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.currentVendor = nil
            completion(.success(()))
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
            completion(.failure(signOutError))
        }
    }

    // Update Profile

    func updateProfile(
        name: String?,
        description: String?,
        profileImage: UIImage?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentVendor = self.currentVendor,
              let firebaseUID = currentVendor.firebaseUUID
        else {
            completion(.failure(SimpleError("No user logged in")))
            return
        }

        // Si hay nueva imagen, subirla primero
        if let newImage = profileImage {
            uploadProfileImage(userId: firebaseUID, image: newImage) { result in
                switch result {
                case .success(let imageUrl):
                    self.updateVendorData(
                        vendor: currentVendor,
                        name: name,
                        description: description,
                        imageUrl: imageUrl,
                        completion: completion
                    )
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            // Sin imagen nueva, solo actualizar datos
            self.updateVendorData(
                vendor: currentVendor,
                name: name,
                description: description,
                imageUrl: nil,
                completion: completion
            )
        }
    }

    // Update User Data From CoreData First

    func updateVendorData(
        vendor: Vendor,
        name: String?,
        description: String?,
        imageUrl: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        DispatchQueue.main.async {
            // Only update if user write something in the text boxes in CoreData
            if let name = name {
                vendor.name = name
            }
            
            if let description = description{
                vendor.vendorDescription = description
            }

            if let imageUrl = imageUrl, !imageUrl.isEmpty {
                vendor.profileImageURL = imageUrl
            }

            do {
                try self.viewContext.save()

                // Sync changes to FireStore

                self.createVendorCollection(vendor: vendor) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } catch {
                completion(.failure(error))
            }

        }

    }
}
