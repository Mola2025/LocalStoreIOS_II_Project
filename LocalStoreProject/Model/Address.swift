//
//  Address.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-03-07.
//

import Foundation
import CoreData
import MapKit

extension Address{
    
    var hasValidCoordinates: Bool {
        return coordinate.latitude != 0 && coordinate.longitude != 0
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var displayAddress: String{
        if let city = city, let street = street, !city.isEmpty, !street.isEmpty{
            return "\(street), \(city)"
        }
        else if let city = city, !city.isEmpty{
            return city
        }
        else if hasValidCoordinates{
            return String(format: "%.4f, %.4f", latitude, longitude)
        }
        return "No Address Registered."
    }
}
