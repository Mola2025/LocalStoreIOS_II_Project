//
//  User.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-02.
//

import Foundation
import CoreData

extension User{
    
    var displayName: String{
        return name ?? "User without name"
    }
    
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^\S+@\S+\.\S+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    
    static func isAllFieldValid(name: String, email: String, password: String) -> Bool{
        return !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6
    }
    
    
}
