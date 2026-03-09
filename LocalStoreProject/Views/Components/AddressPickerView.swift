//
//  AddressPickerView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-03-08.
//

import MapKit
import SwiftUI

struct AddressPickerView: View {

    var onSave: (Double, Double, String, String) -> Void

    var initialCoordinate: CLLocationCoordinate2D?

    @Environment(\.dismiss) var dismiss

    @StateObject private var locationManager = LocationManager()
    @State private var camera: MapCameraPosition = .automatic
    @State private var zoomLevel: Double = 4000.0

    @State private var currentCenter: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 45.4919, longitude: -73.5794)

    @State private var searchText: String = ""
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedCity: String = ""
    @State private var selectedStreet: String = ""
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Map(position: $camera) {

                if let userLocation = locationManager.UserLocation {
                    Marker("You", coordinate: userLocation)
                        .tint(.blue)
                }

                if let selected = selectedCoordinate {
                    Marker("Selected Location", coordinate: selected)
                        .tint(.green)
                }
            }
            .mapStyle(.standard)
            .onMapCameraChange {
                context in
                currentCenter = context.camera.centerCoordinate
                zoomLevel = context.camera.distance
            }

            // Location Button (Manually added)
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Button(action: goToUserLocation) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .shadow(radius: 4)
                    }
                    .padding()
                }
                Spacer()
            }

            // Zoom Controls
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Button(action: zoomIn) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .shadow(radius: 4)

                        Button(action: zoomOut) {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {

                // Search bar
                HStack(spacing: 10) {
                    TextField("Search address or city", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit { runSearch() }

                    Button {
                        runSearch()
                    } label: {
                        if isSearching {
                            ProgressView()
                                .tint(.white)
                                .frame(width: 24, height: 24)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .disabled(
                        isSearching
                            || searchText.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                    )
                }

                // Basic error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let selected = selectedCoordinate {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading) {
                            Text(
                                selectedStreet.isEmpty
                                    ? "Selected location" : selectedStreet
                            )
                            .font(.subheadline)
                            .bold()
                            Text(
                                selectedCity.isEmpty
                                    ? String(
                                        format: "%.4f, %.4f",
                                        selected.latitude,
                                        selected.longitude
                                    ) : selectedCity
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    Button {
                        confirmSelection()
                    } label: {
                        Text("Save this location")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
        }.navigationTitle("Set Your Address")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            if let initial = initialCoordinate, initial.latitude != 0 {
                camera = .camera(
                    MapCamera(centerCoordinate: initial, distance: zoomLevel)
                )
                selectedCoordinate = initial
            } else {
                camera = .camera(
                    MapCamera(
                        centerCoordinate: currentCenter,
                        distance: zoomLevel
                    )
                )
            }

        }
    }
    
    private func runSearch(currentDestination: Bool = false) {
        Task {
            @MainActor in
            errorMessage = nil

            let query = searchText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard !query.isEmpty else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                let (coordinate, city, street) = try await searchAddress(
                    for: query
                )
                selectedCoordinate = coordinate
                selectedCity = city
                selectedStreet = street
                
                withAnimation{
                    camera = .camera(
                        MapCamera(
                            centerCoordinate: coordinate,
                            distance: 2000
                        )
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func searchAddress(for query: String) async throws -> (
        CLLocationCoordinate2D, String, String
    ){
        try await withCheckedThrowingContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            MKLocalSearch(request: request).start {
                response,
                error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let mapItem = response?.mapItems.first else {
                    continuation
                        .resume(
                            throwing: NSError(
                                domain: "Search",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "No results found for: \(query)"]
                            )
                        )
                    return
                }
                
                let coordinate = mapItem.placemark.coordinate
                // Esto es para extraer la ciudad y calle del placemark
                let city = mapItem.placemark.locality ?? mapItem.placemark.administrativeArea ?? ""
                let street = mapItem.placemark.thoroughfare ?? ""
                
                continuation.resume(returning: (coordinate, city, street))
            }
        }
    }
    
    private func confirmSelection(){
        guard let coord = selectedCoordinate else { return }
        onSave(coord.latitude,coord.longitude,selectedCity,selectedStreet)
        dismiss()
    }

    private func zoomIn() {
        withAnimation {
            zoomLevel *= 0.8
            camera =
                .camera(
                    MapCamera(
                        centerCoordinate: currentCenter,
                        distance: zoomLevel
                    )
                )
        }
    }

    private func zoomOut() {
        withAnimation {
            zoomLevel *= 1.2
            camera =
                .camera(
                    MapCamera(
                        centerCoordinate: currentCenter,
                        distance: zoomLevel
                    )
                )
        }
    }

    private func goToUserLocation() {
        if let userLocation = locationManager.UserLocation {
            withAnimation {
                camera = .camera(
                    MapCamera(
                        centerCoordinate: userLocation,
                        distance: zoomLevel
                    )
                )
            }
        }
    }
}

#Preview {
    AddressPickerView{
        lat, long, city, street in
        print("Saved: \(lat), \(long), \(city), \(street)")
    }
}
