//
//  AddressMiniMapView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-03-08.
//

import SwiftUI
import MapKit

struct AddressMiniMapView: View {
    
    let coordinate: CLLocationCoordinate2D
    let addressText: String
    
    var onEditTapped: () -> Void
    
    // Fit camera to full route (best UX)
    private var region: MKCoordinateRegion{
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8){
            HStack{
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                Text("My Location")
                    .font(.headline)
                Spacer()
                // Button for editing in the addresspickerview
                Button(action: onEditTapped){
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            
            Map(initialPosition: .region(region)){
                Marker(addressText,coordinate: coordinate)
                    .tint(.red)
            }
            .mapStyle(.standard)
            .frame(height: 180)
            .cornerRadius(12)
            .disabled(true)
            .allowsHitTesting(false)
            
            Text(addressText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    AddressMiniMapView(
        coordinate: CLLocationCoordinate2D(
            latitude: 45.4919,
            longitude: -73.5794
        ),
        addressText: "1750 Rue Sherbrooke, Montreal",
        onEditTapped: {}
    )
}
