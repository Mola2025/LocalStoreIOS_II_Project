//
//  AllVendorsMapView.swift
//  LocalStoreProject
//
//  Created by David Molano on 2026-03-30.
//

import CoreData
import FirebaseFirestore
import MapKit
import SwiftUI

// Color palette — for each vendor gets one color derived from its id hash
private let pinColors: [Color] = [
    .red, .orange, .purple, .green, .pink, .cyan, .indigo, .mint,
]

struct AllVendorsMapView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()

    @State private var camera: MapCameraPosition = .automatic
    @State private var zoomLevel: Double = 4000.0
    @State private var currentCenter: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 45.5, longitude: -73.57)

    @State private var vendors: [Vendor] = []
    @State private var vendorColors: [NSManagedObjectID: Color] = [:]
    @State private var searchText: String = ""
    @State private var appliedSearch: String = ""
    @State private var selectedVendor: Vendor? = nil
    @State private var isLoading: Bool = true

    var filteredVendors: [Vendor] {
        let trimmed = appliedSearch.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return vendors }
        return vendors.filter {
            $0.displayName.localizedCaseInsensitiveContains(trimmed)
                || ($0.address?.displayAddress.localizedCaseInsensitiveContains(
                    trimmed
                ) ?? false)
        }
    }

    var body: some View {
        ZStack {

            // MARK: - Map
            Map(position: $camera) {
                // Use Annotation + Button instead of Marker so taps are detected
                // Annotation is the same as Marker from MapKit just for allowing the tap in simulator
                ForEach(filteredVendors, id: \.id) { vendor in
                    if let address = vendor.address, address.hasValidCoordinates
                    {
                        let color = vendorColors[vendor.objectID] ?? .red
                        
                        Annotation("", coordinate: address.coordinate) {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedVendor?.id == vendor.id {
                                        selectedVendor = nil
                                    } else {
                                        selectedVendor = vendor
                                    }
                                }
                            } label: {
                                VStack(spacing: 0) {
                                    ZStack {
                                        Circle()
                                            .fill(selectedVendor?.objectID == vendor.objectID ? .blue : color)
                                            .frame(
                                                width: selectedVendor?.id
                                                    == vendor.id ? 44 : 34,
                                                height: selectedVendor?.id
                                                    == vendor.id ? 44 : 34
                                            )
                                            .shadow(
                                                color: .black.opacity(0.25),
                                                radius: 4,
                                                x: 0,
                                                y: 2
                                            )

                                        Image(systemName: "storefront.fill")
                                            .font(
                                                .system(
                                                    size: selectedVendor?.id
                                                        == vendor.id ? 20 : 15
                                                )
                                            )
                                            .foregroundColor(.white)
                                    }
                                    Image(systemName: "arrowtriangle.down.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(selectedVendor?.objectID == vendor.objectID ? .blue : color)
                                        .offset(y: -3)
                                }
                                .animation(
                                    .spring(
                                        response: 0.3,
                                        dampingFraction: 0.7
                                    ),
                                    value: selectedVendor?.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let userLocation = locationManager.UserLocation {
                    Marker("You", coordinate: userLocation)
                        .tint(.blue)
                }
            }
            .mapStyle(.standard)
            .onMapCameraChange { context in
                currentCenter = context.camera.centerCoordinate
                zoomLevel = context.camera.distance
            }
            .ignoresSafeArea()

            // MARK: - Top: Search Bar
            VStack {
                HStack(spacing: 8) {
                    TextField(
                        "Search vendors or addresses...",
                        text: $searchText
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { applySearch() }

                    // Button x for clear the search bar
                    if !appliedSearch.isEmpty {
                        Button {
                            searchText = ""
                            appliedSearch = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: applySearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(9)
                    }
                    .disabled(
                        searchText.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(.ultraThinMaterial)
                .cornerRadius(13)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                .padding(.horizontal, 16)
                .padding(.top, 60)

                if !appliedSearch.isEmpty {
                    HStack {
                        Text(
                            "\(filteredVendors.count) result\(filteredVendors.count == 1 ? "" : "s") for \"\(appliedSearch)\""
                        )
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.85), in: Capsule())
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                Spacer()
            }

            // MARK: - Bottom-right: Location + Zoom controls
            VStack {
                Spacer()
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

            // MARK: - Bottom: Selected vendor card
            if let vendor = selectedVendor, let address = vendor.address {
                let color = vendorColors[vendor.objectID] ?? .red
                VStack {
                    Spacer()
                    HStack(spacing: 14) {
                        Image(systemName: "storefront.fill")
                            .font(.title2)
                            .foregroundColor(color)
                            .frame(width: 48, height: 48)
                            .background(color.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(vendor.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(color)
                                Text(address.displayAddress)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button {
                            withAnimation { selectedVendor = nil }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 220)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // MARK: - Loading indicator
            if isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(20)
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
        }
        .onAppear {
            loadVendors()
        }
    }
    
    // MARK: - Random Colors
    
    private func assignRandomColors(to vendors: [Vendor]) {
        vendorColors.removeAll()
        
        for vendor in vendors {
            vendorColors[vendor.objectID] = pinColors.randomElement() ?? .red
        }
    }

    // MARK: - Search

    private func applySearch() {
        appliedSearch = searchText.trimmingCharacters(in: .whitespaces)
        // Move the camera to the results
        fitCamera(to: filteredVendors)
    }

    // MARK: - Load vendors

    private func loadVendors() {
        isLoading = true
        let addressManager = AddressManager(viewContext: viewContext)

        vendors = addressManager.fetchVendorsWithAddress()
        assignRandomColors(to: vendors)
        fitCamera(to: vendors)

        let db = Firestore.firestore()
        db.collection("vendors").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                isLoading = false
                return
            }

            DispatchQueue.main.async {
                for doc in documents {
                    let data = doc.data()
                    let firebaseUID = doc.documentID

                    guard let addressData = data["address"] as? [String: Any],
                        let lat = addressData["latitude"] as? Double,
                        let lon = addressData["longitude"] as? Double,
                        lat != 0, lon != 0
                    else { continue }

                    let request: NSFetchRequest<Vendor> = Vendor.fetchRequest()
                    request.predicate = NSPredicate(
                        format: "firebaseUUID == %@",
                        firebaseUID
                    )
                    request.fetchLimit = 1

                    let vendor: Vendor
                    let existing = (try? viewContext.fetch(request))?.first
                    if let existing = existing {
                        vendor = existing
                    } else {
                        vendor = Vendor(context: viewContext)
                        vendor.id =
                            UUID(uuidString: data["id"] as? String ?? "")
                            ?? UUID()
                        vendor.firebaseUUID = firebaseUID
                        vendor.name = data["name"] as? String
                        vendor.email = data["email"] as? String
                        vendor.vendorDescription =
                            data["vendorDescription"] as? String
                        vendor.profileImageURL =
                            data["profileImageURL"] as? String
                    }

                    let address: Address =
                        vendor.address ?? Address(context: viewContext)
                    address.latitude = lat
                    address.longitude = lon
                    address.city = addressData["city"] as? String ?? ""
                    address.street = addressData["street"] as? String ?? ""
                    vendor.address = address
                    address.vendor = vendor
                }

                try? viewContext.save()

                vendors = addressManager.fetchVendorsWithAddress()
                assignRandomColors(to: vendors)
                fitCamera(to: vendors)
                isLoading = false
            }
        }
    }

    private func fitCamera(to vendors: [Vendor]) {
        let validAddresses = vendors.compactMap { $0.address }.filter {
            $0.hasValidCoordinates
        }
        guard !validAddresses.isEmpty else { return }

        let lats = validAddresses.map { $0.latitude }
        let lons = validAddresses.map { $0.longitude }

        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let center = CLLocationCoordinate2D(
            latitude: centerLat,
            longitude: centerLon
        )

        let latDelta = (lats.max()! - lats.min()!) * 1.4
        let lonDelta = (lons.max()! - lons.min()!) * 1.4
        let regionSpanMeters = max(latDelta, lonDelta) * 111_000

        withAnimation {
            camera = .camera(
                MapCamera(
                    centerCoordinate: center,
                    distance: max(5000, regionSpanMeters)
                )
            )
        }
    }

    // MARK: - Map controls

    private func zoomIn() {
        withAnimation {
            zoomLevel *= 0.8
            camera = .camera(
                MapCamera(centerCoordinate: currentCenter, distance: zoomLevel)
            )
        }
    }

    private func zoomOut() {
        withAnimation {
            zoomLevel *= 1.2
            camera = .camera(
                MapCamera(centerCoordinate: currentCenter, distance: zoomLevel)
            )
        }
    }

    private func goToUserLocation() {
        guard let userLocation = locationManager.UserLocation else { return }
        withAnimation {
            camera = .camera(
                MapCamera(centerCoordinate: userLocation, distance: zoomLevel)
            )
        }
    }
}

#Preview {
    AllVendorsMapView()
}
