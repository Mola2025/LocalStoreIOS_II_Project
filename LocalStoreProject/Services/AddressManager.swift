//
//  AddressManager.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-03-07.
//

import CoreData
import FirebaseFirestore
import Foundation

class AddressManager {

    private let viewContext: NSManagedObjectContext
    private let db = Firestore.firestore()

    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }

    func saveAddressForUser(
        user: User,
        latitude: Double,
        longitude: Double,
        city: String,
        street: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let address: Address

        if let existingAddress = user.address {
            address = existingAddress
        } else {
            address = Address(context: viewContext)

            // Link address with the user (Bidirectional)
            user.address = address
            address.user = user
        }

        address.latitude = latitude
        address.longitude = longitude
        address.city = city
        address.street = street

        do {
            try viewContext.save()

            guard let firebaseUID = user.firebaseUUID else {
                completion(
                    .failure(SimpleError("User does not have a firebase UUID"))
                )
                return
            }

            let addressData: [String: Any] = [
                "latitude": latitude,
                "longitude": longitude,
                "city": city,
                "street": street,
            ]

            db.collection("users").document(firebaseUID).updateData([
                "address": addressData
            ]) {
                error in
                if let error = error {
                    self.db.collection("users").document(firebaseUID).setData(
                        [
                            "address": addressData
                        ],
                        merge: true
                    ) {
                        error2 in
                        if let error2 = error2 {
                            completion(
                                .failure(
                                    SimpleError(
                                        "Failed to save address to Firestore: \(error2)"
                                    )
                                )
                            )
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func saveAddressForVendor(
        vendor: Vendor,
        latitude: Double,
        longitude: Double,
        city: String,
        street: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let address: Address

        if let existingAddress = vendor.address {
            address = existingAddress
        } else {
            address = Address(context: viewContext)

            // Link address with the vendor (Bidirectional)
            vendor.address = address
            address.vendor = vendor
        }

        address.latitude = latitude
        address.longitude = longitude
        address.city = city
        address.street = street

        do {
            try viewContext.save()

            guard let firebaseUID = vendor.firebaseUUID else {
                completion(
                    .failure(SimpleError("Vendor does not have a firebase UUID"))
                )
                return
            }

            let addressData: [String: Any] = [
                "latitude": latitude,
                "longitude": longitude,
                "city": city,
                "street": street,
            ]

            db.collection("vendors").document(firebaseUID).updateData([
                "address": addressData
            ]) {
                error in
                if let error = error {
                    self.db.collection("vendors").document(firebaseUID).setData(
                        [
                            "address": addressData
                        ],
                        merge: true
                    ) {
                        error2 in
                        if let error2 = error2 {
                            completion(
                                .failure(
                                    SimpleError(
                                        "Failed to save address to Firestore: \(error2)"
                                    )
                                )
                            )
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    // Function to load in the map of the users all the locations from the vendors registered in the DB with the Location saved
    func fetchVendorsWithAddress() -> [Vendor]{
        let request: NSFetchRequest<Vendor> = Vendor.fetchRequest()
        request.predicate = NSPredicate(
            format: "address != nil AND address.latitude != 0 AND address.longitude != 0"
        )
        
        do{
            return try viewContext.fetch(request)
        }
        catch{
            print("Error fetching vendors with address: \(error)")
            return []
        }
    }

}
