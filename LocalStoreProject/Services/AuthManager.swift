//
//  AuthManager.swift
//  AuthFirebaseExample
//
//  Created by David Molano on 2025-10-27.
//

import Combine  // Observable Pattern // Donde los componentes estaran notificados si alguna data o variable cambia en la app
import CoreData
// Como un state en React
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

struct SimpleError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var localizedDescription: String {
        return message
    }
}

class AuthManager: ObservableObject {

    @Published var user: FirebaseAuth.User?  // user only for the auth from firebase
    @Published var currentUser: User?  // Este user es para mantener el user durante toda la app // coredata

    private let db = Firestore.firestore()
    private let viewContext: NSManagedObjectContext

    var isAuthenticated: Bool {
        return user != nil && currentUser != nil
    }

    init(viewContext: NSManagedObjectContext) {

        self.viewContext = viewContext

        self.user = Auth.auth().currentUser  // Guardara el usuario para tenerlo presente en toda la app
        if let currentUser = self.user {
            fetchUserData(uid: currentUser.uid, completion: { _ in })
        }
    }

    // Fetch3 Data

    private func fetchUserData(
        uid: String,
        completion: @escaping (Result<User?, Error>) -> Void
    ) {

        // First search in CoreData
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUUID == %@", uid) // WHERE firebaseUUID == uid
        request.fetchLimit = 1

        do {
            let users = try viewContext.fetch(request)
            if let localUser = users.first {
                DispatchQueue.main.async {
                    self.currentUser = localUser
                }
                completion(.success(localUser))
                return
            }
        } catch {
            print("Error searching in CoreData: \(error.localizedDescription)")
        }

        // If not exists in CoreData, search in Firebase

        db.collection("users").document(uid).getDocument {
            snapshot,
            error in
            if let error = error {
                print("Error fetching user data: \(error)")
                completion(.failure(error))
                return
            }

            //data() returns a Dictionary filled with data
            guard let data = snapshot?.data() else {
                DispatchQueue.main.async {
                    self.currentUser = nil
                }
                completion(.success(nil))
                return
            }

            DispatchQueue.main.async {
                let newUser = User(context: self.viewContext)
                newUser.id =
                    UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
                newUser.firebaseUUID = uid
                newUser.name = data["name"] as? String
                newUser.email = data["email"] as? String
                newUser.profileImageURL = data["profileImageURL"] as? String
                
                // Save the address (At the beggining is all set to a default value 0.0 and empty string)
                if let addressData = data["address"] as? [String: Any] {
                    let address = Address(context: self.viewContext)
                    address.latitude = addressData["latitude"] as? Double ?? 0.0
                    address.longitude = addressData["longitude"] as? Double ?? 0.0
                    address.city = addressData["city"] as? String ?? ""
                    address.street = addressData["street"] as? String ?? ""
                    newUser.address = address
                    address.user = newUser
                }

                do {
                    try self.viewContext.save()
                    self.currentUser = newUser
                    completion(.success(newUser))
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

    func registerNewUser(
        email: String,
        password: String,
        name: String,
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

                self.createUserFirestore(
                    userId: firebaseUser.uid,
                    email: email,
                    name: name,
                    profileImage: profileImage,
                    completion: completion
                )

            }
        }
    }

    // CreateUserFirestore Method (This method is to create the user in the firestore using the same id as the Auth)

    private func createUserFirestore(
        userId: String,
        email: String,
        name: String,
        profileImage: UIImage?,
        completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void
    ) {

        self.uploadProfileImage(userId: userId, image: profileImage) { result in
            switch result {
            case .success(let imageUrl):
                // Create the user in CoreData
                DispatchQueue.main.async {
                    let newUser = User(context: self.viewContext)
                    newUser.id = UUID()
                    newUser.firebaseUUID = userId
                    newUser.name = name
                    newUser.email = email
                    newUser.profileImageURL = imageUrl.isEmpty ? nil : imageUrl

                    do {
                        try self.viewContext.save()
                        self.currentUser = newUser

                        self.createUserCollection(user: newUser) {
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
        let profileImageRef = storageRef.child("profileImages/\(userId).jpg")

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
                                completion(.success(urlString))
                
            }
        }
    }

    // createUserCollection Method to push into the firestore the user that is created first in CoreData

    private func createUserCollection(
        user: User,
        completion: @escaping (Error?) -> Void
    ) {

        guard let firebaseUID = user.firebaseUUID else {
            completion(SimpleError("User does not have a firebase UUID"))
            return
        }

        let userData: [String: Any] = [
            "id": user.id?.uuidString ?? "",
            "firebaseUUID": firebaseUID,
            "name": user.name ?? "",
            "email": user.email ?? "",
            "profileImageURL": user.profileImageURL ?? "",

        ]
        db
            .collection("users")
            .document(firebaseUID).setData(userData) {
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
                self.fetchUserData(uid: firebaseUser.uid) { result in
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
            self.currentUser = nil
            completion(.success(()))
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
            completion(.failure(signOutError))
        }
    }

    // Update Profile

    func updateProfile(
        name: String?,
        profileImage: UIImage?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let currentUser = self.currentUser,
            let firebaseUID = currentUser.firebaseUUID
        else {
            completion(.failure(SimpleError("No user logged in")))
            return
        }

        // Si hay nueva imagen, subirla primero
        if let newImage = profileImage {
            uploadProfileImage(userId: firebaseUID, image: newImage) { result in
                switch result {
                case .success(let imageUrl):
                    self.updateUserData(
                        user: currentUser,
                        name: name,
                        imageUrl: imageUrl,
                        completion: completion
                    )
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            // Sin imagen nueva, solo actualizar datos
            self.updateUserData(
                user: currentUser,
                name: name,
                imageUrl: nil,
                completion: completion
            )
        }
    }

    // Update User Data From CoreData First

    func updateUserData(
        user: User,
        name: String?,
        imageUrl: String?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        DispatchQueue.main.async {
            // Only update if user write something in the text boxes in CoreData
            if let name = name {
                user.name = name
            }

            if let imageUrl = imageUrl, !imageUrl.isEmpty {
                user.profileImageURL = imageUrl
            }

            do {
                try self.viewContext.save()

                // Sync changes to FireStore

                self.createUserCollection(user: user) { error in
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
