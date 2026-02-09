//
//  UserType.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-02-08.
//

import Foundation

enum UserType: String, CaseIterable{
    case customer = "Customer"
    case vendor = "Vendor"
    
    var icon: String{
        switch self {
        case .customer:
            return "person.fill"
        case .vendor:
            return "storefront.fill"
        }
    }
    
    var description: String{
        switch self {
        case .customer:
            return "Customer"
        case .vendor:
            return "Vendor"
        }
    }
}
