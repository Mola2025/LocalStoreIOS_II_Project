//
//  ProductValidation.swift
//  IOS_Midterm_Assigment_3
//
//  Created by David Molano on 2026-02-03.
//

import Foundation
import CoreData
import FirebaseAuth

extension Product{
    
    var displayName: String{
        return name ?? "Unnamed Product"
    }
    
    var isOnStock: Bool{
        return stock > 0
    }
    
    var stockStatus: String{
        return isOnStock ? "In Stock (\(stock))" : "Out of Stock"
    }
    
    var vendorName: String{
        return vendor?.displayName ?? "UnKnown Vendor"
    }
    
    static func isAllFieldValid(name: String, price: Double, stock: Int32) -> Bool{
        return !name.isEmpty &&
        price > 0 &&
        stock >= 0
    }
    
    func isOwnedByCurrentVendor() -> Bool {
        guard
            let vendorFirebaseUUID = vendor?.firebaseUUID,
            let uid = Auth.auth().currentUser?.uid
        else {
            return false
        }
        return vendorFirebaseUUID == uid
    }
}
