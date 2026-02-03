//
//  AuthManager.swift
//  AuthFirebaseExample
//
//  Created by David Molano on 2025-10-27.
//

import Combine  // Observable Pattern // Donde los componentes estaran notificados si alguna data o variable cambia en la app
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

    @Published var user: User?  // Lo mismo que FirebaseAuth.user? // Este user es para mantener el user durante toda la app
    @Published var twitterUser: TwitterUser?  // Este user es para traer toda la informacion de la db
    private let db = Firestore.firestore()

    init() {
        self.user = Auth.auth().currentUser  // Guardara el usuario para tenerlo presente en toda la app
        if let currentUser = self.user {
            fetchTwitterUserData(uid: currentUser.uid, completion: { _ in })
        }
    }

    // Fetch User Data

    private func fetchTwitterUserData(
        uid: String,
        completion: @escaping (Result<TwitterUser?, Error>) -> Void
    ) {

        guard let uuid = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async {
                self.twitterUser = nil // this will update the user
            }
            completion(.success(nil))
            return
        }

        db.collection("users").document(uuid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error)")
                return
            }

            do {
                let twitteruser = try snapshot?.data(as: TwitterUser.self)
                DispatchQueue.main.async {
                    self.twitterUser = twitteruser
                }
                completion(.success(twitteruser))
            } catch {
                print(error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    // Register Method For Auth and Creating at the same time calling the method to create the user in the Firestore

    func registerNewUser(
        email: String,
        password: String,
        fullname: String,
        username: String,
        bio: String? = nil,
        profileImage: UIImage? = nil,
        completion: @escaping (Result<User, Error>) -> Void
    ) {

        Auth.auth().createUser(withEmail: email, password: password) {
            (result, error) in
            if let error = error {
                print(error.localizedDescription)
                completion(.failure(error))
                return
            } else if let user = result?.user {
                self.user = user
                
                self.createUserFirestore(
                    userId: user.uid,
                    email: email,
                    fullName: fullname,
                    username: username,
                    bio: bio,
                    profileImage: profileImage,
                    completion: completion
                )
                    
            }
        }
    }

    // Method for checking username in the db (no repeat username)

    private func checkUsername(
        username: String,
        completion: @escaping (Bool) -> Void
    ) {
        db
            .collection("users")
            .whereField("Username", isEqualTo: username.lowercased())
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error username: \(error)")
                    completion(false)
                    return
                }

                completion(snapshot?.documents.isEmpty ?? true)

            }
    }

    // CreateUserFirestore Method (This method is to create the user in the firestore using the same id as the Auth)

    private func createUserFirestore(
        userId: String,
        email: String,
        fullName: String,
        username: String,
        bio: String?,
        profileImage: UIImage?,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        self.checkUsername(username: username) {
            isAvailable in
            guard isAvailable else {
                completion(
                    .failure(
                        SimpleError(
                            "Username is already in use, please use another"
                        )
                    )
                )
                return
            }
            
            self.uploadProfileImage(userId: userId, image: profileImage) { result in
                switch result {
                case .success(let imageUrl):
                    let twitterUser = TwitterUser(
                        email: email,
                        Fullname: fullName,
                        Username: username,
                        Bio: bio,
                        ProfileImageURL: imageUrl
                    )
                    
                    
                    self.createUserCollection(userId: userId, twitterUser: twitterUser){
                        error in
                        if let error = error{
                            completion(.failure(error))
                        }
                        else{
                            self.twitterUser = twitterUser
                            completion(.success((self.user!)))
                        }
                        
                    }
                    
                case .failure(let error):
                  completion(.failure(error))
                                              
                }
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
                completion(.failure(SimpleError(
                    "Error uploading the image: \(error.localizedDescription)"
                )))
                return
            }
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
            } else if let url = url {
                completion(.success(url.absoluteString))
            }
        }
    }

    // createUserCollection Method to push into the firestore

    private func createUserCollection(
        userId: String,
        twitterUser: TwitterUser,
        completion: @escaping (Error?) -> Void
    ) {
        do {
            try db
                .collection("users")
                .document(userId).setData(from: twitterUser)
            
                DispatchQueue.main.async {
                    self.twitterUser = twitterUser // this will update the user
                    }
                completion(nil)
        }
        catch {
            completion(error)
        }
    }

    // Login Method

    func login(
        email: String,
        password: String,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        Auth.auth().signIn(withEmail: email, password: password) {
            (result, error) in

            if let error = error {
                completion(.failure(error))
                return
            } else if let user = result?.user {
                self.user = user
                self.fetchTwitterUserData(uid: user.uid){
                    result in
                    completion(.success(user))
                }
            }
        }
    }

    // SignOut Method

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.twitterUser = nil
            completion(.success(()))
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError)")
            completion(.failure(signOutError))
        }
    }

}
